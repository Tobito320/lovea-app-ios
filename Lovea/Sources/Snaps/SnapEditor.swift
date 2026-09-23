import AVKit
import SwiftUI
import UIKit

/// What the camera handed the editor (Z-6.1 → Z-6.2).
enum SnapInhalt {
    case foto(UIImage)
    case video(URL)
}

/// Snap editor (Z-6.2): text bar (draggable vertically, pinch to scale), a small `Canvas` doodle
/// layer, and stickers/favorite GIFs/figure stickers (via the reused `GifStickerBlatt`, placed &
/// draggable). All element positions are fractions (0...1) of the content area, so the exact same
/// numbers work in the live preview (whatever size the phone gives it) and in `SnapExport`'s
/// flatten pass (the photo's/video's real pixel size) — one set of math, two renders.
struct SnapEditor: View {
    let inhalt: SnapInhalt
    let ich: Person
    let antwortAuf: String?
    let onFertig: () -> Void
    /// Block 18 tray mode (chat photo attachments): the check button hands the flattened JPEG back
    /// instead of sending a snap; nothing is ever sent from here in this mode.
    var onUebernehmen: ((Data) -> Void)? = nil
    /// X button. Defaults to `onFertig`; the camera flow uses it to go back to the camera (Snapchat).
    var onVerwerfen: (() -> Void)? = nil

    struct SnapText { var text = ""; var y: CGFloat = 0.5; var skala: CGFloat = 1 }
    struct SnapSticker: Identifiable { let id = UUID(); let bild: UIImage; var x: CGFloat = 0.5; var y: CGFloat = 0.5 }
    struct SnapLinie { var punkte: [CGPoint]; var farbe: Color } // `punkte` are fractions too

    @State private var text = SnapText()
    @State private var textBearbeitenOffen = false
    @State private var textZiehtGerade = false
    @State private var textYStart: CGFloat = 0.5
    @State private var textSkaliertGerade = false
    @State private var textSkalaStart: CGFloat = 1

    @State private var sticker: [SnapSticker] = []
    @State private var ziehendeStickerID: UUID?
    @State private var stickerZiehStart: CGPoint = .zero
    @State private var stickerBlattOffen = false

    @State private var linien: [SnapLinie] = []
    @State private var aktuelleLinie: [CGPoint] = []
    @State private var zeichnenAktiv = false
    @State private var doodleFarbe = Color.white

    @State private var bleibt = false
    @State private var sendetGerade = false
    @State private var videoSpieler: AVPlayer?
    /// The photo's/video's own aspect ratio — the content box below is locked to this, so the same
    /// (fraction, fraction) numbers land on the same spot live and in `SnapExport`'s flatten pass.
    /// Without this the box defaulted to the *screen's* aspect, `.scaledToFill` silently cropped
    /// the content to match, and every element ended up shifted in the exported snap.
    @State private var inhaltAspekt: CGFloat = 3.0 / 4.0

