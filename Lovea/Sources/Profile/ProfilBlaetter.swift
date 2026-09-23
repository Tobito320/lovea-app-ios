import PhotosUI
import SwiftUI
import UIKit

// MARK: - Wallpaper (shared: `einstellung.setzen profilWallpaper {medienId}`, newest from either person wins)

/// Fills whatever frame it gets; photo or drawing from `Medien`, else a soft Lovea gradient.
struct ProfilWallpaper: View {
    @State private var bild: UIImage?

    static var medienId: String? {
        guard case .object(let o) = EinstellungenModell.shared.geteilt("profilWallpaper"), case .string(let id)? = o["medienId"] else { return nil }
        return id
    }

    var body: some View {
        let id = Self.medienId
        Color.clear
            .overlay {
                if let bild {
                    Image(uiImage: bild).resizable().scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.loveaRose, Color(red: 0.42, green: 0.16, blue: 0.29)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            }
            .clipped()
            .accessibilityHidden(true)
            .task(id: id) { await laden(id) }
    }

    private func laden(_ id: String?) async {
        guard let id else { bild = nil; return }
        var url = ChatMedien.eigeneQuellen[id] ?? Medien.lokal(id)
        if url == nil { url = try? await Medien.holen(id) }
        guard let url else { return }
        bild = await Bilddatei.laden(url, maxPixel: 2000)
    }
}

/// An own drawing with its cached preview (also used by `BackdropAuswahl`).
struct ZeichnungEintrag: Identifiable {
    let id: UUID
    let name: String
    let vorschau: URL
}

/// Photo or one of the own drawings. Uploads first, then sends the setting — so the partner never
/// gets a `medienId` that isn't on the server yet.
struct WallpaperAuswahl: View {
    let partner: Person
    /// Z-25.2: what to write once the upload finishes — the shared `profilWallpaper` key by
    /// default (unchanged R1 behavior), or the per-person `profil.hintergrund` for the own profile.
    var speichern: (String) -> Void = { id in EinstellungenModell.shared.setzen("profilWallpaper", .object(["medienId": .string(id)])) }
    /// The per-person background always has a backdrop fallback, so it skips the "remove" row —
    /// only the shared wallpaper (which falls back to a plain gradient) offers it.
    var zeigtEntfernen = true
    @Environment(\.dismiss) private var dismiss
    @State private var fotoAuswahl: PhotosPickerItem?
    @State private var zeichnungen: [ZeichnungEintrag] = []
    @State private var laedt = false
    @State private var fehler: String?
    @State private var fertig = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $fotoAuswahl, matching: .images) {
                        Label("Foto wählen", systemImage: "photo.on.rectangle")
                    }
                } footer: {
                    Text("Du und \(partner.name) seht das Wallpaper.")
                }
                if !zeichnungen.isEmpty {
                    Section("Eigene Zeichnung") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(zeichnungen) { z in
                                    Button { waehlen(z) } label: { ZeichnungKachel(eintrag: z) }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(z.name)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                if laedt {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Wird hochgeladen …").foregroundStyle(.secondary)
                        }
                    }
                }
                if let fehler {
                    Section { Text(fehler).foregroundStyle(.red) }
                }
                if zeigtEntfernen, ProfilWallpaper.medienId != nil {
                    Section {
                        Button("Wallpaper entfernen", role: .destructive) {
                            EinstellungenModell.shared.setzen("profilWallpaper", .object([:]))
                            dismiss()
                        }
                    }
                }
            }
            .disabled(laedt)
            .navigationTitle("Wallpaper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
            .onAppear {
                let bibliothek = ArtworkLibrary()
                zeichnungen = bibliothek.artworks.map { ZeichnungEintrag(id: $0.id, name: $0.name, vorschau: bibliothek.previewURL(for: $0.id)) }
            }
            .onChange(of: fotoAuswahl) { _, item in
                guard let item else { return }
                fotoAuswahl = nil // lets the same photo be picked again after a failed upload
                Task {
                    guard let daten = try? await item.loadTransferable(type: Data.self) else {
                        fehler = "Das Foto konnte nicht geladen werden."
                        return
                    }
                    await hochladen(daten)
                }
            }
            .sensoryFeedback(.success, trigger: fertig)
        }
        .presentationDetents([.medium, .large])
    }

    private func waehlen(_ z: ZeichnungEintrag) {
        guard let daten = try? Data(contentsOf: z.vorschau) else {
            fehler = "Von dieser Zeichnung gibt es noch keine Vorschau. Öffne sie einmal im Studio."
            return
        }
        Task { await hochladen(daten) }
    }

    private func hochladen(_ daten: Data) async {
        laedt = true
        fehler = nil
        defer { laedt = false }
        let id = UUID().uuidString
        guard let ergebnis = await Task.detached(priority: .userInitiated, operation: { MedienKodierung.foto(daten, id: id) }).value else {
            fehler = "Das Bild konnte nicht gelesen werden."
            return
        }
        ChatMedien.eigeneQuellen[id] = ergebnis.original
        do {
            try await Medien.hochladen(id: id, original: ergebnis.original, klein: ergebnis.klein)
            speichern(id)
            fertig += 1
            dismiss()
        } catch {
            fehler = "Hochladen hat nicht geklappt. Versuch es gleich nochmal."
        }
    }
}

