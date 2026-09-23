import PhotosUI
import SwiftUI
import UIKit

/// GIF/Sticker sheet (Z-5.3): Reiter GIFs / Favoriten / Sticker.
///
/// `aufBildWahl` (Block 6, Z-6.2): when set, every tile hands its flattened `UIImage` to this
/// closure instead of sending it to the chat — the Snap editor's "Sticker" button reuses this
/// whole sheet (all three tabs) rather than rebuilding a picker.
struct GifStickerBlatt: View {
    let ich: Person
    let antwortAuf: String?
    var aufBildWahl: ((UIImage) -> Void)? = nil
    let onGesendet: () -> Void

    private enum Reiter: String, CaseIterable { case gifs = "GIFs", favoriten = "Favoriten", sticker = "Sticker" }
    @State private var reiter = Reiter.gifs

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Reiter", selection: $reiter) {
                    ForEach(Reiter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                switch reiter {
                case .gifs: GifSuche(ich: ich, antwortAuf: antwortAuf, aufBildWahl: aufBildWahl, onGesendet: onGesendet)
                case .favoriten: FavoritenAnsicht(ich: ich, antwortAuf: antwortAuf, aufBildWahl: aufBildWahl, onGesendet: onGesendet)
                case .sticker: StickerAnsicht(ich: ich, antwortAuf: antwortAuf, aufBildWahl: aufBildWahl, onGesendet: onGesendet)
                }
            }
            .navigationTitle("GIFs & Sticker")
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

    var body: some View {
        VStack(spacing: 8) {
            TextField("Suchen", text: $suchtext)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .onChange(of: suchtext) { _, neu in debounceSuche(neu) }

            switch zustand {
            case .laden:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .nichtEingerichtet:
                ContentUnavailableView("Nicht eingerichtet", systemImage: "photo.badge.exclamationmark")
            case .fehler:
                ContentUnavailableView("Fehler beim Laden", systemImage: "wifi.slash")
            case .ok:
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        ForEach(ergebnisse) { gif in
                            if let url = URL(string: gif.url) {
                                AnimiertesGif(url: url)
                                    .aspectRatio(gif.breite > 0 && gif.hoehe > 0 ? gif.breite / gif.hoehe : 1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .onTapGesture { senden(gif) }
                                    .contextMenu {
                                        Button("Zu Favoriten", systemImage: "star") {
                                            ChatEinstellungen.shared.favoritSchalten(
                                                .init(art: .gif, wert: gif.url, breite: gif.breite, hoehe: gif.hoehe), ich: ich
                                            )
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task { debounceSuche("") }
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
        ChatModell.shared.gifSenden(url: gif.url, breite: gif.breite, hoehe: gif.hoehe, antwortAuf: antwortAuf)
        onGesendet()
    }
}

private struct FavoritenAnsicht: View {
    let ich: Person
    let antwortAuf: String?
    var aufBildWahl: ((UIImage) -> Void)? = nil
    let onGesendet: () -> Void

    var body: some View {
        let favoriten = ChatEinstellungen.shared.favoriten(ich)
        Group {
            if favoriten.isEmpty {
                ContentUnavailableView("Keine Favoriten", systemImage: "star")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(favoriten) { eintrag in
                            kachel(eintrag)
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { senden(eintrag) }
                                .contextMenu {
                                    Button("Aus Favoriten entfernen", systemImage: "star.slash", role: .destructive) {
                                        ChatEinstellungen.shared.favoritSchalten(eintrag, ich: ich)
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
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
                case .sticker: bild = await SnapBildQuelle.medium(eintrag.wert)
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

private struct StickerAnsicht: View {
    let ich: Person
    let antwortAuf: String?
    var aufBildWahl: ((UIImage) -> Void)? = nil
    let onGesendet: () -> Void

    @State private var fotoAuswahl: PhotosPickerItem?
    @State private var laeuft = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                PhotosPicker(selection: $fotoAuswahl, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(.thinMaterial)
                        if laeuft { ProgressView() } else { Image(systemName: "plus").font(.title2) }
                    }
                }
                .frame(width: 90, height: 90)

                ForEach(FreundschaftsSticker.alle) { figurenSticker in
                    figurenSticker.ansicht(ahmed: FigurenModell.shared.aussehen(.ahmed), annika: FigurenModell.shared.aussehen(.annika))
                        .scaleEffect(90 / 320)
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture { senden(figurenSticker: figurenSticker) }
                }

                ForEach(EigeneSticker.alle(ich: ich), id: \.self) { id in
                    StickerKachel(medienId: id)
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture { sendenEigenerSticker(id) }
                        .contextMenu {
                            Button("Zu Favoriten", systemImage: "star") {
                                ChatEinstellungen.shared.favoritSchalten(.init(art: .sticker, wert: id, breite: nil, hoehe: nil), ich: ich)
                            }
                        }
                }
            }
            .padding()
        }
        .onChange(of: fotoAuswahl) { _, neu in erstelleAusFoto(neu) }
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

    private func senden(figurenSticker: FreundschaftsSticker) {
        guard let png = figurenSticker.png(ahmed: FigurenModell.shared.aussehen(.ahmed), annika: FigurenModell.shared.aussehen(.annika)) else { return }
        if let aufBildWahl {
            if let bild = UIImage(data: png) { aufBildWahl(bild) }
            onGesendet()
            return
        }
        laeuft = true
        Task {
            defer { laeuft = false }
            guard let id = await ChatMedien.stickerHochladen(png: png) else { return }
            ChatModell.shared.stickerSenden(medienId: id, antwortAuf: antwortAuf)
            onGesendet()
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
}

/// A sticker medium's thumbnail — downloads (or reads the local/own copy) then renders the PNG.
struct StickerKachel: View {
    let medienId: String
    @State private var bild: UIImage?

    var body: some View {
        Group {
            if let bild {
                Image(uiImage: bild).resizable().scaledToFit()
            } else {
                Rectangle().fill(.thinMaterial)
            }
        }
        .task(id: medienId) {
            var url = ChatMedien.eigeneQuellen[medienId] ?? Medien.lokal(medienId)
            if url == nil { url = try? await Medien.holen(medienId) }
            bild = url.flatMap { UIImage(contentsOfFile: $0.path) }
        }
    }
}