    private static let doodleFarben: [Color] = [.white, .black, Color.loveaRose, .yellow, .green, .blue]
    /// Fraction of the content width — shared with `SnapExport`'s static re-render so a stroke has
    /// the same visual thickness live and in the flattened snap.
    static let doodleLinienbreite: CGFloat = 0.015

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    basisInhalt
                    lebendigeUeberlagerung(groesse: geo.size)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(doodleGeste(groesse: geo.size))
            }
            .aspectRatio(inhaltAspekt, contentMode: .fit)

            VStack {
                obereLeiste
                if zeichnenAktiv { farbAuswahl }
                Spacer()
                untereLeiste
            }
        }
        .statusBarHidden()
        .sheet(isPresented: $stickerBlattOffen) {
            GifStickerBlatt(ich: ich, antwortAuf: nil, aufBildWahl: { bild in
                sticker.append(SnapSticker(bild: bild))
            }, onGesendet: { stickerBlattOffen = false })
        }
        .sheet(isPresented: $textBearbeitenOffen) {
            NavigationStack {
                TextField("Text", text: $text.text)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .navigationTitle("Text")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { textBearbeitenOffen = false } } }
            }
            .presentationDetents([.height(160)])
        }
        .task {
            if case .video(let url) = inhalt { videoSpieler = AVPlayer(url: url) }
            await aspektErmitteln()
        }
        .onDisappear { videoSpieler?.pause() }
    }

    /// Same source of truth `SnapExport.video` uses for `upright` — keeps the editor's aspect and
    /// the export's aspect identical even when the camera's `preferredTransform` rotates the frame.
    private func aspektErmitteln() async {
        switch inhalt {
        case .foto(let bild):
            guard bild.size.height > 0 else { return }
            inhaltAspekt = bild.size.width / bild.size.height
        case .video(let url):
            let asset = AVURLAsset(url: url)
            guard let track = try? await asset.loadTracks(withMediaType: .video).first,
                  let naturalSize = try? await track.load(.naturalSize),
                  let transform = try? await track.load(.preferredTransform)
            else { return }
            let upright = CGSize(width: abs(naturalSize.applying(transform).width), height: abs(naturalSize.applying(transform).height))
            guard upright.height > 0 else { return }
            inhaltAspekt = upright.width / upright.height
        }
    }

    // MARK: - Base content + live overlay

    /// `.scaledToFit`, not `.scaledToFill` — the container above is already locked to this content's
    /// own aspect ratio, so nothing needs cropping; filling here would just reintroduce the mismatch.
    @ViewBuilder private var basisInhalt: some View {
        switch inhalt {
        case .foto(let bild):
            Image(uiImage: bild).resizable().scaledToFit()
        case .video:
            if let videoSpieler {
                VideoPlayer(player: videoSpieler).disabled(true)
                    .onAppear { videoSpieler.play() }
            }
        }
    }

    @ViewBuilder private func lebendigeUeberlagerung(groesse: CGSize) -> some View {
        Canvas { context, _ in
            for linie in linien { zeichnePfad(linie, in: &context, groesse: groesse) }
            if aktuelleLinie.count > 1 { zeichnePfad(SnapLinie(punkte: aktuelleLinie, farbe: doodleFarbe), in: &context, groesse: groesse) }
        }
        .allowsHitTesting(false)

        ForEach(sticker) { element in
            Image(uiImage: element.bild)
                .resizable().scaledToFit()
                .frame(width: groesse.width * 0.28)
                .position(x: element.x * groesse.width, y: element.y * groesse.height)
                // `.highPriorityGesture`, not `.gesture` — guarantees this wins over the doodle
                // drag on the ancestor `ZStack` instead of relying on SwiftUI's usual (but here
                // untested, no local compiler) descendant-first tie-break.
                .highPriorityGesture(stickerGeste(id: element.id, groesse: groesse))
        }

        if !text.text.isEmpty {
            Text(text.text)
                .font(.system(size: groesse.width * 0.07, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 3)
                .scaleEffect(text.skala)
                .position(x: groesse.width / 2, y: text.y * groesse.height)
                .highPriorityGesture(textDragGeste(groesse: groesse))
                .simultaneousGesture(textSkaliergeste)
                .onTapGesture { textBearbeitenOffen = true }
        }
    }

    private func zeichnePfad(_ linie: SnapLinie, in context: inout GraphicsContext, groesse: CGSize) {
        var pfad = Path()
        let punkte = linie.punkte.map { CGPoint(x: $0.x * groesse.width, y: $0.y * groesse.height) }
        guard let erster = punkte.first else { return }
        pfad.move(to: erster)
        for punkt in punkte.dropFirst() { pfad.addLine(to: punkt) }
        // Fraction of the content width, not an absolute point count — a photo is often thousands
        // of pixels wide, an absolute width would look right live and near-invisible once exported.
        context.stroke(pfad, with: .color(linie.farbe), style: StrokeStyle(lineWidth: groesse.width * Self.doodleLinienbreite, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Gestures

    /// Doodle drawing (Z-6.2): active only while `zeichnenAktiv`; a no-op drag otherwise. Attached
    /// to the whole content area, so `.highPriorityGesture` on stickers/text (above) is what keeps
    /// dragging one of those from also being read as a doodle stroke underneath it.
    private func doodleGeste(groesse: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { wert in
                guard zeichnenAktiv, groesse.width > 0, groesse.height > 0 else { return }
                aktuelleLinie.append(CGPoint(x: wert.location.x / groesse.width, y: wert.location.y / groesse.height))
            }
            .onEnded { _ in
                guard zeichnenAktiv, aktuelleLinie.count > 1 else { aktuelleLinie = []; return }
                linien.append(SnapLinie(punkte: aktuelleLinie, farbe: doodleFarbe))
                aktuelleLinie = []
            }
    }

    /// One shared "drag anchor" for all stickers (only one finger drags at a time in practice) —
    /// simpler than a `@GestureState` per dynamic array element.
    private func stickerGeste(id: UUID, groesse: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { wert in
                guard let index = sticker.firstIndex(where: { $0.id == id }) else { return }
                if ziehendeStickerID != id {
                    ziehendeStickerID = id
                    stickerZiehStart = CGPoint(x: sticker[index].x, y: sticker[index].y)
                }
                sticker[index].x = min(max(0, stickerZiehStart.x + wert.translation.width / groesse.width), 1)
                sticker[index].y = min(max(0, stickerZiehStart.y + wert.translation.height / groesse.height), 1)
            }
            .onEnded { _ in ziehendeStickerID = nil }
    }

    /// Text bar: vertical drag only (Snapchat style), plus pinch to scale.
    private func textDragGeste(groesse: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { wert in
                if !textZiehtGerade { textZiehtGerade = true; textYStart = text.y }
                text.y = min(max(0.1, textYStart + wert.translation.height / groesse.height), 0.9)
            }
            .onEnded { _ in textZiehtGerade = false }
    }

    private var textSkaliergeste: some Gesture {
        MagnificationGesture()
            .onChanged { wert in
                if !textSkaliertGerade { textSkaliertGerade = true; textSkalaStart = text.skala }
                text.skala = min(max(0.5, textSkalaStart * wert), 3)
            }
            .onEnded { _ in textSkaliertGerade = false }
    }

    // MARK: - Chrome

    private var obereLeiste: some View {
        HStack {
            Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); (onVerwerfen ?? onFertig)() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel(onVerwerfen == nil ? "Abbrechen" : "Verwerfen")
            Spacer()
            Button { textBearbeitenOffen = true } label: { Image(systemName: "textformat").frame(width: 44, height: 44) }
                .accessibilityLabel("Text hinzufügen")
            Button { zeichnenAktiv.toggle() } label: { Image(systemName: zeichnenAktiv ? "pencil.circle.fill" : "pencil.circle").frame(width: 44, height: 44) }
                .accessibilityLabel("Kritzeln")
                .accessibilityValue(zeichnenAktiv ? "an" : "aus")
            Button { stickerBlattOffen = true } label: { Image(systemName: "face.smiling").frame(width: 44, height: 44) }
                .accessibilityLabel("Sticker hinzufügen")
        }
        .font(.title2)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 3) // stays readable over a bright photo
        .padding()
    }

    private static let doodleFarbNamen = ["Weiß", "Schwarz", "Rosé", "Gelb", "Grün", "Blau"] // same order as `doodleFarben`

    private var farbAuswahl: some View {
        HStack(spacing: 4) {
            ForEach(Self.doodleFarben.indices, id: \.self) { index in
                let farbe = Self.doodleFarben[index]
                Circle().fill(farbe)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(.white, lineWidth: doodleFarbe == farbe ? 2 : 0))
                    .frame(width: 38, height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture { doodleFarbe = farbe }
                    .accessibilityLabel(Self.doodleFarbNamen[index])
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(doodleFarbe == farbe ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .background(.thinMaterial, in: Capsule())
    }

    private var untereLeiste: some View {
        HStack {
            if onUebernehmen == nil {
                Toggle("bleibt im Chat", isOn: $bleibt)
                    .toggleStyle(.switch)
                    .tint(Color.loveaRose)
                    .fixedSize()
                    .foregroundStyle(.white)
            }

            Spacer()

            Button { senden() } label: {
                if sendetGerade {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: onUebernehmen == nil ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 40)).foregroundStyle(.white)
                }
            }
            .disabled(sendetGerade)
            .accessibilityLabel(onUebernehmen == nil ? "Senden" : "Übernehmen")
        }
        .padding()
        .background(.black.opacity(0.35))
    }

    // MARK: - Send (Z-6.2: flatten, then reuse Block 5's upload helpers)

    /// Dismisses as soon as the flatten step is done and the op is queued — NOT after the network
    /// upload finishes, which `ChatMedien.snapFotoSenden`/`snapVideoSenden` would otherwise make
    /// this whole function (and the spinner) wait on for a possibly large file.
    private func senden() {
        guard !sendetGerade else { return }
        sendetGerade = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let onUebernehmen {
            // ponytail: tray mode edits photos only (videos in the tray aren't editable yet).
            guard case .foto(let bild) = inhalt else { onFertig(); return }
            Task {
                if let jpeg = await SnapExport.foto(quelle: bild, linien: linien, sticker: sticker, text: text) { onUebernehmen(jpeg) }
                onFertig()
            }
            return
        }
        switch inhalt {
        case .foto(let bild):
            Task {
                let jpeg = await SnapExport.foto(quelle: bild, linien: linien, sticker: sticker, text: text)
                onFertig()
                if let jpeg { await ChatMedien.snapFotoSenden(jpeg: jpeg, bleibt: bleibt, antwortAuf: antwortAuf) }
            }
        case .video(let url):
            Task {
                defer { onFertig() }
                guard let exportURL = await SnapExport.video(quelle: url, linien: linien, sticker: sticker, text: text) else { return }
                Task { await ChatMedien.snapVideoSenden(quelle: exportURL, bleibt: bleibt, antwortAuf: antwortAuf) }
            }
        }
    }
}

/// Resolves a chosen GIF/sticker (Z-6.2's sticker picker) down to one static `UIImage`, for
/// placing on the snap canvas — first frame only for an animated GIF, same simplification
/// `MedienKodierung`'s existing thumbnailing already makes elsewhere in Chat/Medien.
@MainActor
enum SnapBildQuelle {
    static func gif(_ urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString), let (daten, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return await Task.detached(priority: .userInitiated) { UIImage(data: daten)?.preparingForDisplay() }.value
    }

    static func medium(_ id: String) async -> UIImage? {
        // Split, not `A ?? B ?? (try? await C)`: an `await` buried in a `??` chain doesn't
        // type-check ("'async' call in a function that does not support concurrency") — same fix
        // already applied project-wide in `StickerKachel`/`GifStickerBlatt`.
        var url = ChatMedien.eigeneQuellen[id] ?? Medien.lokal(id)
        if url == nil { url = try? await Medien.holen(id) }
        guard let url else { return nil }
        return await Bilddatei.laden(url, maxPixel: 1024)
    }
}
