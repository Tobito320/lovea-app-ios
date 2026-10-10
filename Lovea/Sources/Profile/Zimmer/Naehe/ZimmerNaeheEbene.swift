import SwiftUI

/// Unser Zimmer, Worker I: Nähe und Zeit als Overlay über `ZuhauseBuehne` (Welt 975 x 430, unten verankert).
/// Sternenhimmel (nachts), geheime Schublade, Koffer (nur mit Besuchstermin), Kissenburg (nur am Wochenende),
/// Plüschtier, Lichterkette, Faden (nur mit Schalter). Kein Takt: Tippen, Sync-Werte und einmaliges Warten.
struct ZimmerNaeheEbene: View {
    private let welt: ProfilWelt
    private let eigen: Bool

    // Immer sichtbare Orte in Entwurfseinheiten (für ZimmerPlatzLogik)
    static let schubladeRect = CGRect(x: 250, y: 384, width: 36, height: 30)
    static let plueschRect = CGRect(x: 20, y: 232, width: 34, height: 30)
    static let alleRects: [CGRect] = [schubladeRect, plueschRect]

    // Nur mit Kontext sichtbar
    static let kofferRect = CGRect(x: 300, y: 380, width: 40, height: 34)
    static let burgRect = CGRect(x: 330, y: 352, width: 64, height: 50)

    private struct Stern: Identifiable {
        let id: String
        let blatt: ZimmerBlatt
    }

