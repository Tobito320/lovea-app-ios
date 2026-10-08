import SwiftUI

/// Die Blätter, die ein Zimmer-Objekt öffnet (ein einziges `.sheet(item:)`).
private enum ZimmerObjektBlatt: String, Identifiable {
    case briefe, sprache, shop, medien
    var id: String { rawValue }
}

/// Wie `Haptik.an`, aber ohne Akteur-Bindung: die Rückmeldung von `.sensoryFeedback` läuft nicht im MainActor.
private func zimmerHaptikAn() -> Bool { UserDefaults.standard.object(forKey: "lovea.haptik") as? Bool ?? true }

/// "Unser Zimmer": die sechs antippbaren Objekte der Paar-Welt (Briefkasten, Anrufbeantworter, Herzglas,
/// Sparschwein, Abreißkalender, Bilderrahmen). Liegt als Overlay über `ZuhauseBuehne`, rechnet wie
/// `AlltagEbene` (Entwurfsraum 975 x 430, unten verankert) und besitzt die Blätter, die die Objekte öffnen.
/// Gezeichnet wird nur im Panorama und nur im eigenen Zimmer. Nichts läuft im Takt außer der Lampe (nur bei
/// ungehörter Sprachpost), dem Konfetti am Meilenstein-Tag und dem Bilderwechsel alle 6 Sekunden; mit
/// "Bewegung reduzieren" steht alles still.
struct ZimmerObjekteEbene: View {
    private let welt: ProfilWelt
    private let eigen: Bool

    init(welt: ProfilWelt = .panorama, eigen: Bool = true) {
        self.welt = welt
        self.eigen = eigen
    }

    private let briefe = BriefeSpeicher.shared
    private let post = SprachpostSpeicher.shared

    @State private var blatt: ZimmerObjektBlatt?
    /// Zählt jede Berührung: löst die Haptik aus.
    @State private var tipp = 0
    /// 0...1: der Brief gleitet aus dem Schlitz, bevor das Blatt aufgeht.
    @State private var briefRaus = 0.0
    /// 0...1: ein gesendeter Brief fliegt aus dem Briefkasten.
    @State private var flug = 0.0
    /// 0...1: das Herz fällt ins Glas.
    @State private var fallen = 0.0
    /// 0...1: die oberste Kalenderseite wird abgerissen.
    @State private var riss = 0.0
    @State private var konfettiStart: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Mitten der Objekte in der Welt (Entwurfseinheiten, y von oben in den 430).
    private static let briefkastenOrt = CGPoint(x: 34, y: 388)
    private static let kalenderOrt = CGPoint(x: 911, y: 46)
    private static let rahmenOrt = CGPoint(x: 710, y: 198)
    private static let anrufOrt = CGPoint(x: 806, y: 256)
    private static let glasOrt = CGPoint(x: 918, y: 244)
    private static let schweinOrt = CGPoint(x: 803, y: 396)

