import PhotosUI
import SwiftUI
import UIKit

/// Z-34.2: full-screen backdrop picker (partner profile → "Unser Chat" → "Backdrop"). Swipe
/// sideways through the 16 templates, each with real sample bubbles in its colors; "Übernehmen"
/// sets it for both of you. The last page takes an own photo or drawing.
struct BackdropAuswahl: View {
    @Environment(\.dismiss) private var dismiss
    /// Id of the visible page (a backdrop id or `Self.eigeneSeite`), kept by the paging scroll view.
    @State private var seite: String?
    @State private var zeichnungen: [ZeichnungEintrag] = []
    @State private var fotoAuswahl: PhotosPickerItem?
    /// Own picture: preview right away, `eigenes` once the upload finished (the partner must be
    /// able to fetch it before the setting goes out).
    @State private var eigenesBild: UIImage?
    @State private var eigenes: BackdropWahl?
    @State private var hochladenId: String?
    @State private var fehler: String?

    private static let eigeneSeite = "eigenes"

    var body: some View {
        ZStack {
            seiten
            VStack(spacing: 0) {
                kopfleiste
                Spacer(minLength: 0)
                fussleiste
            }
        }
        .background(Color.black)
        .onAppear {
            let bibliothek = ArtworkLibrary()
            zeichnungen = bibliothek.artworks.map { ZeichnungEintrag(id: $0.id, name: $0.name, vorschau: bibliothek.previewURL(for: $0.id)) }
            // Set after appearing, not as the initial value: a changed binding reliably scrolls there.
            if seite == nil { seite = startSeite }
        }
        .onChange(of: seite) { alt, _ in if alt != nil { Haptik.auswahl() } }
        .onChange(of: fotoAuswahl) { _, neu in fotoUebernehmen(neu) }
    }