    @State private var sternBlatt: ZimmerBlatt?
    @State private var schubladeAuf = false
    @State private var meinHalt: Date?
    @State private var hinweis: String?
    @State private var tipp = 0
    @State private var erinnerungen: [Stern] = []
    @State private var funkeln = false
    @State private var inView = true
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var oeffnen
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ZimmerNaeheLogik.fadenSchluessel) private var fadenAn = false

    init(welt: ProfilWelt = .panorama, eigen: Bool = true) {
        self.welt = welt
        self.eigen = eigen
    }

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var stunde: Int { Calendar.berlin.component(.hour, from: Date()) }
    private var sichtbar: Bool { inView && phase == .active }
    private var partnerHalt: Date? { ZimmerNaeheDaten.halt(von: ich.partner) }

    private var besuch: Int? {
        let heute = Datum.text(Date())
        let tage = KalenderModell.shared.zustand.daten.treffen.map(\.datum)
        return ZimmerNaeheLogik.tageBis(ZimmerNaeheLogik.naechsterBesuch(tage, heute: heute), heute: heute)
    }

    private var meineDecken: Int { ZimmerNaeheDaten.decken(von: ich) }
    private var partnerDecken: Int { ZimmerNaeheDaten.decken(von: ich.partner) }

    private var birnen: [Bool] {
        ZimmerNaeheLogik.birnen(meine: ZimmerNaeheDaten.tage(von: ich), partner: ZimmerNaeheDaten.tage(von: ich.partner), heute: Date())
    }

    private var fadenKm: Int? {
        guard fadenAn, let a = Standort.shared.positionen[ich], let b = Standort.shared.positionen[ich.partner] else { return nil }
        return ZimmerNaeheLogik.gerundeteKm(meter: a.meter(bis: b))
    }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / welt.breite
            let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
            ZStack(alignment: .topLeading) {
                if ZimmerNaeheLogik.nacht(stunde: stunde) { sterne(s, oben) }
                lichterkette(s, oben)
                if let km = fadenKm { faden(km, s, oben) }
                plueschtier(s, oben)
                schublade(s, oben)
                if let tage = besuch, tage >= 0 { koffer(tage, s, oben) }
                if ZimmerNaeheLogik.wochenende(Date()) { burg(s, oben) }
                if funkeln { ueberraschung(geo.size, oben, s) }
                if let hinweis { pille(hinweis).position(x: geo.size.width / 2, y: oben + 70 * s) }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tipp)
        .onAppear { inView = true }
        .onDisappear { inView = false }
        .onScrollVisibilityChange(threshold: 0.05) { inView = $0 }
        .task(id: sichtbar) { if sichtbar { ZimmerNaeheDaten.heuteEintragen() } }
        .task(id: partnerHalt) { schubladePruefen() }
        .task(id: ChatModell.shared.nachrichten.count) { erinnerungenLaden() }
        .task(id: ZimmerNaeheLogik.kettenVoll(birnen)) { ueberraschungPruefen() }
        .sheet(item: $sternBlatt) { ZimmerBlattInhalt(blatt: $0) }
        .sheet(isPresented: $schubladeAuf) { SchubladeBlatt() }
    }

    // MARK: Bausteine

    private func ding<V: View>(_ rect: CGRect, _ s: CGFloat, _ oben: CGFloat, name: String, tippen: @escaping () -> Void,
                               @ViewBuilder _ inhalt: () -> V) -> some View {
        Button {
            tipp += 1
            tippen()
        } label: {
            inhalt()
                .frame(minWidth: ProfilSlots.tippMinimum, minHeight: ProfilSlots.tippMinimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .position(x: rect.midX * s, y: oben + rect.midY * s)
    }

    private func symbol(_ name: String, _ rect: CGRect, _ s: CGFloat, _ farbe: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: rect.height * s * 0.85))
            .foregroundStyle(farbe)
            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
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

    // MARK: 2 Sternenhimmel

    private func erinnerungenLaden() {
        let monate = ZimmerAlbumLogik.monate(aus: ChatModell.shared.nachrichten, ich: ich)
        var liste: [Stern] = []
        for m in monate {
            for f in m.fotos { liste.append(Stern(id: f.id, blatt: .foto(medienId: f.medium.id, titel: m.titel))) }
            for t in m.saetze { liste.append(Stern(id: t.id, blatt: .info(titel: m.titel, text: t.text))) }
        }
        let ids = Set(ZimmerNaeheLogik.sterne(ids: liste.map(\.id)))
        erinnerungen = liste.filter { ids.contains($0.id) }
    }

    private func sterne(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let feld = CGRect(x: 200, y: 10, width: 660, height: 34)
        return ForEach(erinnerungen) { e in
            let p = ZimmerNaeheLogik.sternOrt(id: e.id)
            let ort = CGRect(x: feld.minX + p.x * feld.width - 6, y: feld.minY + p.y * feld.height - 6, width: 12, height: 12)
            ding(ort, s, oben, name: "Stern, eine Erinnerung", tippen: { sternBlatt = e.blatt }) {
                symbol("star.fill", ort, s, .yellow.opacity(0.9))
            }
        }
    }

    // MARK: 20 Lichterkette

    private func lichterkette(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let liste = birnen
        let an = liste.filter { $0 }.count
        return Canvas { ctx, _ in
            let x0 = 200 * s, x1 = 860 * s, y0 = oben + 6 * s
            var draht = Path()
            draht.move(to: CGPoint(x: x0, y: y0))
            draht.addQuadCurve(to: CGPoint(x: x1, y: y0), control: CGPoint(x: (x0 + x1) / 2, y: y0 + 24 * s))
            ctx.stroke(draht, with: .color(.black.opacity(0.35)), lineWidth: max(1, s))
            let n = liste.count
            for (i, leuchtet) in liste.enumerated() {
                let t = CGFloat(i) / CGFloat(max(n - 1, 1))
                let x = x0 + (x1 - x0) * t
                let y = y0 + 24 * s * t * (1 - t) * 2 + 2 * s
                let r = max(2, 3.2 * s)
                let kreis = Path(ellipseIn: CGRect(x: x - r, y: y, width: 2 * r, height: 2 * r))
                ctx.fill(kreis, with: .color(leuchtet ? .yellow : .gray.opacity(0.45)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Lichterkette, \(an) von \(ZimmerNaeheLogik.kettenTage) Tagen zusammen")
    }

    private func ueberraschungPruefen() {
        let schluessel = "lovea.zimmer.kette.gezeigt"
        guard ZimmerNaeheLogik.kettenVoll(birnen), sichtbar, !UserDefaults.standard.bool(forKey: schluessel) else { return }
        UserDefaults.standard.set(true, forKey: schluessel)
        withAnimation(reduceMotion ? nil : Feder.weich) { funkeln = true }
        zeigen("30 Tage, jeden Tag zusammen. Die ganze Kette leuchtet")
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(reduceMotion ? nil : Feder.weich) { funkeln = false }
        }
    }

    private func ueberraschung(_ groesse: CGSize, _ oben: CGFloat, _ s: CGFloat) -> some View {
        Image(systemName: "sparkles")
            .font(.system(size: 120 * s))
            .foregroundStyle(.yellow)
            .symbolEffect(.bounce, options: reduceMotion ? .nonRepeating : .repeat(2), value: funkeln)
            .position(x: groesse.width / 2, y: oben + 40 * s)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: 11 Faden

    private func faden(_ km: Int, _ s: CGFloat, _ oben: CGFloat) -> some View {
        let laenge = ZimmerNaeheLogik.fadenLaenge(km: km)
        return Canvas { ctx, _ in
            let x0 = 20 * s, x1 = x0 + 940 * s * laenge, y = oben + 120 * s
            var pfad = Path()
            pfad.move(to: CGPoint(x: x0, y: y))
            pfad.addQuadCurve(to: CGPoint(x: x1, y: y), control: CGPoint(x: (x0 + x1) / 2, y: y + 30 * s * (1 - laenge)))
            ctx.stroke(pfad, with: .color(.red.opacity(0.8)), lineWidth: max(1.5, 1.5 * s))
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Roter Faden. \(ZimmerNaeheLogik.fadenText(km: km) ?? "")")
    }

    // MARK: 18 Plüschtier

    private func plueschtier(_ s: CGFloat, _ oben: CGFloat) -> some View {
        ding(Self.plueschRect, s, oben, name: "Plüschtier. Gedrückt halten spielt die letzte Sprachnachricht", tippen: {
            zeigen("Gedrückt halten spielt die letzte Sprachnachricht von \(ich.partner.name)")
        }) { symbol("teddybear.fill", Self.plueschRect, s, .brown) }
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in sprachpostSpielen() })
        .accessibilityAction(named: "Sprachnachricht abspielen") { sprachpostSpielen() }
    }

    private func sprachpostSpielen() {
        guard let post = ZimmerNaeheLogik.neuesteSprachpost(SprachpostSpeicher.shared.liste, von: ich.partner) else {
            zeigen("Noch keine Sprachnachricht von \(ich.partner.name)")
            return
        }
        tipp += 1
        if SprachSpieler.shared.spielt(post.medienId) { SprachSpieler.shared.pausieren(); return }
        Task {
            let url: URL?
            if let lokal = Medien.lokal(post.medienId) { url = lokal } else { url = try? await Medien.holen(post.medienId) }
            guard let url else { zeigen("Sprachnachricht lädt noch nicht"); return }
            SprachSpieler.shared.spielen(id: post.medienId, url: url)
        }
    }

    // MARK: 8 Schublade

    private func schublade(_ s: CGFloat, _ oben: CGFloat) -> some View {
        ding(Self.schubladeRect, s, oben, name: "Geheime Schublade. Öffnet, wenn ihr beide innerhalb von 10 Sekunden tippt", tippen: {
            let jetzt = Date()
            meinHalt = jetzt
            RDaten.setzen(ZimmerNaeheDaten.haltKey, zahl: jetzt.timeIntervalSince1970)
            if ZimmerNaeheLogik.schubladeOffen(meinHalt: jetzt, partnerHalt: partnerHalt, jetzt: jetzt) {
                schubladeAuf = true
            } else {
                zeigen("Die Schublade klemmt. \(ich.partner.name) muss in 10 Sekunden auch tippen")
            }
        }) { symbol("tray.fill", Self.schubladeRect, s, .brown) }
    }

    /// Tippt der Partner nach mir innerhalb des Fensters, geht die Schublade bei mir auf.
    private func schubladePruefen() {
        guard sichtbar, ZimmerNaeheLogik.schubladeOffen(meinHalt: meinHalt, partnerHalt: partnerHalt, jetzt: Date()) else { return }
        schubladeAuf = true
    }

    // MARK: 12 Koffer

    private func koffer(_ tage: Int, _ s: CGFloat, _ oben: CGFloat) -> some View {
        let n = ZimmerNaeheLogik.gepackt(tageBis: tage)
        let text = tage == 0 ? "Heute seht ihr euch" : "Noch \(tage) Tage bis zum Besuch"
        return ding(Self.kofferRect, s, oben, name: "Koffer, \(n) von \(ZimmerNaeheLogik.koffer.count) Dingen gepackt. \(text)", tippen: {
            let drin = ZimmerNaeheLogik.koffer.prefix(n).joined(separator: ", ")
            zeigen(n == 0 ? text : "\(text). Gepackt: \(drin)")
        }) { symbol("suitcase.fill", Self.kofferRect, s, .orange) }
    }

    // MARK: 15 Kissenburg

    private func burg(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let voll = ZimmerNaeheLogik.burgVoll(meine: meineDecken, partner: partnerDecken)
        let anzahl = ZimmerNaeheLogik.decken(meine: meineDecken, partner: partnerDecken)
        return ding(Self.burgRect, s, oben, name: "Kissenburg, \(anzahl) von \(ZimmerNaeheLogik.deckenVoll) Decken", tippen: {
            if voll { zusammenAnrufen(); return }
            guard meineDecken < ZimmerNaeheLogik.deckenProPerson else {
                zeigen("Deine Decken liegen schon. Jetzt ist \(ich.partner.name) dran")
                return
            }
            RDaten.setzen(ZimmerNaeheDaten.deckenKey, zahl: Double(meineDecken + 1))
        }) {
            VStack(spacing: 2) {
                symbol("tent.fill", Self.burgRect, s, voll ? .pink : .indigo)
                if voll {
                    Text("Zusammen anrufen")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: .capsule)
                }
            }
        }
    }

    private func zusammenAnrufen() {
        guard let url = FaceTime.url(audio: false, kontakt: FaceTime.kontakt(von: ich.partner)) else {
            zeigen("Trag den FaceTime-Kontakt von \(ich.partner.name) in den Einstellungen ein")
            return
        }
        oeffnen(url)
    }
}

/// Der Inhalt der Schublade: Zettel von beiden, eigene dazuschreiben.
private struct SchubladeBlatt: View {
    @State private var zettel = ZimmerNaeheDaten.alleZettel()
    @State private var eingabe = ""
    @State private var gespeichert = 0
    @FocusState private var fokus: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Zettel für die Schublade", text: $eingabe, axis: .vertical)
                        .focused($fokus)
                        .onAppear { fokus = true }
                        .lineLimit(1...3)
                    Button("Zettel hineinlegen", action: hinzu)
                        .disabled(ZimmerNaeheLogik.bereinigt(eingabe) == nil)
                }
                Section("In der Schublade") {
                    if zettel.isEmpty { Text("Noch leer").foregroundStyle(.secondary) }
                    ForEach(zettel) { Text($0.text) }
                }
            }
            .navigationTitle("Geheime Schublade")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: gespeichert)
        }
        .presentationDetents([.medium, .large])
    }

    private func hinzu() {
        guard ZimmerNaeheLogik.bereinigt(eingabe) != nil else { return }
        ZimmerNaeheDaten.zettelSchreiben(eingabe)
        eingabe = ""
        zettel = ZimmerNaeheDaten.alleZettel()
        gespeichert += 1
    }
}