    private var ich: Person? { Raum.shared.ich }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        Group {
            if welt == .panorama && eigen { szene }
        }
    }

    private var szene: some View {
        GeometryReader { geo in
            let s = geo.size.width / welt.breite
            let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
            ZStack(alignment: .topLeading) {
                briefkasten(s, oben)
                kalender(s, oben)
                rahmen(s, oben)
                anrufbeantworter(s, oben)
                herzglas(s, oben)
                sparschwein(s, oben)
            }
        }
        .sheet(item: $blatt) { b in
            switch b {
            case .briefe: fertigBlatt(BriefeView())
            case .sprache: fertigBlatt(SprachpostView())
            case .shop: ShopView(ziel: ich)
            case .medien:
                if let ich { MedienUebersicht(ich: ich) }
            }
        }
        .sensoryFeedback(trigger: tipp) { _, _ -> SensoryFeedback? in zimmerHaptikAn() ? .impact(weight: .light) : nil }
        .onChange(of: briefe.geschrieben.count) { alt, neu in if neu > alt { briefFliegt() } }
        .task(id: konfettiStart) {
            guard konfettiStart != nil else { return }
            try? await Task.sleep(for: .seconds(2.6))
            if !Task.isCancelled { konfettiStart = nil }
        }
        .task {
            if ZimmerObjekteLogik.istMeilensteinTag(heute: heute), !reduceMotion { konfettiStart = Date() }
        }
    }

    private func fertigBlatt<V: View>(_ inhalt: V) -> some View {
        NavigationStack {
            inhalt
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { blatt = nil } } }
        }
    }

    // MARK: Teile

    /// Ein antippbares Objekt an einer Stelle der Welt. Das Polster macht die Tippfläche mindestens 44 x 44 pt.
    private func ding<V: View>(_ mitte: CGPoint, _ s: CGFloat, _ oben: CGFloat, name: String,
                               lang: (() -> Void)? = nil, tippen: @escaping () -> Void,
                               @ViewBuilder _ inhalt: () -> V) -> some View {
        Button(action: tippen) {
            inhalt().padding(8).frame(minWidth: ProfilSlots.tippMinimum, minHeight: ProfilSlots.tippMinimum).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in lang?() })
        .accessibilityLabel(name)
        .position(x: mitte.x * s, y: oben + mitte.y * s)
    }

    private func bild(_ raster: CGSize, breite: CGFloat, _ s: CGFloat, _ zeichne: @escaping (GraphicsContext) -> Void) -> some View {
        SignaleBild(raster: raster, zeichne: zeichne)
            .frame(width: breite * s, height: breite * s * raster.height / raster.width)
    }

    private func pille(_ text: String, _ s: CGFloat, hoechstens: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 9 * s, weight: .bold, design: .rounded))
            .foregroundStyle(Pal.tinte.farbe)
            .lineLimit(1)
            .padding(.horizontal, 5 * s)
            .padding(.vertical, 2 * s)
            .frame(maxWidth: hoechstens * s)
            .background(Color.white.opacity(0.92), in: Capsule())
    }

    // MARK: 4 Briefkasten

    private func briefkasten(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let neu = briefe.ungeoeffnet
        let stapel = ZimmerObjekteLogik.briefStapel(ungeoeffnet: neu)
        let fahne = ZimmerObjekteLogik.fahneOben(ungeoeffnet: neu)
        let r = ZimmerObjekteZeichnung.briefkastenRaster
        return ding(Self.briefkastenOrt, s, oben, name: PostLogik.beschriftung("Briefkasten", neu: neu), tippen: briefkastenTippen) {
            bild(r, breite: 48, s) { ZimmerObjekteZeichnung.briefkasten($0, stapel: stapel, fahne: fahne) }
                .overlay(alignment: .topLeading) {
                    // Der Brief, der beim Antippen aus dem Schlitz gleitet.
                    bild(ZimmerObjekteZeichnung.umschlagRaster, breite: 20, s, { ZimmerObjekteZeichnung.umschlag($0) })
                        .offset(x: 14 * s, y: (17 + briefRaus * 40) * s)
                        .opacity(briefRaus > 0 ? 1 : 0)
                }
                .overlay(alignment: .topLeading) {
                    // Ein gesendeter Brief fliegt oben rechts heraus.
                    bild(ZimmerObjekteZeichnung.umschlagRaster, breite: 20, s, { ZimmerObjekteZeichnung.umschlag($0, winkel: -12) })
                        .offset(x: (24 + flug * 34) * s, y: (4 - flug * 46) * s)
                        .opacity(flug > 0 ? 1 - flug : 0)
                }
        }
    }

    private func briefkastenTippen() {
        tipp += 1
        guard briefRaus == 0 else { return }
        guard !reduceMotion else { blatt = .briefe; return }
        withAnimation(Feder.weich) { briefRaus = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            blatt = .briefe
            briefRaus = 0
        }
    }

    private func briefFliegt() {
        guard !reduceMotion else { return }
        flug = 0
        withAnimation(.easeOut(duration: 0.9)) { flug = 1 } completion: { flug = 0 }
    }

    // MARK: 5 Anrufbeantworter

    private func anrufbeantworter(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let neu = post.ungehoert
        let ziffern = ZimmerObjekteLogik.ziffern(ungehoert: neu)
        let name = neu > 0 ? "Anrufbeantworter, \(neu) neue Sprachnachricht\(neu == 1 ? "" : "en")" : "Anrufbeantworter, keine neue Sprachnachricht"
        let offen: () -> Void = { tipp += 1; blatt = .sprache }
        return ding(Self.anrufOrt, s, oben, name: name, lang: offen, tippen: offen) {
            // Die Lampe blinkt im Takt, solange etwas ungehört ist; mit ruhiger Bewegung leuchtet sie nur.
            TimelineView(.animation(minimumInterval: 0.6, paused: neu == 0 || reduceMotion)) { zeit in
                let an = reduceMotion || Int(zeit.date.timeIntervalSinceReferenceDate / 0.6) % 2 == 0
                bild(ZimmerObjekteZeichnung.anrufRaster, breite: 64, s) {
                    ZimmerObjekteZeichnung.anrufbeantworter($0, ziffern: ziffern, lampe: an, hatNachricht: neu > 0)
                }
            }
        }
    }

    // MARK: 8 Herzglas

    private func herzglas(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let erhalten = ZimmerObjekteLogik.herzenErhalten(heute: FigurenModell.shared.herzHeute, ich: ich)
        let herzen = ZimmerObjekteLogik.glasHerzen(erhalten: erhalten)
        let von = ich?.partner.name ?? "dem Partner"
        let name = "Herzglas, \(erhalten) Herzen heute von \(von). Antippen schickt ein Herz"
        return ding(Self.glasOrt, s, oben, name: name, tippen: herzSenden) {
            bild(ZimmerObjekteZeichnung.glasRaster, breite: 52, s) { ZimmerObjekteZeichnung.herzglas($0, herzen: herzen) }
                .overlay(alignment: .topLeading) {
                    bild(ZimmerObjekteZeichnung.herzRaster, breite: 12, s, ZimmerObjekteZeichnung.herz)
                        .offset(x: 20 * s, y: (-16 + fallen * 40) * s)
                        .opacity(fallen > 0 ? 1 - max(0, fallen - 0.85) / 0.15 : 0)
                }
                .overlay(alignment: .top) {
                    if erhalten > 0 { pille("\(erhalten)", s, hoechstens: 30).offset(y: -14 * s) }
                }
        }
    }

    private func herzSenden() {
        tipp += 1
        FigurenModell.shared.gesteSenden("herz")
        guard !reduceMotion else { return }
        fallen = 0
        withAnimation(.easeIn(duration: 0.7)) { fallen = 1 } completion: { fallen = 0 }
    }

    // MARK: 12 Sparschwein

    private func sparschwein(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let punkte = ich.map { PunkteModell.shared.verfuegbar($0) } ?? 0
        let stufe = ZimmerObjekteLogik.schweinStufe(punkte: punkte)
        return ding(Self.schweinOrt, s, oben, name: "Sparschwein, \(punkte) Punkte. Öffnet den Shop", tippen: { tipp += 1; blatt = .shop }) {
            bild(ZimmerObjekteZeichnung.schweinRaster, breite: 56, s) { ZimmerObjekteZeichnung.sparschwein($0, stufe: stufe) }
                .overlay(alignment: .top) { pille("\(punkte)", s, hoechstens: 56).offset(y: -14 * s) }
        }
    }

    // MARK: 13 Abreißkalender

    private func kalender(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let tage = ZimmerObjekteLogik.tageBis(heute: heute)
        let fest = ZimmerObjekteLogik.meilensteinHeute(heute: heute)
        let name = fest.map { "Abreißkalender, heute ist \($0)" } ?? "Abreißkalender, noch \(tage) \(tage == 1 ? "Tag" : "Tage") bis zum nächsten Meilenstein"
        return ding(Self.kalenderOrt, s, oben, name: name, tippen: { seiteReissen(fest: fest != nil) }) {
            bild(ZimmerObjekteZeichnung.kalenderRaster, breite: 42, s) {
                ZimmerObjekteZeichnung.kalenderRumpf($0)
                ZimmerObjekteZeichnung.kalenderSeite($0, tage: tage, fest: fest != nil)
            }
            .overlay(alignment: .topLeading) {
                // Die abgerissene Seite kippt weg und fällt.
                bild(ZimmerObjekteZeichnung.kalenderRaster, breite: 42, s, { ZimmerObjekteZeichnung.kalenderSeite($0, tage: tage + 1, fest: false) })
                    .rotationEffect(.degrees(riss * 38), anchor: .topLeading)
                    .offset(x: riss * 8 * s, y: riss * 64 * s)
                    .opacity(riss > 0 ? 1 - riss : 0)
            }
            .overlay(alignment: .topLeading) {
                if let start = konfettiStart {
                    TimelineView(.animation) { zeit in
                        let phase = min(max(zeit.date.timeIntervalSince(start) / 2.5, 0), 1)
                        bild(ZimmerObjekteZeichnung.kalenderRaster, breite: 42, s, { ZimmerObjekteZeichnung.konfetti($0, phase: phase) })
                    }
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) {
                if let fest { pille(fest, s, hoechstens: 90).offset(y: -14 * s) }
            }
        }
    }

    private func seiteReissen(fest: Bool) {
        tipp += 1
        if fest && !reduceMotion { konfettiStart = Date() }
        guard !reduceMotion else { return }
        riss = 0
        withAnimation(.easeIn(duration: 0.8)) { riss = 1 } completion: { riss = 0 }
    }

    // MARK: 14 Bilderrahmen

    private func rahmen(_ s: CGFloat, _ oben: CGFloat) -> some View {
        ding(Self.rahmenOrt, s, oben, name: "Bilderrahmen mit euren Fotos. Öffnet die Medien", tippen: { tipp += 1; blatt = .medien }) {
            ZimmerRahmen(s: s)
        }
    }
}

