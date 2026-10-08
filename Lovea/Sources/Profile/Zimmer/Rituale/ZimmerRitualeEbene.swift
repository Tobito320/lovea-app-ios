import SwiftUI

/// Unser Zimmer, Worker D: Paar-Rituale als Overlay über `ZuhauseBuehne` (Welt 975 x 430, unten verankert).
/// Vorhang (Guten-Morgen-Sonne), Nachtlicht, Kussglas, Glückskeks, Tee für zwei, Wunschglas. Die Umarmung
/// (beide haben das Profil offen) steckt in `ZimmerUmarmung` und den Figuren. Kein Takt: alles ist Tippen,
/// Sync-Werte (`zimmer.*`) oder ein einmaliges `.task`-Warten.
struct ZimmerRitualeEbene: View {
    private let welt: ProfilWelt
    private let eigen: Bool

    // Orte in Entwurfseinheiten (für F: ZimmerPlatzLogik)
    static let vorhangRect = ProfilSlots.welt(.fenster)
    static let nachtlichtRect = CGRect(x: 88, y: 160, width: 44, height: 44)
    static let kussglasRect = CGRect(x: 166, y: 362, width: 44, height: 52)
    static let teeRect = CGRect(x: 418, y: 318, width: 64, height: 44)
    static let keksRect = CGRect(x: 490, y: 332, width: 44, height: 36)
    static let wunschglasRect = CGRect(x: 580, y: 176, width: 40, height: 52)
    static let alleRects: [CGRect] = [nachtlichtRect, kussglasRect, teeRect, keksRect, wunschglasRect]

    private enum Blatt: String, Identifiable {
        case keks, wuensche
        var id: String { rawValue }
    }

    @State private var blatt: Blatt?
    @State private var hinweis: String?
    @State private var tipp = 0
    @State private var haeltEben = false
    @State private var partnerHaelt = false
    @State private var inView = true
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let modell = EinstellungenModell.shared
    private let figuren = FigurenModell.shared

    init(welt: ProfilWelt = .panorama, eigen: Bool = true) {
        self.welt = welt
        self.eigen = eigen
    }

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var stunde: Int { Calendar.berlin.component(.hour, from: Date()) }
    private var sichtbar: Bool { inView && phase == .active }

    // MARK: Abgeleiteter Stand

