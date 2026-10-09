import AVKit
import SwiftUI
import UIKit

/// Paar-Galerie wie Snapchat Memories: Rückblick oben, darunter Monate als Raster. Das Raster lädt nur Vorschaubilder
/// (400 px, gecacht), Originale erst im Vollbild. Quelle ist der Chat, nicht die Zeichenbibliothek (`galerie.*`).
struct GalerieView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var filter: GalerieFilter = .alle
    @State private var offen: GalerieStueck?

    var body: some View {
        let alle = GalerieLogik.stuecke(aus: ChatModell.shared.nachrichten)
        let sichtbar = GalerieLogik.filtern(alle, filter)
        let monate = GalerieLogik.monate(sichtbar)
        let rueckblick = filter == .alle ? GalerieLogik.rueckblick(alle) : nil
        NavigationStack {
            Group {
                if sichtbar.isEmpty {
                    ContentUnavailableView("Noch nichts da", systemImage: "photo.on.rectangle.angled",
                                           description: Text("Fotos, Videos und behaltene Snaps aus eurem Chat erscheinen hier."))
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18, pinnedViews: .sectionHeaders) {
                            if let rueckblick { rueckblickZeile(rueckblick.titel, rueckblick.stuecke) }
                            ForEach(monate) { monat in
                                Section {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                                        ForEach(monat.stuecke) { s in
                                            GalerieKachel(stueck: s).onTapGesture { Haptik.leicht(); offen = s }
                                        }
                                    }
                                } header: {
                                    Text(monat.titel).font(.headline).padding(.horizontal, 12).padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading).background(.bar)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Galerie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Filter", selection: $filter) {
                            ForEach(GalerieFilter.allCases) { Text($0.titel).tag($0) }
                        }
                    } label: {
                        Label(filter.titel, systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filtern")
                }
            }
        }
        .fullScreenCover(item: $offen) { start in GalerieVollbild(liste: sichtbar, start: start.id) }
    }

    private func rueckblickZeile(_ titel: String, _ stuecke: [GalerieStueck]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel).font(.headline).padding(.horizontal, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(stuecke) { s in
                        GalerieKachel(stueck: s).frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture { Haptik.leicht(); offen = s }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.top, 8)
    }
}

/// Vorschaubild; lädt erst, wenn die Kachel im Bild ist, und bricht beim Wegscrollen ab.
private struct GalerieKachel: View {
    let stueck: GalerieStueck
    @State private var bild: UIImage?

    var body: some View {
        Color(uiColor: .secondarySystemBackground)
            .overlay {
                if let bild { Image(uiImage: bild).resizable().scaledToFill() }
            }
            .overlay(alignment: .bottomTrailing) {
                if stueck.art == .video {
                    Image(systemName: "play.fill").font(.caption2).foregroundStyle(.white).padding(5)
                } else if stueck.snap {
                    Image(systemName: "flame.fill").font(.caption2).foregroundStyle(.white).padding(5)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .contentShape(.rect)
            .task(id: stueck.id) { bild = await GalerieDatei.vorschau(stueck) }
            .accessibilityLabel(stueck.art == .video ? "Video" : "Foto")
            .accessibilityAddTraits(.isButton)
    }
}

@MainActor
enum GalerieDatei {
    /// Datei lokal oder aus dem Netz holen (ein Versuch, kein Dauerlauf).
    static func datei(_ s: GalerieStueck) async -> URL? {
        if let q = ChatMedien.eigeneQuellen[s.id] ?? Medien.lokal(s.id) { return q }
        return try? await Medien.holen(s.id)
    }

    static func vorschau(_ s: GalerieStueck) async -> UIImage? {
        guard let url = await datei(s) else { return nil }
        return s.art == .video ? await Videobild.erstesBild(url) : await Bilddatei.laden(url, maxPixel: 400)
    }
}

/// Vollbild mit seitlichem Wischen, Teilen und Speichern in Aufnahmen.
private struct GalerieVollbild: View {
    let liste: [GalerieStueck]
    @State private var aktuell: String
    @Environment(\.dismiss) private var dismiss
    @State private var teilen: [Any]?
    @State private var meldung: String?

    init(liste: [GalerieStueck], start: String) {
        self.liste = liste
        _aktuell = State(initialValue: start)
    }

    private var stueck: GalerieStueck? { liste.first { $0.id == aktuell } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $aktuell) {
                ForEach(liste) { s in GalerieSeite(stueck: s, aktiv: s.id == aktuell).tag(s.id) }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark").padding(12).background(.ultraThinMaterial, in: .circle) }
                    .accessibilityLabel("Schließen")
                Spacer()
                if let stueck {
                    Text(stueck.zeit.formatted(date: .abbreviated, time: .shortened)).font(.footnote)
                }
                Spacer()
                Button { Task { await vorbereitenTeilen() } } label: { Image(systemName: "square.and.arrow.up").padding(12).background(.ultraThinMaterial, in: .circle) }
                    .accessibilityLabel("Teilen")
                Button { Task { await speichern() } } label: { Image(systemName: "arrow.down.to.line").padding(12).background(.ultraThinMaterial, in: .circle) }
                    .accessibilityLabel("In Aufnahmen speichern")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
        }
        .overlay(alignment: .bottom) {
            if let meldung {
                Text(meldung).font(.footnote.weight(.medium)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: .capsule).padding(.bottom, 30)
                    .task(id: meldung) {
                        try? await Task.sleep(for: .seconds(2))
                        self.meldung = nil
                    }
            }
        }
        .sheet(isPresented: Binding(get: { teilen != nil }, set: { if !$0 { teilen = nil } })) {
            if let teilen { AktivitaetsAnsicht(objekte: teilen).presentationDetents([.medium, .large]) }
        }
    }

    private func vorbereitenTeilen() async {
        guard let stueck, let url = await GalerieDatei.datei(stueck) else { meldung = "Noch nicht geladen"; return }
        if stueck.art == .video {
            teilen = [Videobild.abspielbar(url)]
        } else if let bild = await Bilddatei.laden(url) {
            teilen = [bild]
        }
    }

    private func speichern() async {
        guard let stueck else { return }
        do {
            try await AufnahmenSpeichern.speichern([stueck.medium])
            Haptik.leicht()
            meldung = "In Aufnahmen gespeichert"
        } catch {
            meldung = "Speichern ging nicht"
        }
    }
}

private struct GalerieSeite: View {
    let stueck: GalerieStueck
    let aktiv: Bool
    @State private var bild: UIImage?
    @State private var spieler: AVPlayer?

    var body: some View {
        Group {
            if stueck.art == .video {
                if let spieler { VideoPlayer(player: spieler) } else { ProgressView().tint(.white) }
            } else if let bild {
                Image(uiImage: bild).resizable().scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: stueck.id) {
            guard let url = await GalerieDatei.datei(stueck) else { return }
            if stueck.art == .video {
                spieler = AVPlayer(url: Videobild.abspielbar(url))
            } else {
                bild = await Bilddatei.laden(url, maxPixel: 2048)
            }
        }
        .onChange(of: aktiv) { _, an in if !an { spieler?.pause() } }
        .onDisappear { spieler?.pause() }
    }
}

private struct AktivitaetsAnsicht: UIViewControllerRepresentable {
    let objekte: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: objekte, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
