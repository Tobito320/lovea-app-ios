import AVKit
import CoreImage
import SwiftUI
import UIKit

/// What the camera handed the editor (Z-6.1 → Z-6.2).
enum SnapInhalt {
    case foto(UIImage)
    case video(URL)
}

/// Snap-Editor im CapCut-Aufbau: Vorschau oben, bei Video Play-Zeile und Zeitleiste (Filmstreifen,
/// feste Abspiel-Linie in der Mitte), unten die Werkzeugleiste. Ein Werkzeug öffnet ein Panel
/// statt der Leiste (kein Sheet). Alle Element-Positionen sind Bruchteile (0...1) der Inhaltsfläche,
/// damit Live-Vorschau und `SnapExport` (echte Pixelgröße) dieselben Zahlen rechnen.
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
    /// Filter picked on the camera screen; applied once when the editor opens.
    var startFilter: SnapFilter = .original

    struct SnapText {
        var text = ""
        var x: CGFloat = 0.5
        var y: CGFloat = 0.5
        var skala: CGFloat = 1
        var winkel: Double = 0
        var schrift = SnapSchrift.fett
        var stil = SnapTextStil.schlicht
        var farbe = Color.white
    }
    struct SnapSticker: Identifiable {
        let id = UUID()
        let bild: UIImage
        var x: CGFloat = 0.5
        var y: CGFloat = 0.5
        var skala: CGFloat = 1
        var winkel: Double = 0
    }
    struct SnapLinie { var punkte: [CGPoint]; var farbe: Color } // `punkte` are fractions too

    /// Was gerade markiert ist (weißer Rahmen): der Clip auf der Zeitleiste, der Text oder ein Sticker.
    enum Auswahl: Equatable {
        case clip, text
        case sticker(UUID)
    }

    /// Benannter Koordinatenraum der Inhaltsfläche — die Element-Gesten messen darin.
    static let inhaltRaum = "snap.inhalt"

    @State private var text = SnapText()
    @State private var sticker: [SnapSticker] = []
    @State private var auswahl: Auswahl?

    @State private var linien: [SnapLinie] = []
    @State private var aktuelleLinie: [CGPoint] = []
    @State private var doodleFarbe = Color.white

    @State private var panel: SnapPanel?

    @AppStorage(SnapFilterAnzeige.schluessel) private var filterAn = true // same key `SnapFilterAnzeige.an` reads
    @State private var bleibt = false
    @State private var sendetGerade = false
    @State private var sendeFehler: String?

    // Video
    @State private var videoSpieler: AVPlayer?
    /// Schnittplan (kürzen, Teile entfernen, stumm); erst beim Senden umgesetzt. `nil` = noch nicht geladen / Foto.
    @State private var plan: SnapSchnitt?
    @State private var filmbilder: [UIImage] = []
    @State private var zeit: Double = 0
    @State private var spielt = false
    @State private var scrubStart: Double?
    @State private var markeStart: Double?
    @State private var schnittHinweis: String?

    // Filter
    @State private var ausgewaehlterFilter: SnapFilter = .original
    /// 0...100, wie der Regler. 100 = voller Filter.
    @State private var filterStaerke: Double = 100
    @State private var filterThumbnails: [SnapFilter: UIImage] = [:]
    /// Nur fürs Foto live gerendert (Video filtert sich über `videoSpieler`s eigene
    /// `AVVideoComposition`, siehe `vorschauAktualisieren`). `nil` = Originalbild zeigen.
    @State private var filterVorschauBild: UIImage?
    /// Bricht einen noch laufenden Vorschau-Render ab, wenn schon der nächste Filter/Wert kommt.
    @State private var vorschauTask: Task<Void, Never>?
    /// The photo's/video's own aspect ratio — the content box below is locked to this, so the same
    /// (fraction, fraction) numbers land on the same spot live and in `SnapExport`'s flatten pass.
    @State private var inhaltAspekt: CGFloat = 3.0 / 4.0

    /// Fraction of the content width — shared with `SnapExport`'s static re-render so a stroke has
    /// the same visual thickness live and in the flattened snap.
    static let doodleLinienbreite: CGFloat = 0.015

    var body: some View {
        VStack(spacing: 0) {
            SnapEditorKopfzeile(
                bleibt: onUebernehmen == nil ? $bleibt : nil,
                sendetGerade: sendetGerade,
                tray: onUebernehmen != nil,
                schliessenLabel: onVerwerfen == nil ? "Abbrechen" : "Verwerfen",
                onSchliessen: { Haptik.leicht(); (onVerwerfen ?? onFertig)() },
                onSenden: senden
            )
            vorschau
            if istVideo {
                abspielZeile
                if let plan { zeitleiste(plan: plan) }
            }
            if let sendeFehler {
                Text(sendeFehler).font(.caption).foregroundStyle(Color.orange).padding(.vertical, 4)
            }
            untenBereich
        }
        .background(Color.black.ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: panel)
        .task { await vorbereiten() }
        .task(id: spielt) { await wiedergabeSchleife() }
        .onChange(of: filterStaerke) { _, _ in vorschauAktualisieren() }
        .onDisappear { videoSpieler?.pause(); vorschauTask?.cancel() }
    }

    private func vorbereiten() async {
        if case .video(let url) = inhalt {
            videoSpieler = AVPlayer(url: url)
            if let dauer = await SnapSchnittExport.dauer(von: url) { plan = SnapSchnitt(dauer: dauer) }
            spielt = true
        }
        if filterAn, startFilter != .original {
            ausgewaehlterFilter = startFilter
            vorschauAktualisieren()
        }
        await aspektErmitteln()
        await thumbnailsErzeugen()
        if case .video(let url) = inhalt, let dauer = plan?.dauer {
            filmbilder = await SnapFilmbilder.laden(url: url, dauer: dauer)
        }
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

    private var istVideo: Bool {
        if case .video = inhalt { return true }
        return false
    }

    // MARK: - Vorschau

    private var vorschau: some View {
        GeometryReader { geo in
            ZStack {
                basisInhalt
                lebendigeUeberlagerung(groesse: geo.size)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(.named(Self.inhaltRaum))
            .contentShape(Rectangle())
            .gesture(TapGesture().onEnded { auswahl = nil }, including: panel == .zeichnen ? .none : .all)
            .gesture(zeichenGeste(groesse: geo.size), including: panel == .zeichnen ? .all : .none)
        }
        .aspectRatio(inhaltAspekt, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// `.scaledToFit`, not `.scaledToFill` — the container above is already locked to this content's
    /// own aspect ratio, so nothing needs cropping; filling here would just reintroduce the mismatch.
    @ViewBuilder private var basisInhalt: some View {
        switch inhalt {
        case .foto(let bild):
            Image(uiImage: filterVorschauBild ?? bild).resizable().scaledToFit()
        case .video:
            if let videoSpieler {
                VideoPlayer(player: videoSpieler).disabled(true)
            }
        }
    }

    @ViewBuilder private func lebendigeUeberlagerung(groesse: CGSize) -> some View {
        Canvas { context, _ in
            for linie in linien { zeichnePfad(linie, in: &context, groesse: groesse) }
            if aktuelleLinie.count > 1 { zeichnePfad(SnapLinie(punkte: aktuelleLinie, farbe: doodleFarbe), in: &context, groesse: groesse) }
        }
        .allowsHitTesting(false)

        ForEach($sticker) { $element in
            stickerElement($element, groesse: groesse)
        }
        .allowsHitTesting(panel != .zeichnen)

        if !text.text.isEmpty {
            textElement(groesse: groesse)
                .allowsHitTesting(panel != .zeichnen)
        }
    }

    private func stickerElement(_ element: Binding<SnapSticker>, groesse: CGSize) -> some View {
        let id = element.wrappedValue.id
        return SnapElementHuelle(
            x: element.x, y: element.y, skala: element.skala, winkel: element.winkel,
            groesse: groesse,
            ausgewaehlt: auswahl == .sticker(id),
            begrenzung: SnapElementRechnung.imBild,
            onAntippen: { auswahl = .sticker(id) },
            onBeruehrt: { auswahl = .sticker(id) },
            onLoeschen: { sticker.removeAll { $0.id == id }; auswahl = nil }
        ) {
            Image(uiImage: element.wrappedValue.bild)
                .resizable().scaledToFit()
                .frame(width: groesse.width * 0.28 * element.wrappedValue.skala)
        }
    }

    private func textElement(groesse: CGSize) -> some View {
        SnapElementHuelle(
            x: $text.x, y: $text.y, skala: $text.skala, winkel: $text.winkel,
            groesse: groesse,
            ausgewaehlt: auswahl == .text,
            begrenzung: { SnapTextPlatz.begrenzt(x: $0, y: $1) },
            onAntippen: { if auswahl == .text { panel = .text } else { auswahl = .text } },
            onBeruehrt: { auswahl = .text },
            onLoeschen: { text = SnapText(); auswahl = nil }
        ) {
            SnapTextAnzeige(text: text, breite: groesse.width)
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

    /// Kritzeln, solange das Zeichnen-Panel offen ist.
    private func zeichenGeste(groesse: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { wert in
                guard groesse.width > 0, groesse.height > 0 else { return }
                aktuelleLinie.append(CGPoint(x: wert.location.x / groesse.width, y: wert.location.y / groesse.height))
            }
            .onEnded { _ in
                guard aktuelleLinie.count > 1 else { aktuelleLinie = []; return }
                linien.append(SnapLinie(punkte: aktuelleLinie, farbe: doodleFarbe))
                aktuelleLinie = []
            }
    }

    // MARK: - Wiedergabe

    private var abspielZeile: some View {
        HStack(spacing: 12) {
            Button {
                Haptik.leicht()
                spielt.toggle()
            } label: {
                Image(systemName: spielt ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 40)
            }
            .accessibilityLabel(spielt ? "Pause" : "Abspielen")
            Text(SnapZeitleisteRechnung.anzeige(zeit: zeit, dauer: plan?.dauer ?? 0))
                .font(.footnote.monospacedDigit().weight(.medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    /// Läuft nur, solange `spielt` gilt (die `.task(id:)` startet bei jedem Wechsel neu).
    private func wiedergabeSchleife() async {
        guard spielt, let spieler = videoSpieler else {
            videoSpieler?.pause()
            return
        }
        spieler.play()
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
            if Task.isCancelled { break }
            wiedergabeSchritt(spieler)
        }
    }

    private func wiedergabeSchritt(_ spieler: AVPlayer) {
        guard let plan else { return }
        let jetzt = spieler.currentTime().seconds
        guard jetzt.isFinite else { return }
        if let ziel = SnapZeitleisteRechnung.sprungZiel(plan: plan, zeit: jetzt) {
            springe(zu: ziel)
            zeit = ziel
            spieler.play()
            return
        }
        zeit = jetzt
        if spieler.timeControlStatus == .paused { spieler.play() }
    }

    private func springe(zu sekunde: Double) {
        videoSpieler?.seek(to: CMTime(seconds: sekunde, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Zeitleiste

    private static let spurZeile: CGFloat = 26

    private func spurZeilen() -> Int {
        min((text.text.isEmpty ? 0 : 1) + sticker.count, 3)
    }

    private func zeitleiste(plan: SnapSchnitt) -> some View {
        let gesamt = SnapZeitleisteRechnung.breite(dauer: plan.dauer)
        let hoehe = SnapFilmstreifen.hoehe + CGFloat(spurZeilen()) * Self.spurZeile + 14
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    SnapFilmstreifen(bilder: filmbilder, plan: plan, ausgewaehlt: auswahl == .clip, onKuerzen: kuerzen)
                        .onTapGesture { auswahl = auswahl == .clip ? nil : .clip }
                    spurBalken(plan: plan, gesamt: gesamt)
                }
                .padding(.top, 6)
                .frame(width: gesamt, alignment: .leading)
                .offset(x: SnapZeitleisteRechnung.versatz(zeit: zeit, mitte: geo.size.width / 2))
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2, height: SnapFilmstreifen.hoehe + 12)
                    .offset(x: geo.size.width / 2 - 1, y: 0)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(scrubGeste(plan: plan))
        }
        .frame(height: hoehe)
        .background(Color.black)
    }

    @ViewBuilder private func spurBalken(plan: SnapSchnitt, gesamt: CGFloat) -> some View {
        let von = SnapZeitleisteRechnung.x(zeit: plan.anfang)
        let breite = SnapZeitleisteRechnung.x(zeit: plan.ende - plan.anfang)
        VStack(alignment: .leading, spacing: 4) {
            if !text.text.isEmpty {
                SnapSpurBalken(titel: text.text, farbe: Color.loveaRose, gewaehlt: auswahl == .text,
                               von: von, breite: breite, gesamtBreite: gesamt, onAntippen: { auswahl = .text })
            }
            ForEach(Array(sticker.prefix(max(0, 3 - (text.text.isEmpty ? 0 : 1))))) { element in
                SnapSpurBalken(titel: "Sticker", farbe: Color.orange, gewaehlt: auswahl == .sticker(element.id),
                               von: von, breite: breite, gesamtBreite: gesamt, onAntippen: { auswahl = .sticker(element.id) })
            }
        }
    }

    private func scrubGeste(plan: SnapSchnitt) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { wert in
                if scrubStart == nil { scrubStart = zeit; spielt = false }
                let neu = SnapZeitleisteRechnung.zeit(start: scrubStart ?? zeit, verschiebung: wert.translation.width, dauer: plan.dauer)
                zeit = neu
                springe(zu: neu)
            }
            .onEnded { _ in scrubStart = nil }
    }

    /// Griff-Zug: der Plan entscheidet (Mindestlänge), bei Ablehnung bleibt alles wie es war.
    private func kuerzen(anfang: Double, ende: Double) {
        schnittHinweis = nil
        plan?.kuerzen(anfang: anfang, ende: ende)
    }

    // MARK: - Panels

    @ViewBuilder private var untenBereich: some View {
        if let panel {
            panelAnsicht(panel)
                .transition(.move(edge: .bottom))
        } else {
            SnapWerkzeugLeiste(werkzeuge: SnapPanel.leiste(video: istVideo, filterAn: filterAn), onWahl: werkzeugWahl)
        }
    }

    private func werkzeugWahl(_ wahl: SnapPanel) {
        Haptik.auswahl()
        schnittHinweis = nil
        sendeFehler = nil
        switch wahl {
        case .text: auswahl = text.text.isEmpty ? nil : .text
        case .zeichnen: auswahl = nil
        default: break
        }
        panel = wahl
    }

    @ViewBuilder private func panelAnsicht(_ wahl: SnapPanel) -> some View {
        SnapPanelRahmen(titel: wahl.titel, onFertig: { panel = nil }) {
            switch wahl {
            case .bearbeiten: bearbeitenPanel
            case .ton: tonPanel
            case .text: SnapTextPanel(text: $text)
            case .sticker: stickerPanel
            case .filter: filterPanel
            case .zeichnen: zeichnenPanel
            }
        }
    }

    @ViewBuilder private var bearbeitenPanel: some View {
        if let plan {
            SnapBearbeitenPanel(
                plan: plan, markeStart: markeStart, hinweis: schnittHinweis,
                onAnfang: { schnittAendern { $0.kuerzen(anfang: zeit, ende: $0.ende) } },
                onEnde: { schnittAendern { $0.kuerzen(anfang: $0.anfang, ende: zeit) } },
                onMarke: markeSetzen,
                onWiederherstellen: { index in schnittAendern { $0.entfernenRueckgaengig(bei: index); return true } },
                onZuruecksetzen: {
                    var neu = SnapSchnitt(dauer: plan.dauer)
                    neu.stumm = plan.stumm
                    self.plan = neu
                    markeStart = nil
                    schnittHinweis = nil
                }
            )
        }
    }

    private var tonPanel: some View {
        SnapTonPanel(stumm: plan?.stumm ?? false, onUmschalten: {
            plan?.stumm.toggle()
            videoSpieler?.isMuted = plan?.stumm ?? false
        })
    }

    private var stickerPanel: some View {
        GifStickerBlatt(
            ich: ich, antwortAuf: nil,
            aufBildWahl: { bild in
                let neu = SnapSticker(bild: bild)
                sticker.append(neu)
                auswahl = .sticker(neu.id)
            },
            onGesendet: { panel = nil },
            panel: true
        )
        .frame(height: 300)
    }

    private var filterPanel: some View {
        SnapFilterPanel(
            vorschauBilder: filterThumbnails,
            gewaehlt: ausgewaehlterFilter,
            staerke: $filterStaerke,
            onWahl: waehleFilter
        )
    }

    private var zeichnenPanel: some View {
        SnapZeichnenPanel(farbe: $doodleFarbe, kannZurueck: !linien.isEmpty, onZurueck: { _ = linien.popLast() })
    }

    /// Ändert den Plan; `false` aus der Änderung = zu kurz, dann kurzer Hinweis im Panel.
    private func schnittAendern(_ aenderung: (inout SnapSchnitt) -> Bool) {
        guard var neu = plan else { return }
        if aenderung(&neu) {
            plan = neu
            schnittHinweis = nil
        } else {
            schnittHinweis = "Geht nicht: es müssen mindestens \(SnapSchnitt.zeit(SnapSchnitt.mindestdauer)) Video bleiben."
        }
    }

    private func markeSetzen() {
        guard let start = markeStart else {
            markeStart = zeit
            schnittHinweis = "Start gesetzt bei \(SnapSchnitt.zeit(zeit)). Zur Endstelle gehen und erneut tippen."
            return
        }
        markeStart = nil
        schnittAendern { $0.entfernen(von: start, bis: zeit) }
    }

    // MARK: - Filter

    /// Filter aus (Einstellungen) oder Stärke 0: immer das Original, egal was vorher gewählt war.
    private var wirksamerFilter: SnapFilter {
        filterStaerke > 0 ? SnapFilterAnzeige.filter(ausgewaehlterFilter, an: filterAn) : .original
    }

    private var wirksameStaerke: Double { min(max(filterStaerke, 0), 100) / 100 }

    private func waehleFilter(_ filter: SnapFilter) {
        guard filter != ausgewaehlterFilter else { return }
        Haptik.auswahl()
        ausgewaehlterFilter = filter
        filterStaerke = 100
        vorschauAktualisieren()
    }

    /// Live-Vorschau: Foto wird einmal neu gerendert (nicht pro Frame), Video bekommt dieselbe
    /// `AVVideoComposition` wie der Export auf seinen Player gesetzt (Akku-Regel: nur bei Wechsel).
    /// Kurze Wartezeit, damit ein ziehender Regler nicht pro Wert rendert.
    private func vorschauAktualisieren() {
        vorschauTask?.cancel()
        let filter = wirksamerFilter
        let staerke = wirksameStaerke
        switch inhalt {
        case .foto(let bild):
            vorschauTask = Task {
                try? await Task.sleep(for: .milliseconds(60))
                guard !Task.isCancelled else { return }
                let ergebnis = await Self.gefiltertesVorschauBild(quelle: bild, filter: filter, staerke: staerke)
                guard !Task.isCancelled else { return }
                filterVorschauBild = ergebnis
            }
        case .video(let url):
            vorschauTask = Task {
                try? await Task.sleep(for: .milliseconds(60))
                guard !Task.isCancelled else { return }
                let komposition = await filter.videoKomposition(fuer: AVURLAsset(url: url), staerke: staerke)
                guard !Task.isCancelled else { return }
                videoSpieler?.currentItem?.videoComposition = komposition
            }
        }
    }

    /// Datei, die Vorschau und Senden benutzen: das Schnitt-Ergebnis, sonst das Original.
    static func sendeQuelle(original: URL, geschnitten: URL?) -> URL { geschnitten ?? original }

    /// Nur `SnapFilter` (Sendable) und ein gewickeltes `CGImage` queren die `Task.detached`-Grenze —
    /// `CIImage`/`CIFilter` werden bewusst erst innerhalb von `SnapFilter.gefiltertesCGBild` gebaut
    /// (R9-Review: kein von außen hineingereichtes `CIImage`, kein unmarkiertes `CIContext`).
    private static func gefiltertesVorschauBild(quelle: UIImage, filter: SnapFilter, staerke: Double) async -> UIImage? {
        guard filter != .original, let cgQuelle = Self.aufrechtesCGBild(quelle) else { return nil }
        let eingabe = SendableCGImage(bild: cgQuelle)
        let ergebnis = await Task.detached(priority: .userInitiated) { () -> SendableCGImage? in
            guard let cgBild = SnapFilter.gefiltertesCGBild(aus: eingabe.bild, filter: filter, staerke: staerke) else { return nil }
            return SendableCGImage(bild: cgBild)
        }.value
        return ergebnis.map { UIImage(cgImage: $0.bild) }
    }

    /// `UIImage.imageOrientation` in die Pixel backen (gleiche Wirkung wie vorher
    /// `CIImage(image:options:[.applyOrientationProperty: true])`), synchron auf dem aufrufenden Actor —
    /// danach reicht nur noch das fertige `CGImage` über die `Task.detached`-Grenze, nie das `UIImage`.
    /// Roher `CGContext` statt dem UIKit-Bild-Renderer — CI-Regel erlaubt den nur in `Snaps`-Dateien
    /// mit "Export" im Namen.
    private static func aufrechtesCGBild(_ bild: UIImage) -> CGImage? {
        guard bild.imageOrientation != .up else { return bild.cgImage }
        let skala = bild.scale
        let breite = Int((bild.size.width * skala).rounded(.up))
        let hoehe = Int((bild.size.height * skala).rounded(.up))
        guard breite > 0, hoehe > 0,
              let context = CGContext(data: nil, width: breite, height: hoehe, bitsPerComponent: 8, bytesPerRow: 0,
                                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Core Graphics: Ursprung unten links, Y hoch. `UIImage.draw` erwartet Y runter wie jedes
        // UIKit-Layout, und `skala` rechnet Punkte in Pixel um — ohne beides läge das Ergebnis
        // gespiegelt/falsch skaliert.
        context.translateBy(x: 0, y: CGFloat(hoehe))
        context.scaleBy(x: skala, y: -skala)
        UIGraphicsPushContext(context)
        bild.draw(at: .zero)
        UIGraphicsPopContext()
        return context.makeImage()
    }

    /// Einmal pro Snap: eine kleine (~160px) Thumbnail-CIImage, für alle 15 Filter gerendert und
    /// gecached — nicht pro Chip/Frame neu (Akku-Regel). Lebt off-main in `Task.detached`.
    private func thumbnailsErzeugen() async {
        let quellBild: UIImage?
        switch inhalt {
        case .foto(let bild): quellBild = bild
        case .video(let url): quellBild = await Self.erstesVideoBild(url: url)
        }
        guard filterAn, let quellBild else { return }
        filterThumbnails = await Self.filterThumbnails(aus: quellBild)
    }

    private static func erstesVideoBild(url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        guard let ergebnis = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: ergebnis.image)
    }

    /// Wie `gefiltertesVorschauBild`: nur `SendableCGImage`/`SnapFilter`/`CGSize` queren die
    /// `Task.detached`-Grenze, `CIImage` wird innerhalb des Closures aus dem `CGImage` neu gebaut.
    private static func filterThumbnails(aus quellBild: UIImage) async -> [SnapFilter: UIImage] {
        guard let cgQuelle = Self.aufrechtesCGBild(quellBild), cgQuelle.width > 0, cgQuelle.height > 0 else { return [:] }
        let klein = MedienKodierung.skaliert(CGSize(width: cgQuelle.width, height: cgQuelle.height), langeKante: 160)
        guard klein.width > 0, klein.height > 0 else { return [:] }
        let eingabe = SendableCGImage(bild: cgQuelle)

        let ergebnis: [SnapFilter: SendableCGImage] = await Task.detached(priority: .utility) {
            let ciBasis = CIImage(cgImage: eingabe.bild)
            guard ciBasis.extent.width > 0, ciBasis.extent.height > 0 else { return [:] }
            let skaliert = ciBasis.transformed(by: CGAffineTransform(scaleX: klein.width / ciBasis.extent.width, y: klein.height / ciBasis.extent.height))
            var ergebnis: [SnapFilter: SendableCGImage] = [:]
            for filter in SnapFilter.allCases {
                let gefiltert = filter.anwenden(auf: skaliert)
                guard let cgBild = SnapFilterKontext.shared.context.createCGImage(gefiltert, from: CGRect(origin: .zero, size: klein)) else { continue }
                ergebnis[filter] = SendableCGImage(bild: cgBild)
            }
            return ergebnis
        }.value

        return ergebnis.mapValues { UIImage(cgImage: $0.bild) }
    }

    // MARK: - Send (Z-6.2: flatten, then reuse Block 5's upload helpers)

    /// Dismisses as soon as the flatten step is done and the op is queued — NOT after the network
    /// upload finishes, which `ChatMedien.snapFotoSenden`/`snapVideoSenden` would otherwise make
    /// this whole function (and the spinner) wait on for a possibly large file.
    private func senden() {
        guard !sendetGerade else { return }
        sendetGerade = true
        sendeFehler = nil
        videoSpieler?.pause()
        spielt = false
        Haptik.leicht()
        let filter = wirksamerFilter
        let staerke = wirksameStaerke
        if let onUebernehmen {
            // ponytail: tray mode edits photos only (videos in the tray aren't editable yet).
            guard case .foto(let bild) = inhalt else { onFertig(); return }
            Task {
                if let jpeg = await SnapExport.foto(quelle: bild, linien: linien, sticker: sticker, text: text, filter: filter, filterStaerke: staerke) { onUebernehmen(jpeg) }
                onFertig()
            }
            return
        }
        switch inhalt {
        case .foto(let bild):
            Task {
                let jpeg = await SnapExport.foto(quelle: bild, linien: linien, sticker: sticker, text: text, filter: filter, filterStaerke: staerke)
                onFertig()
                if let jpeg { await ChatMedien.snapFotoSenden(jpeg: jpeg, bleibt: bleibt, antwortAuf: antwortAuf) }
            }
        case .video(let url):
            let schnitt = plan
            Task {
                var quelle = url
                if let schnitt, schnitt.veraendert {
                    guard let geschnitten = await SnapSchnittExport.exportieren(quelle: url, plan: schnitt) else {
                        sendeFehler = "Schneiden hat nicht geklappt. Bitte noch einmal versuchen."
                        sendetGerade = false
                        return
                    }
                    quelle = geschnitten
                }
                defer { onFertig() }
                guard let exportURL = await SnapExport.video(quelle: quelle, linien: linien, sticker: sticker, text: text, filter: filter, filterStaerke: staerke) else { return }
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
        if let name = MitgelieferteSticker.assetName(id) { return UIImage(named: name) }
        // Split, not `A ?? B ?? (try? await C)`: an `await` buried in a `??` chain doesn't
        // type-check ("'async' call in a function that does not support concurrency") — same fix
        // already applied project-wide in `StickerKachel`/`GifStickerBlatt`.
        var url = ChatMedien.eigeneQuellen[id] ?? Medien.lokal(id)
        if url == nil { url = try? await Medien.holen(id) }
        guard let url else { return nil }
        return await Bilddatei.laden(url, maxPixel: 1024)
    }
}
