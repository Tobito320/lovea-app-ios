import SwiftUI

/// p60: die antippbaren Paar-Signale im gemeinsamen Zimmer. Liegt als Overlay über `ZuhauseBuehne`
/// und rechnet wie sie (Entwurfsraum 390 x 430, unten verankert). Nichts läuft von allein: jede
/// Änderung kommt aus einem Tipp oder einer Op, die Lampe leuchtet einmal kurz und ist wieder aus.
struct PaarSignaleEbene: View {
    private let speicher: SignaleSpeicher
    private let briefe: BriefeSpeicher
    private let figuren = FigurenModell.shared
    private let wir = WirModell.shared
    /// Nur für die Render-Tafel: feste Grüße und feste Uhrzeit statt Live-Stand und Jetzt.
    private let gruesse: NachtLogik.Gruesse?
    private let jetzt: Date?
    /// p65: `.panorama` setzt jedes Ding an seinen Platz in der breiten Welt (Tippfläche mindestens 44 pt).
    private let welt: ProfilWelt

    @Binding private var blatt: SignaleBlatt?
    @State private var leuchtet: Bool
    @State private var lampeZuletzt: Date?

    init(blatt: Binding<SignaleBlatt?>, speicher: SignaleSpeicher = .shared, briefe: BriefeSpeicher = .shared,
         gruesse: NachtLogik.Gruesse? = nil, jetzt: Date? = nil, leuchtet: Bool = false, welt: ProfilWelt = .einzel) {
        _blatt = blatt
        self.speicher = speicher
        self.briefe = briefe
        self.gruesse = gruesse
        self.jetzt = jetzt
        self.welt = welt
        _leuchtet = State(initialValue: leuchtet)
    }

    private static let lampe = ZuhauseZeichnung.lampe
    private static let umschlagOrt = P(198, 313)
    private static let stapelOrt = P(248, 314)
    private static let zettelOrt = P(332, 150)
    private static let schalterOrt = P(150, 176)
    private static let boxOrt = P(118, 338) // unter dem Bett, rechts neben dem Profilbild im Kopf

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / welt.breite
            let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
            ZStack(alignment: .topLeading) {
                if leuchtet { LampenGlanz(welt: welt).transition(.opacity) }
                lampenTaste(s, oben)
                zettel(s, oben)
                if briefe.ungeoeffnet > 0, let neu = briefe.erhalten.first { umschlag(neu, s, oben) }
                stapel(s, oben)
                geschenkBox(s, oben)
                if let ich = speicher.ich, NachtLogik.schalterSichtbar(gruesse ?? figuren.gruss, jetzt: jetzt ?? Date()) { schalter(ich, s, oben) }
            }
        }
        .onChange(of: figuren.lampeEreignis) { _, _ in leuchten() }
        .sheet(item: $blatt) { b in
            switch b {
            case .stimmung: StimmungWahlBlatt()
            case .brief(let brief): BriefLesenBlatt(brief: brief)
            case .liebesbrief: LiebesbriefBlatt()
            case .zettel: ZettelBlatt()
            case .geschenke: GeschenkBoxBlatt()
            }
        }
    }

    // MARK: Teile

    /// Ein antippbares Ding an einer Stelle des Entwurfsraums. Das Polster macht die Tippfläche groß genug.
    private func ding<V: View>(_ mitte: CGPoint, _ s: CGFloat, _ oben: CGFloat, name: String, tippen: @escaping () -> Void,
                               @ViewBuilder _ inhalt: () -> V) -> some View {
        let mindest: CGFloat = welt == .panorama ? ProfilSlots.tippMinimum : 0
        return Button(action: tippen) { inhalt().padding(8).frame(minWidth: mindest, minHeight: mindest).contentShape(.rect) }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
            .position(x: mitte.x * s, y: oben + mitte.y * s)
    }

    private func bild(_ raster: CGSize, breite: CGFloat, _ s: CGFloat, _ zeichne: @escaping (GraphicsContext) -> Void) -> some View {
        SignaleBild(raster: raster, zeichne: zeichne)
            .frame(width: breite * s, height: breite * s * raster.height / raster.width)
    }

    private func lampenTaste(_ s: CGFloat, _ oben: CGFloat) -> some View {
        ding(welt.ort(P(Self.lampe.x, Self.lampe.y - 22), .lampe), s, oben, name: "Lampe. Denk an dich", tippen: lampeTippen) {
            Color.clear.frame(width: 44 * s, height: 50 * s)
        }
    }

    private func zettel(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let offen = wir.heute.map { wir.meineAntwort($0.id) == nil } ?? false
        return ding(welt.ort(Self.zettelOrt, .zettel), s, oben, name: offen ? "Frage des Tages, noch offen" : "Frage des Tages", tippen: { blatt = .zettel }) {
            bild(SignaleZeichnung.zettelRaster, breite: 30, s, SignaleZeichnung.zettel)
                .overlay(alignment: .top) {
                    Text("?")
                        .font(.system(size: 17 * s, weight: .heavy, design: .rounded))
                        .foregroundStyle(Pal.tinte.farbe.opacity(0.7))
                        .padding(.top, 6 * s)
                }
                .overlay(alignment: .topTrailing) {
                    if offen { Circle().fill(Color.loveaRose).frame(width: 9 * s, height: 9 * s).offset(x: 3 * s, y: -3 * s) }
                }
        }
    }

    private func umschlag(_ brief: Brief, _ s: CGFloat, _ oben: CGFloat) -> some View {
        ding(welt.ort(Self.umschlagOrt, .kommode), s, oben, name: "Ungeöffneter Brief von \(brief.von.name)", tippen: { blatt = .brief(brief) }) {
            bild(CGSize(width: 40, height: 40), breite: 26, s, SignaleZeichnung.umschlag)
                .overlay(alignment: .topTrailing) {
                    if briefe.ungeoeffnet > 1 {
                        Text("\(briefe.ungeoeffnet)")
                            .font(.system(size: 9 * s, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 13 * s, minHeight: 13 * s)
                            .background(Color.loveaRose, in: Capsule())
                            .offset(x: 5 * s, y: -3 * s)
                    }
                }
        }
    }

    private func stapel(_ s: CGFloat, _ oben: CGFloat) -> some View {
        ding(welt.ort(Self.stapelOrt, .kommode), s, oben, name: "Briefstapel", tippen: { blatt = .liebesbrief }) {
            bild(CGSize(width: 40, height: 40), breite: 26, s, SignaleZeichnung.stapel)
        }
    }

    private func geschenkBox(_ s: CGFloat, _ oben: CGFloat) -> some View {
        ding(welt.ort(Self.boxOrt, .geschenkbox), s, oben, name: "Geschenkbox unter dem Bett", tippen: { blatt = .geschenke }) {
            bild(SignaleZeichnung.geschenkRaster, breite: 36, s, SignaleZeichnung.geschenkBox)
        }
    }

    private func schalter(_ ich: Person, _ s: CGFloat, _ oben: CGFloat) -> some View {
        let gesagt = NachtLogik.gedrueckt(ich, gruesse ?? figuren.gruss, jetzt: jetzt ?? Date())
        return ding(welt.ort(Self.schalterOrt, .schalter), s, oben, name: gesagt ? "Gute Nacht gesagt" : "Gute Nacht sagen", tippen: { nachtSagen(gesagt) }) {
            bild(SignaleZeichnung.schalterRaster, breite: 18, s) { SignaleZeichnung.schalter($0, an: gesagt) }
        }
    }

    // MARK: Aktionen

    private func lampeTippen() {
        let jetzt = Date()
        guard SignaleLogik.lampeFrei(zuletzt: lampeZuletzt, jetzt: jetzt) else { return }
        lampeZuletzt = jetzt
        Haptik.leicht()
        leuchten()
        figuren.gesteSenden("herz", quelle: "lampe")
    }

    /// Die Lampe leuchtet kurz auf und geht von selbst wieder aus, ein einziger Auftrag je Tipp.
    private func leuchten() {
        withAnimation(Feder.weich) { leuchtet = true }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(Feder.weich) { leuchtet = false }
        }
    }

    private func nachtSagen(_ schonGesagt: Bool) {
        guard !schonGesagt else { return }
        Haptik.mittel()
        figuren.grussSenden("nacht")
    }
}

