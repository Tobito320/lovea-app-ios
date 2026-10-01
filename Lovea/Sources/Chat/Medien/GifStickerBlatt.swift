import PhotosUI
import SwiftUI
import UIKit

/// Sticker/GIF sheet (Z-5.3, R7): Reiter Wir / Ahmed / Annika / Favoriten / GIFs.
///
/// `aufBildWahl` (Block 6, Z-6.2): when set, every tile hands its flattened `UIImage` to this
/// closure instead of sending it to the chat — the Snap editor's "Sticker" button reuses this
/// whole sheet (all tabs) rather than rebuilding a picker.
struct GifStickerBlatt: View {
    let ich: Person
    let antwortAuf: String?
    var aufBildWahl: ((UIImage) -> Void)? = nil
    let onGesendet: () -> Void

    private enum Reiter: String, CaseIterable { case wir = "Wir", ahmed = "Ahmed", annika = "Annika", favoriten = "Favoriten", gifs = "GIFs" }
    @State private var reiter = Reiter.wir

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Reiter", selection: $reiter) {
                    // "Favoriten" ist das längste Label unter 5 Segmenten (390pt knapp) — Stern statt Text.
                    ForEach(Reiter.allCases, id: \.self) { eintrag in
                        if eintrag == .favoriten {
                            Image(systemName: "star.fill").tag(eintrag).accessibilityLabel("Favoriten")
                        } else {
                            Text(eintrag.rawValue).tag(eintrag)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch reiter {
                case .wir: WirStickerAnsicht(ich: ich, antwortAuf: antwortAuf, wer: .beide, aufBildWahl: aufBildWahl, onGesendet: onGesendet)
                case .ahmed: WirStickerAnsicht(ich: ich, antwortAuf: antwortAuf, wer: .ahmed, aufBildWahl: aufBildWahl, onGesendet: onGesendet)
                case .annika: WirStickerAnsicht(ich: ich, antwortAuf: antwortAuf, wer: .annika, aufBildWahl: aufBildWahl, onGesendet: onGesendet)
                case .favoriten: FavoritenAnsicht(ich: ich, antwortAuf: antwortAuf, aufBildWahl: aufBildWahl, onGesendet: onGesendet)
                case .gifs: GifSuche(ich: ich, antwortAuf: antwortAuf, aufBildWahl: aufBildWahl, onGesendet: onGesendet)
                }
            }
            .navigationTitle("Sticker & GIFs")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct GifSuche: View {
    let ich: Person
    let antwortAuf: String?
    var aufBildWahl: ((UIImage) -> Void)? = nil
    let onGesendet: () -> Void

    private enum Zustand { case laden, ok, nichtEingerichtet, fehler }
    @State private var suchtext = ""
    @State private var ergebnisse: [KlipyClient.Gif] = []
    @State private var zustand = Zustand.laden
    @State private var sucheTask: Task<Void, Never>?

    /// Fix round 2: quick searches under the field; tapping one runs it.
    private static let kategorien = [
        "Gym", "Schlafen", "Guten Morgen", "Gute Nacht", "Liebe", "Kuss", "Lustig",
        "Hunger", "Traurig", "Wütend", "Party", "Ja", "Nein",
    ]

    var body: some View {
        VStack(spacing: 10) {
            suchfeld
            kategorieLeiste
            switch zustand {
            case .laden:
                ladeRaster
            case .nichtEingerichtet:
                ContentUnavailableView("Nicht eingerichtet", systemImage: "photo.badge.exclamationmark")
            case .fehler:
                ContentUnavailableView("Fehler beim Laden", systemImage: "wifi.slash")
            case .ok:
                if ergebnisse.isEmpty {
                    ContentUnavailableView.search(text: suchtext)
                } else {
                    ScrollView { masonry(KlipyClient.spalten(ergebnisse)) }
                }
            }
        }
        .onChange(of: suchtext) { _, neu in debounceSuche(neu) }
        .task { debounceSuche("") }
    }

    /// System-style search field (tinted fill, magnifier, clear button) instead of a bordered box.
    private var suchfeld: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("GIFs suchen", text: $suchtext)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !suchtext.isEmpty {
                Button { suchtext = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 40)
        .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var kategorieLeiste: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.kategorien, id: \.self) { kategorie in
                    let aktiv = suchtext == kategorie
                    Button {
                        Haptik.auswahl()
                        suchtext = aktiv ? "" : kategorie
                    } label: {
                        Text(kategorie)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .foregroundStyle(aktiv ? Color.white : Color.primary)
                            .background(aktiv ? Color.loveaRose : Color(uiColor: .tertiarySystemFill), in: .capsule)
                    }
                    .buttonStyle(.federnd)
                    .accessibilityAddTraits(aktiv ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Two columns, each cell exactly its GIF's aspect ratio, clipped to its own rounded rect.
    private func masonry(_ spalten: (links: [KlipyClient.Gif], rechts: [KlipyClient.Gif])) -> some View {
        HStack(alignment: .top, spacing: 8) {
            spalte(spalten.links)
            spalte(spalten.rechts)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func spalte(_ gifs: [KlipyClient.Gif]) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(gifs) { gif in
                if let url = URL(string: gif.url) { zelle(gif, url) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func zelle(_ gif: KlipyClient.Gif, _ url: URL) -> some View {
        Color.clear
            .aspectRatio(gif.breite > 0 && gif.hoehe > 0 ? gif.breite / gif.hoehe : 1, contentMode: .fit)
            .overlay { AnimiertesGif(url: url) }
            .clipShape(.rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
            .onTapGesture { senden(gif) }
            .accessibilityElement()
            .accessibilityLabel("GIF")
            .accessibilityAddTraits(.isButton)
            .contextMenu {
                Button("Zu Favoriten", systemImage: "star") {
                    ChatEinstellungen.shared.favoritSchalten(
                        .init(art: .gif, wert: gif.url, breite: gif.breite, hoehe: gif.hoehe), ich: ich
                    )
                }
            }
    }

    /// Shimmering cells while the list loads, same masonry shape.
    private var ladeRaster: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<2, id: \.self) { spalte in
                VStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { zeile in
                        LadeSchimmer()
                            .frame(height: CGFloat([120, 90, 150, 110][(zeile + spalte) % 4]))
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(.horizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityLabel("GIFs werden geladen")
    }

    /// Klipy's test key allows 100 calls/hour — debounced so typing doesn't burn through it.
    private func debounceSuche(_ text: String) {
        sucheTask?.cancel()
        sucheTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            zustand = .laden
            do {
                ergebnisse = try await KlipyClient.suchen(text)
                zustand = .ok
            } catch KlipyClient.Fehler.nichtEingerichtet {
                zustand = .nichtEingerichtet
            } catch {
                zustand = .fehler
            }
        }
    }

    private func senden(_ gif: KlipyClient.Gif) {
        if let aufBildWahl {
            Task {
                if let bild = await SnapBildQuelle.gif(gif.url) { aufBildWahl(bild) }
                onGesendet()
            }
            return
        }
        ChatHaptik.leicht()
        ChatModell.shared.gifSenden(url: gif.url, breite: gif.breite, hoehe: gif.hoehe, antwortAuf: antwortAuf)
        onGesendet()
    }
}

/// R7-Fix: "Favoriten" trägt jetzt zusätzlich "Eigene" (eigene Sticker — Foto-Freisteller + aus der
/// Zeichnen-Bibliothek gespeicherte) als erste Zeile, weil der alte Reiter "Sticker" (mit seiner
/// `EigeneSticker.alle(ich:)`-Liste) komplett entfernt wurde. Sonst gäbe es keinen Weg mehr, bereits
/// erstellte eigene Sticker zu sehen oder zu senden.
private struct FavoritenAnsicht: View {
    let ich: Person
    let antwortAuf: String?
    var aufBildWahl: ((UIImage) -> Void)? = nil
    let onGesendet: () -> Void

    @State private var fotoAuswahl: PhotosPickerItem?
    @State private var laeuft = false

    var body: some View {
        // Mitgelieferte (`asset:`) stehen schon in Wir/Ahmed/Annika, nicht doppelt hier.
        let eigene = EigeneSticker.alle(ich: ich).filter { MitgelieferteSticker.assetName($0) == nil }
        let favoriten = ChatEinstellungen.shared.favoriten(ich)
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                Section {
                    plusKachel
                    ForEach(eigene, id: \.self) { id in
                        StickerKachel(medienId: id)
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture { sendenEigenerSticker(id) }
                            .accessibilityElement()
                            .accessibilityLabel("Eigener Sticker")
                            .accessibilityAddTraits(.isButton)
                            .contextMenu {
                                Button("Zu Favoriten", systemImage: "star") {
                                    ChatEinstellungen.shared.favoritSchalten(.init(art: .sticker, wert: id, breite: nil, hoehe: nil), ich: ich)
                                }
                            }
                    }
                } header: {
                    kopfzeile("Eigene")
                }
                if !favoriten.isEmpty {
                    Section {
                        ForEach(favoriten) { eintrag in
                            kachel(eintrag)
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { senden(eintrag) }
                                .accessibilityElement()
                                .accessibilityLabel(eintrag.art == .gif ? "GIF" : "Sticker")
                                .accessibilityAddTraits(.isButton)
                                .contextMenu {
                                    Button("Aus Favoriten entfernen", systemImage: "star.slash", role: .destructive) {
                                        ChatEinstellungen.shared.favoritSchalten(eintrag, ich: ich)
                                    }
                                }
                        }
                    } header: {
                        kopfzeile("Favoriten")
                    }
                }
            }
            .padding()
        }
        .onChange(of: fotoAuswahl) { _, neu in erstelleAusFoto(neu) }
    }

    private func kopfzeile(_ titel: String) -> some View {
        Text(titel)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var plusKachel: some View {
        PhotosPicker(selection: $fotoAuswahl, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.thinMaterial)
                if laeuft { ProgressView() } else { Image(systemName: "plus").font(.title2) }
            }
        }
        .frame(height: 100)
        .accessibilityLabel("Sticker aus Foto erstellen")
    }

    private func erstelleAusFoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        laeuft = true
        Task {
            defer { laeuft = false; fotoAuswahl = nil }
            guard let daten = try? await item.loadTransferable(type: Data.self),
                  let freigestellt = await StickerErstellung.freistellen(daten),
                  let id = await ChatMedien.stickerHochladen(png: freigestellt)
            else { return }
            EigeneSticker.hinzufuegen(medienId: id)
        }
    }

    private func sendenEigenerSticker(_ id: String) {
        if let aufBildWahl {
            Task {
                if let bild = await SnapBildQuelle.medium(id) { aufBildWahl(bild) }
                onGesendet()
            }
            return
        }
        ChatModell.shared.stickerSenden(medienId: id, antwortAuf: antwortAuf)
        onGesendet()
    }

    @ViewBuilder private func kachel(_ eintrag: ChatEinstellungen.FavoritEintrag) -> some View {
        switch eintrag.art {
        case .gif:
            if let url = URL(string: eintrag.wert) { AnimiertesGif(url: url) }
        case .sticker:
            StickerKachel(medienId: eintrag.wert)
        }
    }

    private func senden(_ eintrag: ChatEinstellungen.FavoritEintrag) {
        if let aufBildWahl {
            Task {
                let bild: UIImage?
                switch eintrag.art {
                case .gif: bild = await SnapBildQuelle.gif(eintrag.wert)
                case .sticker:
                    if let name = MitgelieferteSticker.assetName(eintrag.wert) { bild = UIImage(named: name) }
                    else { bild = await SnapBildQuelle.medium(eintrag.wert) }
                }
                if let bild { aufBildWahl(bild) }
                onGesendet()
            }
            return
        }
        switch eintrag.art {
        case .gif: ChatModell.shared.gifSenden(url: eintrag.wert, breite: eintrag.breite ?? 0, hoehe: eintrag.hoehe ?? 0, antwortAuf: antwortAuf)
        case .sticker: ChatModell.shared.stickerSenden(medienId: eintrag.wert, antwortAuf: antwortAuf)
        }
        onGesendet()
    }
}

/// Z-40.2: mitgelieferte Sticker aus `Assets.xcassets/Sticker`. Gesendet als `asset:<name>` ohne
/// Upload. Namen stehen von Hand hier, weil sich ein Asset-Katalog nicht aufzählen lässt.
enum MitgelieferteSticker {
    static let praefix = "asset:"
    static let alle = [
        "wir-annika-kuss-winken", "wir-annika-rosen", "wir-annika-kichern", "wir-annika-schuechtern",
        "wir-annika-finger-grinsen", "wir-annika-finger-sw", "wir-annika-frech", "wir-annika-schulterblick",
        "wir-annika-zunge", "wir-annika-augenrollen", "wir-annika-telefon", "wir-annika-cheers",
        "wir-kuss-echt", "wir-kuss", "wir-umarmung", "wir-selfie", "wir-kino", "wir-gym",
        "wir-ich", "wir-du", "wir-zuhause", "wir-vermisse-dich", "wir-so-suess", "wir-lieblingsmensch",
        "wir-nur-wir", "wir-wir-immer", "wir-fuer-dich", "wir-danke", "wir-danke-dass-es-dich-gibt",
        "wir-du-bist-meine", "wir-pass-auf-dich-auf", "wir-so-gluecklich", "wir-gluecklich", "wir-mit-dir-besser",
        "wir-zusammen-besser", "wir-wenn-wir-zusammen", "wir-alles-wird-gut", "wir-so-gut-aus",
        "wir-gute-nacht", "wir-gute-nacht-bett", "wir-schlafen-gehen", "wir-noch-5-minuten", "wir-nur-noch-5-minuten",
        "wir-gelesen", "wir-gleich-schreiben", "wir-wer-hat-geschrieben", "wir-schon-wieder-online",
        "wir-hmm", "wir-interessant", "wir-interessant-tasse", "wir-interessant-trinken", "wir-echt-jetzt",
        "wir-keine-ahnung", "wir-keine-ahnung-2", "wir-nicht-frech", "wir-essen", "wir-wochenende",
        "wir-lernen-arbeit", "wir-zu-viel-zu-tun",
        "meme-drake", "meme-this-is-fine", "meme-side-eye",
    ]

    static func assetName(_ medienId: String) -> String? {
        medienId.hasPrefix(praefix) ? String(medienId.dropFirst(praefix.count)) : nil
    }

    static func medienId(_ name: String) -> String { praefix + name }
}

private struct WirStickerAnsicht: View {
    let ich: Person
    let antwortAuf: String?
    let wer: WirWer
    var aufBildWahl: ((UIImage) -> Void)? = nil
    let onGesendet: () -> Void

    @State private var kontextFilter: String?

    var body: some View {
        // Nur Namen, deren Bild im Bundle liegt: eine Liste, die dem Katalog voraus ist, zeigt keine Lücken.
        let namen = MitgelieferteSticker.alle.filter { UIImage(named: $0) != nil }
        let gefiltert = WirStickerFilter.gefiltert(namen, wer: wer, kontext: kontextFilter)
        VStack(spacing: 0) {
            kontextLeiste
            if gefiltert.isEmpty {
                ContentUnavailableView("Noch keine Sticker", systemImage: "heart.text.square")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(gefiltert, id: \.self) { name in
                            StickerKachel(medienId: MitgelieferteSticker.medienId(name))
                                .frame(width: 100, height: 100)
                                .contentShape(Rectangle())
                                .onTapGesture { senden(name) }
                                .accessibilityElement()
                                .accessibilityLabel("Sticker \(name.replacingOccurrences(of: "-", with: " "))")
                                .accessibilityAddTraits(.isButton)
                                .contextMenu {
                                    Button("Zu Favoriten", systemImage: "star") {
                                        ChatEinstellungen.shared.favoritSchalten(.init(art: .sticker, wert: MitgelieferteSticker.medienId(name), breite: nil, hoehe: nil), ich: ich)
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var kontextLeiste: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Alle", aktiv: kontextFilter == nil) { kontextFilter = nil }
                ForEach(WirStickerMeta.kontexte(fuer: wer), id: \.self) { kontext in
                    chip(kontext, aktiv: kontextFilter == kontext) { kontextFilter = kontext }
                }
            }
            .padding(.horizontal)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func chip(_ titel: String, aktiv: Bool, wahl: @escaping () -> Void) -> some View {
        Button {
            Haptik.auswahl()
            wahl()
        } label: {
            Text(titel)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .foregroundStyle(aktiv ? Color.white : Color.primary)
                .background(aktiv ? Color.loveaRose : Color(uiColor: .tertiarySystemFill), in: .capsule)
        }
        .buttonStyle(.federnd)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }

    private func senden(_ name: String) {
        if let aufBildWahl {
            if let bild = UIImage(named: name) { aufBildWahl(bild) }
            onGesendet()
            return
        }
        ChatHaptik.leicht()
        ChatModell.shared.stickerSenden(medienId: MitgelieferteSticker.medienId(name), antwortAuf: antwortAuf)
        onGesendet()
    }
}

/// A sticker medium's thumbnail — downloads (or reads the local/own copy) then renders the PNG.
struct StickerKachel: View {
    let medienId: String
    @State private var bild: UIImage?

    var body: some View {
        // Mitgelieferte Sticker mit Bewegung liegen zusätzlich als `<name>.gif` im Bundle (StickerGIFs/).
        if let name = MitgelieferteSticker.assetName(medienId), let gif = Bundle.main.url(forResource: name, withExtension: "gif") {
            AnimiertesGif(url: gif, fuellen: false)
        } else {
            standbild
        }
    }

    private var standbild: some View {
        Group {
            if let bild {
                Image(uiImage: bild).resizable().scaledToFit()
            } else {
                Rectangle().fill(.thinMaterial)
            }
        }
        .task(id: medienId) {
            if let name = MitgelieferteSticker.assetName(medienId) { bild = UIImage(named: name); return }
            var url = ChatMedien.eigeneQuellen[medienId] ?? Medien.lokal(medienId)
            if url == nil { url = try? await Medien.holen(medienId) }
            guard let url else { return }
            bild = await Bilddatei.laden(url, maxPixel: 420)
        }
    }
}