/// Der Bilderrahmen für sich: Erinnerungen und Chat-Fotos wechseln alle 6 Sekunden mit Überblendung. Eigene
/// Ansicht, damit das Sortieren der Fotos nicht bei jedem Bild der anderen Animationen läuft.
private struct ZimmerRahmen: View {
    let s: CGFloat
    @State private var nr = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let fotos = ZimmerObjekteLogik.rahmenFotos(nachrichten: ChatModell.shared.nachrichten, ich: Raum.shared.ich)
        let raster = ZimmerObjekteZeichnung.rahmenRaster
        let r = ZimmerObjekteZeichnung.rahmenBild
        ZStack(alignment: .topLeading) {
            SignaleBild(raster: raster) { g in
                ZimmerObjekteZeichnung.bilderrahmen(g)
                if fotos.isEmpty { ZimmerObjekteZeichnung.bildPlatzhalter(g) }
            }
            if !fotos.isEmpty {
                let foto = fotos[nr % fotos.count]
                MedienKachel(medium: foto.medium, eigene: foto.eigene)
                    .frame(width: r.width * s, height: r.height * s)
                    .clipShape(RoundedRectangle(cornerRadius: 2 * s))
                    .offset(x: r.minX * s, y: r.minY * s)
                    .id(foto.id)
                    .transition(.opacity)
            }
        }
        .frame(width: raster.width * s, height: raster.height * s, alignment: .topLeading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: nr)
        .task(id: fotos.count) {
            guard fotos.count > 1, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                if Task.isCancelled { return }
                nr = (nr + 1) % fotos.count
            }
        }
    }
}