/// Der warme Schein der Lampe, solange sie leuchtet.
private struct LampenGlanz: View {
    var welt: ProfilWelt = .einzel

    var body: some View {
        let welt = welt
        Canvas { g, groesse in
            let k = SzenenZeichnung.raum(g, groesse, welt: welt)
            let mitte = welt.ort(ZuhauseZeichnung.lampe, .lampe)
            let stufen = Gradient(colors: [FigurFarbe(0xFFE9A8).farbe.opacity(0.9), FigurFarbe(0xFFC96B).farbe.opacity(0.35), .clear])
            k.fill(kreis(mitte, 140), with: .radialGradient(stufen, center: mitte, startRadius: 4, endRadius: 140))
            k.fill(oval(P(mitte.x, mitte.y - 4), 10, 5.5), with: .color(.white))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Die Stimmungsblase über einer Figur: bei der anderen Person nur, wenn sie eine gesetzt hat; bei
/// mir immer, leer mit Plus lädt sie zum Setzen ein (`setzen` öffnet die Wahl). `figurHoehe` ist die Höhe der Figur auf dem Bildschirm.
struct StimmungBlase: View {
    let person: Person
    let figurHoehe: CGFloat
    let ganzkoerper: Bool
    var speicher = SignaleSpeicher.shared
    let setzen: () -> Void

    var body: some View {
        let art = speicher.stimmung(von: person)
        let meine = person == speicher.ich
        if art != nil || meine {
            let hoehe = max(34, figurHoehe * 0.26)
            let blase = SignaleBild(raster: SignaleZeichnung.blasenRaster) { SignaleZeichnung.blase($0, art) }
                .frame(width: hoehe * SignaleZeichnung.blasenRaster.width / SignaleZeichnung.blasenRaster.height, height: hoehe)
            Group {
                if meine {
                    Button(action: setzen) { blase.contentShape(Rectangle().inset(by: -6)) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(art.map { "Deine Stimmung: \($0.name)" } ?? "Stimmung setzen")
                } else {
                    blase
                        .allowsHitTesting(false)
                        .accessibilityLabel("\(person.name): \(art?.name ?? "")")
                }
            }
            .offset(y: figurHoehe * (ganzkoerper ? 0.06 : 0.04) - hoehe)
        }
    }
}