struct ZeichnungKachel: View {
    let eintrag: ZeichnungEintrag
    @State private var bild: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(uiColor: .tertiarySystemFill))
            .frame(width: 88, height: 88)
            .overlay {
                if let bild { Image(uiImage: bild).resizable().scaledToFill() }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .task { bild = await Bilddatei.laden(eintrag.vorschau, maxPixel: 300) }
    }
}

// MARK: - Unser Chat: Briefe und Sterne (Z-34.2, the old Briefbox moved here)

/// Every letter, newest first, each as B1's `BriefBlase` (tap opens it in place).
struct BriefeBlatt: View {
    let ich: Person
    @Environment(\.dismiss) private var dismiss

    private var briefe: [ChatModell.Nachricht] {
        ChatModell.shared.nachrichten.filter { $0.brief != nil && !$0.geloescht }.sorted { $0.zeit > $1.zeit }
    }

    var body: some View {
        let liste = briefe
        NavigationStack {
            Group {
                if liste.isEmpty {
                    ContentUnavailableView("Noch keine Briefe", systemImage: "envelope", description: Text("Schreib einen über Plus im Chat."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            ForEach(liste) { brief in zeile(brief) }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Briefe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private func zeile(_ n: ChatModell.Nachricht) -> some View {
        let eigen = n.von == ich
        return VStack(alignment: eigen ? .trailing : .leading, spacing: 4) {
            BriefBlase(titel: n.brief?.titel ?? "", text: n.text ?? "", von: n.von)
            Text("\(eigen ? "Von dir" : "Von \(n.von.name)") · \(n.zeit.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: eigen ? .trailing : .leading)
    }
}

/// The own stars, newest first. Tap jumps to the message in the chat.
struct SterneBlatt: View {
    let ich: Person
    let springen: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let liste = ChatModell.shared.meineSterne(ich).sorted { $0.zeit > $1.zeit }
        NavigationStack {
            Group {
                if liste.isEmpty {
                    ContentUnavailableView("Noch keine Sterne", systemImage: "star", description: Text("Halte eine Nachricht gedrückt und tippe auf Stern."))
                } else {
                    List(liste) { n in
                        Button { springen(n.id) } label: { zeile(n) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Sterne")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private func zeile(_ n: ChatModell.Nachricht) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(n.von == ich ? "Du" : n.von.name) · \(n.zeit.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(ChatVorschau.inhalt(n)).lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityHint("Im Chat zeigen")
    }
}
