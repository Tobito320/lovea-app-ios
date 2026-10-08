import SwiftUI

/// Die Blätter, die ein Ding im Zimmer öffnet.
enum AlltagBlatt: String, Identifiable {
    case platte, wecker, spiegel, kuehlschrank
    var id: String { rawValue }
}

/// p64: die antippbaren Dinge des Paar-Alltags im gemeinsamen Zimmer: Plattenspieler, Nachttisch mit
/// Wecker, Spiegel, Kühlschrank und (nur an schweren Tagen) Tee, Wärmflasche und etwas Süßes.
/// Liegt als Overlay über `ZuhauseBuehne` und rechnet wie `PaarSignaleEbene` (Entwurfsraum 390 x 430,
/// unten verankert). Beim Öffnen wird nichts geladen und kein Takt gestartet: Cover und Fotos laden erst
/// in den Blättern, nur die Platte dreht sich einmal 30 Sekunden, wenn ein Song aufliegt.
struct AlltagEbene: View {
    private let speicher: AlltagSpeicher
    /// Nur für die Render-Tafel: fester Tag statt heute und kein Abgleich der Wärme mit dem Zyklus.
    private let heute: String
    private let pruefen: Bool
    /// p65: `.panorama` setzt jedes Ding an seinen Platz in der breiten Welt (`ProfilSlots`).
    private let welt: ProfilWelt

    @State private var blatt: AlltagBlatt?
    @State private var dreht = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("lovea.gruss.morgenTag") private var morgenTag = ""

    init(speicher: AlltagSpeicher = .shared, heute: String = Datum.text(Date()), pruefen: Bool = true, welt: ProfilWelt = .einzel) {
        self.speicher = speicher
        self.heute = heute
        self.pruefen = pruefen
        self.welt = welt
    }

    private static let platteOrt = ProfilSlots.platteMitte // auf dem Wandregal links über dem Bett
    private static let spiegelOrt = ProfilSlots.spiegelMitte // an der Wand rechts über dem Sofa
    private static let nachttischOrt = ProfilSlots.nachttischMitte
    private static let kuehlOrt = ProfilSlots.kuehlMitte
    private static let waermeOrt = ProfilSlots.waermeMitte // auf dem Teppich neben dem Tisch

