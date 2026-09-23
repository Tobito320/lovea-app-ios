import CoreLocation
import MapKit
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

private struct ZeichnungEintrag: Identifiable {
    let id: UUID
    let name: String
    let vorschau: URL
}

/// Photo or one of the own drawings. Uploads first, then sends the setting — so the partner never
/// gets a `medienId` that isn't on the server yet.
struct WallpaperAuswahl: View {
    let partner: Person
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
                if ProfilWallpaper.medienId != nil {
                    Section {
                        Button("Wallpaper entfernen", role: .destructive) {
                            EinstellungenModell.shared.setzen("profilWallpaper", .null)
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
            EinstellungenModell.shared.setzen("profilWallpaper", .object(["medienId": .string(id)]))
            fertig += 1
            dismiss()
        } catch {
            fehler = "Hochladen hat nicht geklappt. Versuch es gleich nochmal."
        }
    }
}

private struct ZeichnungKachel: View {
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

// MARK: - Chatfarbe

struct ChatFarbeAuswahl: View {
    let ich: Person
    @Environment(\.dismiss) private var dismiss
    @State private var gewaehlt = 0

    private var aktuell: String { EinstellungenModell.shared.string("chatfarbe", default: "", von: ich) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text(ich.name)
                    .font(.title2.bold())
                    .foregroundStyle(ChatFarbe.farbe(ich))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                    .accessibilityLabel("Vorschau: \(ich.name)")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                    ForEach(ChatFarbe.auswahl, id: \.self) { option in
                        Button {
                            EinstellungenModell.shared.setzen("chatfarbe", .string(option.hex))
                            gewaehlt += 1
                        } label: {
                            Circle()
                                .fill(ChatFarbe.farbe(hex: option.hex) ?? .gray)
                                .frame(width: 52, height: 52)
                                .overlay {
                                    if aktuell == option.hex {
                                        Image(systemName: "checkmark").font(.headline.bold()).foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.name)
                        .accessibilityAddTraits(aktuell == option.hex ? .isSelected : [])
                    }
                }
                Button("Standardfarbe") {
                    EinstellungenModell.shared.setzen("chatfarbe", .string(""))
                    gewaehlt += 1
                }
                .disabled(aktuell.isEmpty)
                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Chatfarbe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .sensoryFeedback(.selection, trigger: gewaehlt)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Map preview ("Annika ist hier: …")

struct KartenVorschau: View {
    let person: Person
    let oeffnen: () -> Void
    @State private var ortName: String?

    private var standort: StandortDaten? { Standort.shared.positionen[person] }
    private var istIch: Bool { person == Raum.shared.ich }

    var body: some View {
        Button(action: oeffnen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottom) {
                    if let d = standort {
                        karte(d)
                        if let info = infoText(d) {
                            Text(info)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.regularMaterial, in: Capsule())
                                .padding(.bottom, 10)
                        }
                    } else {
                        Rectangle().fill(Color(uiColor: .tertiarySystemFill))
                        Label("Noch kein Standort", systemImage: "location.slash")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipped()

                HStack {
                    Text("\(istIch ? "Du bist" : "\(person.name) ist") hier: \(Text(ortName ?? "…").bold())")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öffnet die Karte")
        .task(id: standort.map { "\($0.lat),\($0.lon)" }) { await ortLaden() }
    }

    private func karte(_ d: StandortDaten) -> some View {
        let punkt = CLLocationCoordinate2D(latitude: d.lat, longitude: d.lon)
        return Map(initialPosition: .region(MKCoordinateRegion(center: punkt, latitudinalMeters: 1800, longitudinalMeters: 1800)), interactionModes: []) {
            Annotation("", coordinate: punkt, anchor: .bottom) {
                // Static: the profile already animates two figures, a third loop isn't worth the frames.
                FigurView(FigurenModell.shared.aussehen(person), zustand: FigurenModell.shared.anzeige(person).haupt, groesse: 60, animiert: false)
            }
        }
        .id("\(d.lat),\(d.lon)")
        .allowsHitTesting(false)
    }

    private func infoText(_ d: StandortDaten) -> String? {
        var teile: [String] = []
        if let zeit = ISO8601DateFormatter().date(from: d.zeit) {
            let sekunden = Date().timeIntervalSince(zeit)
            teile.append(sekunden < 90 ? "gerade eben" : sekunden < 3600 ? "vor \(Int(sekunden / 60)) min" : "vor \(Int(sekunden / 3600)) h")
        }
        if !istIch, let ich = Raum.shared.ich, let eigene = Standort.shared.positionen[ich] {
            let km = CLLocation(latitude: eigene.lat, longitude: eigene.lon).distance(from: CLLocation(latitude: d.lat, longitude: d.lon)) / 1000
            teile.append(km < 1 ? "\(Int(km * 1000)) m" : "\(Int(km.rounded())) km")
        }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    private func ortLaden() async {
        guard let d = standort else { ortName = nil; return }
        if let info = OrteModell.shared.aktuellerOrt(person, lat: d.lat, lon: d.lon) {
            ortName = info.name
            return
        }
        // ponytail: `CLGeocoder` is deprecated on iOS 26 but still works (InfoKarteView uses it too);
        // switch both to `MKReverseGeocodingRequest` together once someone can compile against it.
        guard let orte = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: d.lat, longitude: d.lon)), let p = orte.first else { return }
        let text = [p.subLocality ?? p.thoroughfare, p.locality].compactMap { $0 }.joined(separator: ", ")
        ortName = text.isEmpty ? nil : text
    }
}