    private var vorhangOffen: Bool { RDaten.erster(RDaten.vorhang) != nil }
    private var teeGemacht: Bool { RDaten.erster(RDaten.tee) != nil }
    private var nachtGedrueckt: Bool { NachtLogik.gedrueckt(ich, figuren.gruss, jetzt: Date()) }
    private var dunkel: Bool { NachtLogik.gemeinsamDunkel(figuren.gruss, jetzt: Date()) }
    private var halt: Date? { RDaten.datum(RDaten.halt, von: ich.partner) }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / welt.breite
            let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
            ZStack(alignment: .topLeading) {
                if dunkel { nachtDunkel }
                vorhang(s, oben)
                if NachtLogik.schalterSichtbar(figuren.gruss, jetzt: Date()) { nachtlicht(s, oben) }
                kussglas(s, oben)
                tee(s, oben)
                keks(s, oben)
                wunschglas(s, oben)
                if let hinweis { pille(hinweis).position(x: geo.size.width / 2, y: oben + 30 * s) }
            }
            .animation(reduceMotion ? nil : Feder.weich, value: vorhangOffen)
            .animation(reduceMotion ? nil : Feder.weich, value: dunkel)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tipp)
        .onAppear { inView = true }
        .onDisappear { inView = false }
        .onScrollVisibilityChange(threshold: 0.05) { inView = $0 }
        .onChange(of: sichtbar, initial: true) { _, da in ZimmerUmarmung.shared.sichtbar(da) }
        .task(id: RDaten.erster(RDaten.vorhang)) { partnerHinweis(RDaten.vorhang, "vorhang") }
        .task(id: RDaten.erster(RDaten.tee)) { partnerHinweis(RDaten.tee, "tee") }
        .task(id: halt) { await partnerHaeltPruefen() }
        .sheet(item: $blatt) { b in
            switch b {
            case .keks: ZimmerKeksBlatt()
            case .wuensche: ZimmerWunschBlatt()
            }
        }
    }

    // MARK: Bausteine

    private func ding<V: View>(_ rect: CGRect, _ s: CGFloat, _ oben: CGFloat, name: String, tippen: @escaping () -> Void,
                               @ViewBuilder _ inhalt: () -> V) -> some View {
        Button {
            tipp += 1
            tippen()
        } label: {
            inhalt().padding(8)
                .frame(minWidth: ProfilSlots.tippMinimum, minHeight: ProfilSlots.tippMinimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .position(x: rect.midX * s, y: oben + rect.midY * s)
    }

    private func pille(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: .capsule)
            .transition(.opacity)
            .allowsHitTesting(false)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private func zeigen(_ text: String) {
        withAnimation(reduceMotion ? nil : Feder.schnell) { hinweis = text }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if hinweis == text { withAnimation(reduceMotion ? nil : Feder.schnell) { hinweis = nil } }
        }
    }

    /// Hat der Partner heute zuerst gedrückt und ich habe das noch nicht gesehen: einmal am Tag sagen.
    private func partnerHinweis(_ schluessel: String, _ art: String) {
        let erster = RDaten.erster(schluessel)
        guard erster == ich.partner, sichtbar, RDaten.hinweisNeu(art) else { return }
        let text = art == "vorhang" ? RLogik.vorhangText(oeffner: erster, ich: ich) : RLogik.teeText(macher: erster, ich: ich)
        guard let text else { return }
        RDaten.hinweisGesehen(art)
        zeigen(text)
    }

    // MARK: 1 Vorhang und Sonne

    private func vorhang(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let r = Self.vorhangRect
        let zu = RLogik.vorhangZu(offenHeute: vorhangOffen, stunde: stunde)
        let fluegel = zu ? r.width / 2 : 12
        return ZStack(alignment: .topLeading) {
            if vorhangOffen, (6..<20).contains(stunde) {
                ZimmerRitualeZeichnung.Sonnenstrahl(breite: r.width * s, hoehe: 110 * s)
                    .position(x: r.midX * s, y: oben + (r.maxY + 55) * s)
            }
            HStack(spacing: 0) {
                ZimmerRitualeZeichnung.Vorhang(breite: fluegel * s, hoehe: r.height * s)
                Spacer(minLength: 0)
                ZimmerRitualeZeichnung.Vorhang(breite: fluegel * s, hoehe: r.height * s)
            }
            .frame(width: r.width * s, height: r.height * s)
            .allowsHitTesting(false)
            .position(x: r.midX * s, y: oben + r.midY * s)
            ding(r, s, oben, name: vorhangName, tippen: vorhangTippen) { Color.clear.frame(width: r.width * s, height: r.height * s) }
        }
    }

    private var vorhangName: String {
        if let t = RLogik.vorhangText(oeffner: RDaten.erster(RDaten.vorhang), ich: ich) { return "Vorhänge. \(t)" }
        return "Vorhänge aufmachen"
    }

    private func vorhangTippen() {
        if let t = RLogik.vorhangText(oeffner: RDaten.erster(RDaten.vorhang), ich: ich) { zeigen(t); return }
        RDaten.markeSetzen(RDaten.vorhang)
        RDaten.hinweisGesehen("vorhang")
        if stunde < 12 { figuren.grussSenden("morgen") }
        zeigen("Guten Morgen, die Vorhänge sind auf")
    }

    // MARK: 2 Gute-Nacht-Licht

    private var nachtDunkel: some View {
        Color.black.opacity(0.38).ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }

    private func nachtlicht(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let an = nachtGedrueckt
        return ding(Self.nachtlichtRect, s, oben, name: an ? "Gute-Nacht-Licht, brennt" : "Gute-Nacht-Licht anmachen", tippen: {
            if an { zeigen("Das Licht brennt schon. Gute Nacht") } else {
                figuren.grussSenden("nacht")
                zeigen("Gute Nacht, \(ich.partner.name) bekommt ein leises Zeichen")
            }
        }) { ZimmerRitualeZeichnung.Nachtlicht(an: an, e: s) }
    }

    // MARK: 6 Kussglas

    private func kussglas(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let n = RDaten.kuesse()
        let leuchtet = partnerHaelt || haeltEben
        return ding(Self.kussglasRect, s, oben, name: "Kussglas, \(n) Küsse", tippen: {
            zeigen("Halte das Glas, bis \(ich.partner.name) auch hält")
        }) { ZimmerRitualeZeichnung.Glas(herzen: RLogik.glasHerzen(n), leuchtet: leuchtet, e: s) }
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.8).onEnded { _ in kussHalten() })
        .accessibilityAction(named: "Glas halten") { kussHalten() }
        .sensoryFeedback(.success, trigger: n)
    }

    private func kussHalten() {
        let jetzt = Date()
        RDaten.setzen(RDaten.halt, zahl: jetzt.timeIntervalSince1970)
        haeltEben = true
        Task {
            try? await Task.sleep(for: .seconds(RLogik.kussFenster))
            haeltEben = false
        }
        let gezaehlt = RDaten.datum(RDaten.kussGezaehlt, von: ich)
        if RLogik.kussZaehlt(meinHalt: jetzt, partnerHalt: halt, schonGezaehlt: gezaehlt), let ph = halt {
            RDaten.setzen(RDaten.kuss, zahl: (RDaten.zahl(RDaten.kuss, von: ich) ?? 0) + 1)
            RDaten.setzen(RDaten.kussGezaehlt, zahl: ph.timeIntervalSince1970)
            figuren.gesteSenden("kuss")
            zeigen("Ein Kuss ist im Glas")
        } else {
            zeigen("Gehalten. \(ich.partner.name) hat \(Int(RLogik.kussFenster)) Sekunden Zeit")
        }
    }

    /// Das Glas leuchtet, solange der Partner innerhalb des Fensters gehalten hat. Einmaliges Warten, kein Takt.
    private func partnerHaeltPruefen() async {
        guard let h = halt, RLogik.haeltGerade(halt: h, jetzt: Date()) else { partnerHaelt = false; return }
        partnerHaelt = true
        let rest = RLogik.kussFenster - Date().timeIntervalSince(h)
        try? await Task.sleep(for: .seconds(max(rest, 0.5)))
        if !Task.isCancelled { partnerHaelt = false }
    }

    // MARK: 10 Tee für zwei

    private func tee(_ s: CGFloat, _ oben: CGFloat) -> some View {
        ding(Self.teeRect, s, oben, name: teeName, tippen: {
            if let t = RLogik.teeText(macher: RDaten.erster(RDaten.tee), ich: ich) { zeigen(t); return }
            RDaten.markeSetzen(RDaten.tee)
            RDaten.hinweisGesehen("tee")
            zeigen("Tee für \(ich.partner.name) ist fertig")
        }) { ZimmerRitualeZeichnung.Tee(gemacht: teeGemacht, e: s) }
    }

    private var teeName: String {
        RLogik.teeText(macher: RDaten.erster(RDaten.tee), ich: ich).map { "Tee für zwei. \($0)" } ?? "Tee für zwei machen"
    }

    // MARK: 8 Keks, 14 Wunschglas

    private func keks(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let beide = RLogik.antwortenOffen(meine: RDaten.keksAntwort(von: ich), partner: RDaten.keksAntwort(von: ich.partner))
        return ding(Self.keksRect, s, oben, name: "Glückskeks mit Frage des Tages", tippen: { blatt = .keks }) {
            ZimmerRitualeZeichnung.Keks(offen: beide, e: s)
        }
    }

    private func wunschglas(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let n = RDaten.meineWuensche().count + RDaten.partnerWuensche().count
        let gold = RLogik.gold(RDaten.meineWuensche(), erfuellt: RDaten.erfuellteIds(von: ich.partner))
            + RLogik.gold(RDaten.partnerWuensche(), erfuellt: RDaten.erfuellteIds(von: ich))
        return ding(Self.wunschglasRect, s, oben, name: "Wunschglas, \(n) Wünsche", tippen: { blatt = .wuensche }) {
            ZimmerRitualeZeichnung.Wunschglas(wuensche: n, gold: gold, e: s)
        }
    }
}