    private func versetzt(_ mitte: CGPoint, _ d: ProfilDing) -> CGPoint {
        let v = welt.versatz(d)
        return CGPoint(x: mitte.x + v.width, y: mitte.y + v.height)
    }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / welt.breite
            let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
            ZStack(alignment: .topLeading) {
                if waermeDa { waermeSet(s, oben) }
                plattenspieler(s, oben)
                spiegel(s, oben)
                nachttisch(s, oben)
                kuehlschrank(s, oben)
            }
        }
        .task { if pruefen { speicher.waermePruefen(heute: heute) } }
        .task(id: speicher.stand.platte?.opId) { await plattenDrehen() }
        .sheet(item: $blatt) { b in
            switch b {
            case .platte: PlatteBlatt()
            case .wecker: WeckerBlatt()
            case .spiegel: SpiegelBlatt()
            case .kuehlschrank: KuehlschrankBlatt()
            }
        }
    }

    private var waermeDa: Bool {
        Person.allCases.contains { AlltagLogik.waermeAktiv(speicher.stand, von: $0, heute: heute) }
    }

    // MARK: Teile

    /// Ein antippbares Ding an einer Stelle des Entwurfsraums. Das Polster macht die Tippfläche groß genug.
    private func ding<V: View>(_ mitte: CGPoint, _ s: CGFloat, _ oben: CGFloat, name: String, tippen: @escaping () -> Void,
                               @ViewBuilder _ inhalt: () -> V) -> some View {
        Button(action: tippen) { inhalt().padding(8).contentShape(.rect) }
            .buttonStyle(.plain)
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

    private func plattenspieler(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let platte = speicher.stand.platte
        let name = platte.map { "Plattenspieler: \($0.titel)" } ?? "Plattenspieler, noch keine Platte"
        return ding(versetzt(Self.platteOrt, .platte), s, oben, name: name, tippen: { blatt = .platte }) {
            TimelineView(.animation(minimumInterval: 0.1, paused: !dreht)) { zeit in
                bild(AlltagZeichnung.platteRaster, breite: 78, s) {
                    AlltagZeichnung.plattenspieler($0, winkel: dreht ? zeit.date.timeIntervalSinceReferenceDate * 2 : 0, bespielt: platte != nil)
                }
            }
            .overlay(alignment: .top) {
                if let titel = platte?.titel { pille(titel, s, hoechstens: 78).offset(y: -15 * s) }
            }
        }
    }

    private func spiegel(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let partner = speicher.ich?.partner
        let haengt = partner.flatMap { AlltagLogik.outfit(speicher.stand, von: $0, heute: heute) } != nil
        let name = haengt ? "Spiegel, \(partner?.name ?? "") hat ein Outfit aufgehängt" : "Spiegel mit Outfit des Tages"
        return ding(versetzt(Self.spiegelOrt, .spiegel), s, oben, name: name, tippen: { blatt = .spiegel }) {
            bild(AlltagZeichnung.spiegelRaster, breite: 46, s) { AlltagZeichnung.spiegel($0, haengt: haengt) }
        }
    }

    private func nachttisch(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let partner = speicher.ich?.partner
        let zeit = AlltagLogik.weckzeit(partner.flatMap { speicher.stand.wecker[$0] })
        let morgen = GrussFenster.knopf(stunde: Calendar.berlin.component(.hour, from: Date()), jetzt: Date(), letzteNacht: nil,
                                        morgenGesendetHeute: morgenTag == heute) == "morgen"
        let name = zeit.map { "Wecker von \(partner?.name ?? ""): \($0)" } ?? "Wecker"
        return ding(versetzt(Self.nachttischOrt, .nachttisch), s, oben, name: name, tippen: { blatt = .wecker }) {
            bild(AlltagZeichnung.nachttischRaster, breite: 40, s) { AlltagZeichnung.nachttisch($0, gestellt: zeit != nil) }
                .overlay(alignment: .top) {
                    if let zeit { pille(zeit, s, hoechstens: 40).offset(y: -14 * s) }
                }
                .overlay(alignment: .topTrailing) {
                    if morgen { Circle().fill(Color.loveaRose).frame(width: 9 * s, height: 9 * s).offset(x: 2 * s, y: -2 * s) }
                }
        }
    }

    private func kuehlschrank(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let alle = AlltagLogik.zettelListe(speicher.stand)
        let offen = AlltagLogik.offene(speicher.stand)
        let name = offen > 0 ? "Kühlschrank, \(offen) offen" : "Kühlschrank mit Zetteln"
        return ding(versetzt(Self.kuehlOrt, .kuehl), s, oben, name: name, tippen: { blatt = .kuehlschrank }) {
            bild(AlltagZeichnung.kuehlRaster, breite: 36, s) { AlltagZeichnung.kuehlschrank($0, zettel: alle.count) }
                .overlay(alignment: .topTrailing) {
                    if offen > 0 {
                        Text("\(offen)")
                            .font(.system(size: 9 * s, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 13 * s, minHeight: 13 * s)
                            .background(Color.loveaRose, in: Capsule())
                            .offset(x: 4 * s, y: -3 * s)
                    }
                }
        }
    }

    /// Tee, Wärmflasche und Keks: nur zum Ansehen, kein Tippen.
    private func waermeSet(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let m = versetzt(Self.waermeOrt, .waerme)
        return bild(AlltagZeichnung.waermeRaster, breite: 40, s, AlltagZeichnung.waermeSet)
            .position(x: m.x * s, y: oben + m.y * s)
            .allowsHitTesting(false)
    }

    // MARK: Aktionen

    /// Die Platte dreht sich, solange ein Song aufliegt, einmal 30 Sekunden lang und nur mit Bewegung und
    /// ohne Stromsparmodus. Ein einziger Auftrag je Song; verschwindet die Ansicht, endet er mit ihr.
    private func plattenDrehen() async {
        guard speicher.stand.platte != nil, !reduceMotion, !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        dreht = true
        try? await Task.sleep(for: .seconds(AlltagLogik.drehDauer))
        dreht = false
    }
}