    private var seiten: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Backdrops.alle) { backdrop in
                    BackdropVorlagenSeite(backdrop: backdrop)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(backdrop.id)
                }
                eigeneSeite
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(Self.eigeneSeite)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $seite)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
    }

    // MARK: - Floating controls (glass only here, over the picture)

    private var kopfleiste: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Schließen")
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Text(seitenName).font(.headline)
                Text("\(seitenNummer)/\(Backdrops.alle.count + 1)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .glassEffect(.regular, in: .capsule)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            Color.clear.frame(width: 44, height: 44) // keeps the title centered
        }
        .padding(.horizontal, 16)
    }

    /// Solid, in the page's own-bubble gradient: the button previews the bubble it will give you.
    private var fussleiste: some View {
        let backdrop = seitenBackdrop
        return VStack(spacing: 10) {
            if let fehler {
                Text(fehler)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
            }
            Button(action: uebernehmen) {
                HStack(spacing: 8) {
                    if istAktuell { Image(systemName: "checkmark") }
                    if laedtHoch { ProgressView().tint(backdrop.eigeneText) }
                    Text(knopfTitel)
                }
                .font(.headline)
                .foregroundStyle(backdrop.eigeneText)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(LinearGradient(colors: backdrop.verlauf, startPoint: .leading, endPoint: .trailing), in: Capsule())
                .opacity(kannUebernehmen || istAktuell ? 1 : 0.6)
            }
            .buttonStyle(.federnd)
            .disabled(!kannUebernehmen)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Own photo or drawing (last page)

    private var eigeneSeite: some View {
        BackdropProbe(backdrop: Backdrops.neutral, bild: eigenesBild, eigenesBild: true)
            .overlay(alignment: .top) {
                eigeneAuswahl
                    .padding(.horizontal, 24)
                    .padding(.top, 130)
            }
            .task { await aktuellesEigenesBildZeigen() }
    }

    private var eigeneAuswahl: some View {
        VStack(spacing: 14) {
            Text("Ein Foto oder eine deiner Zeichnungen. Die Blasen bleiben neutral, das Bild etwas abgedunkelt.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            PhotosPicker(selection: $fotoAuswahl, matching: .images) {
                Label("Foto wählen", systemImage: "photo.on.rectangle").frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            if !zeichnungen.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(zeichnungen) { z in
                            Button { zeichnungUebernehmen(z) } label: { ZeichnungKachel(eintrag: z) }
                                .buttonStyle(.federnd)
                                .accessibilityLabel("Zeichnung \(z.name)")
                        }
                    }
                }
                .frame(height: 88)
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .environment(\.colorScheme, .dark)
    }

    /// Shows the photo or drawing that is the backdrop right now, until a new one is picked.
    private func aktuellesEigenesBildZeigen() async {
        guard eigenesBild == nil else { return }
        switch Backdrops.wahl {
        case .foto(let medienId)?, .zeichnung(let medienId)?:
            eigenesBild = await Backdrops.eigenesBildLaden(medienId)
        default:
            break
        }
    }

    private func fotoUebernehmen(_ item: PhotosPickerItem?) {
        guard let item else { return }
        fotoAuswahl = nil // lets the same photo be picked again after a failed upload
        Task {
            guard let daten = try? await item.loadTransferable(type: Data.self) else {
                fehler = "Das Foto konnte nicht geladen werden."
                return
            }
            await hochladen(daten, zeichnung: false)
        }
    }

    /// Drawings live only on this phone, so the chosen one goes up as a snapshot like a photo.
    private func zeichnungUebernehmen(_ z: ZeichnungEintrag) {
        guard let daten = try? Data(contentsOf: z.vorschau) else {
            fehler = "Von dieser Zeichnung gibt es noch keine Vorschau. Öffne sie einmal im Studio."
            return
        }
        Task { await hochladen(daten, zeichnung: true) }
    }

    private func hochladen(_ daten: Data, zeichnung: Bool) async {
        let id = UUID().uuidString
        hochladenId = id
        eigenes = nil
        fehler = nil
        defer { if hochladenId == id { hochladenId = nil } }
        guard let ergebnis = await Task.detached(priority: .userInitiated, operation: { MedienKodierung.foto(daten, id: id) }).value else {
            fehler = "Das Bild konnte nicht gelesen werden."
            return
        }
        ChatMedien.eigeneQuellen[id] = ergebnis.original
        let vorschau = await Bilddatei.laden(ergebnis.original, maxPixel: 2800)
        guard hochladenId == id else { return } // a newer pick won
        withAnimation(Feder.weich) { eigenesBild = vorschau }
        do {
            try await Medien.hochladen(id: id, original: ergebnis.original, klein: ergebnis.klein)
            guard hochladenId == id else { return }
            eigenes = zeichnung ? .zeichnung(id) : .foto(id)
        } catch {
            if hochladenId == id { fehler = "Hochladen hat nicht geklappt. Versuch es gleich nochmal." }
        }
    }

    // MARK: - State

    private var startSeite: String {
        switch Backdrops.wahl {
        case .vorlage(let id)? where Backdrops.von(id) != nil: id
        case .foto?, .zeichnung?: Self.eigeneSeite
        default: Backdrops.alle[0].id
        }
    }

    private var aufEigenerSeite: Bool { seite == Self.eigeneSeite }
    private var seitenBackdrop: Backdrop { seite.flatMap { Backdrops.von($0) } ?? Backdrops.neutral }
    private var seitenName: String { aufEigenerSeite ? "Eigenes Bild" : seitenBackdrop.name }
    private var seitenNummer: Int { (Backdrops.alle.firstIndex { $0.id == seite } ?? Backdrops.alle.count) + 1 }
    private var laedtHoch: Bool { aufEigenerSeite && hochladenId != nil }

    /// The visible page already is the backdrop of the chat.
    private var istAktuell: Bool {
        switch Backdrops.wahl {
        case .vorlage(let id)?: seite == id
        case .foto?, .zeichnung?: aufEigenerSeite && eigenes == nil && hochladenId == nil
        case nil: false
        }
    }

    private var kannUebernehmen: Bool {
        guard !istAktuell else { return false }
        return aufEigenerSeite ? eigenes != nil : seite != nil
    }

    private var knopfTitel: String {
        if istAktuell { return "Ausgewählt" }
        if laedtHoch { return "Wird hochgeladen …" }
        if aufEigenerSeite && eigenes == nil { return "Foto oder Zeichnung wählen" }
        return "Übernehmen"
    }

    private func uebernehmen() {
        let wahl: BackdropWahl
        if aufEigenerSeite {
            guard let eigenes else { return }
            wahl = eigenes
        } else {
            guard let seite else { return }
            wahl = .vorlage(seite)
        }
        Backdrops.waehlen(wahl)
        Haptik.erfolg()
        dismiss()
    }
}

/// One template page: the picture loads off the main thread, the mesh shows until then.
private struct BackdropVorlagenSeite: View {
    let backdrop: Backdrop
    @State private var bild: UIImage?

    var body: some View {
        BackdropProbe(backdrop: backdrop, bild: bild)
            .task(id: backdrop.id) {
                let geladen = await backdrop.bildLaden()
                withAnimation(Feder.weich) { bild = geladen }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Backdrop \(backdrop.name)")
    }
}

/// A backdrop with sample bubbles in its colors, as the picker pages and the render board show it.
struct BackdropProbe: View {
    let backdrop: Backdrop
    let bild: UIImage?
    var eigenesBild = false
    var animiert = true

    var body: some View {
        BackdropHintergrund(backdrop: backdrop, bild: bild, eigenesBild: eigenesBild, animiert: animiert)
            .overlay(alignment: .bottom) {
                BackdropBeispielBlasen(backdrop: backdrop)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 132)
            }
    }
}

/// A short exchange in the backdrop's colors. ponytail: the own gradient runs per bubble here;
/// the chat itself lays it over the whole screen (B1), which a still preview can't show anyway.
private struct BackdropBeispielBlasen: View {
    let backdrop: Backdrop

    var body: some View {
        VStack(spacing: 6) {
            blase("Guten Morgen, Schatz", eigen: false)
            blase("Morgen! Hast du gut geschlafen?", eigen: true)
            blase("Neben dir immer 🥰", eigen: false)
            blase("Dann bis heute Abend ❤️", eigen: true)
        }
        .accessibilityHidden(true)
    }

    private func blase(_ text: String, eigen: Bool) -> some View {
        let fuellung: AnyShapeStyle = eigen
            ? AnyShapeStyle(LinearGradient(colors: backdrop.verlauf, startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(backdrop.partnerBlase)
        return Text(text)
            .font(.body)
            .foregroundStyle(eigen ? backdrop.eigeneText : backdrop.partnerText)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(fuellung, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: .infinity, alignment: eigen ? .trailing : .leading)
            .padding(eigen ? .leading : .trailing, 48)
    }
}
