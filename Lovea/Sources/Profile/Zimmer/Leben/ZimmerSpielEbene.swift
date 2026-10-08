import SwiftUI

/// Unser Zimmer, Worker C: die kleinen Spiel-Dinge im gemeinsamen Zimmer. Zwei Stimmungs-Pflanzen (Töpfe
/// links und rechts vom Sofa), die Termine-Pinnwand, das Leuchten der Lampe, wenn der Partner online ist,
/// und der Zettel auf dem Bett. Liegt als Overlay über `ZuhauseBuehne` und rechnet wie `AlltagEbene`
/// (Welt 975 x 430, unten verankert). Es wird nichts geladen und kein Takt gestartet.
struct ZimmerSpielEbene: View {
    private let welt: ProfilWelt
    @Binding var signale: SignaleBlatt?

    @State private var blatt: ZimmerSpielBlatt?
    @State private var statistik: ZimmerStatistikZiel?
    @State private var kalenderOffen = false
    @State private var tipp = 0
    @Namespace private var zoomRaum
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(signale: Binding<SignaleBlatt?>, welt: ProfilWelt = .panorama) {
        _signale = signale
        self.welt = welt
    }

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var heute: String { Datum.text(Date()) }

    /// Pinnwand der Termine: rechts neben der Foto-Pinnwand (`.pinnwand` = 775, 58, 84 x 60).
    private static let termineBrett = CGRect(x: 865, y: 58, width: 84, height: 60)

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / welt.breite
            let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
            ZStack(alignment: .topLeading) {
                lampenGlanz(s, oben)
                zettel(s, oben)
                termine(s, oben)
                topf(.ahmed, s, oben)
                topf(.annika, s, oben)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tipp)
        .sensoryFeedback(.success, trigger: SignaleSpeicher.shared.stand.stimmung[ich]?.opId)
        .task(id: SignaleSpeicher.shared.stand.stimmung[ich]?.opId) { giessen() }
        .zimmerStatistik($statistik)
        .sheet(item: $blatt) { b in
            switch b {
            case .zettel: ZimmerSpielZettelBlatt(ich: ich)
            }
        }
        .fullScreenCover(isPresented: $kalenderOffen) {
            NavigationStack {
                TagNeu(tag: heute)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Schließen") { kalenderOffen = false } }
                    }
            }
            .navigationTransition(.zoom(sourceID: "termine", in: zoomRaum))
        }
    }

    // MARK: Teile

    private struct Aktion {
        let titel: String
        let symbol: String
        let tun: () -> Void
    }

    /// Ein antippbares Ding an einer Stelle der Welt: mindestens 44 x 44 pt, Haptik, Long-Press-Menü, Label.
    private func ding<V: View>(_ mitte: CGPoint, _ s: CGFloat, _ oben: CGFloat, name: String, menue: [Aktion] = [],
                               tippen: @escaping () -> Void, @ViewBuilder _ inhalt: () -> V) -> some View {
        Button {
            tipp += 1
            tippen()
        } label: {
            inhalt().padding(8)
                .frame(minWidth: ProfilSlots.tippMinimum, minHeight: ProfilSlots.tippMinimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            ForEach(Array(menue.enumerated()), id: \.offset) { _, a in
                Button { tipp += 1; a.tun() } label: { Label(a.titel, systemImage: a.symbol) }
            }
        }
        .accessibilityLabel(name)
        .position(x: mitte.x * s, y: oben + mitte.y * s)
    }

    // MARK: Stimmungs-Pflanzen (Feature 6)

    /// Ein Topf je Person links (Ahmed) und rechts (Annika) vom Sofa. Tippen: im eigenen Topf die
    /// Stimmung wählen (das gießt), im anderen die Zahlen der Person.
    private func topf(_ p: Person, _ s: CGFloat, _ oben: CGFloat) -> some View {
        let sofa = welt.rect(.sofa)
        let mitte = CGPoint(x: p == .ahmed ? sofa.minX - 20 : sofa.maxX + 20, y: sofa.maxY - 24)
        let stand = pflanzenStand(p)
        let eigener = p == ich
        let zustand: String
        if stand.haengt { zustand = "lässt die Blätter hängen" } else if stand.serie > 0 { zustand = "\(stand.serie) Tage gegossen" } else { zustand = "noch nicht gegossen" }
        let heuteText: String = stand.heuteGegossen ? ", heute gegossen" : ", heute noch nicht gegossen"
        let name: String = "Stimmungs-Pflanze von \(p.name): " + zustand + heuteText
        var menue = [Aktion(titel: "Zahlen von \(p.name)", symbol: "chart.bar.fill") { statistik = ZimmerStatistikZiel(person: p) }]
        if eigener { menue.insert(Aktion(titel: "Stimmung wählen und gießen", symbol: "drop.fill") { signale = .stimmung }, at: 0) }
        return ding(mitte, s, oben, name: name, menue: menue, tippen: {
            if eigener { signale = .stimmung } else { statistik = ZimmerStatistikZiel(person: p) }
        }) {
            ZimmerSpielPflanze(stand: stand, s: s)
                .animation(reduceMotion ? nil : Feder.weich, value: stand)
                .overlay(alignment: .top) { giessAbzeichen(stand, s).offset(y: -9 * s) }
        }
    }

    /// Tropfen über der Pflanze: heute gegossen oder noch nicht; Funken, wenn beide heute gegossen haben (Quest).
    @ViewBuilder
    private func giessAbzeichen(_ stand: StimmungsPflanzeLogik.Stand, _ s: CGFloat) -> some View {
        if stand.heuteGegossen {
            Image(systemName: beideGegossen ? "sparkles" : "drop.fill")
                .font(.system(size: 9 * s, weight: .bold))
                .foregroundStyle(beideGegossen ? Color.yellow : Color.blue)
        } else {
            Image(systemName: "drop")
                .font(.system(size: 9 * s, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    /// Die Tage, an denen eine Person gegossen hat: der gespeicherte Verlauf plus der Tag der gesetzten Stimmung
    /// (so zählt es auch, wenn die Einstellungen noch nicht angekommen sind).
    private func tage(_ p: Person) -> Set<String> {
        var t = Set(ZimmerSpielDaten.tage(p))
        if let e = SignaleSpeicher.shared.stand.stimmung[p], e.art != nil { t.insert(Datum.text(e.zeit)) }
        return t
    }

    private func pflanzenStand(_ p: Person) -> StimmungsPflanzeLogik.Stand {
        StimmungsPflanzeLogik.stand(tage: tage(p), heute: heute)
    }

    /// Halbe Quest "beide gießen heute": Zustand wird gezeigt. Punkte vergibt das `PunkteModell` nur aus
    /// eigenen Ops, es gibt keine Schnittstelle zum Gutschreiben, darum keine Auszahlung hier.
    private var beideGegossen: Bool {
        StimmungsPflanzeLogik.beideHeute(ich: tage(.ahmed), partner: tage(.annika), heute: heute)
    }

    /// Hält die eigene Stimmung als Gieß-Tag fest.
    private func giessen() {
        guard let e = SignaleSpeicher.shared.stand.stimmung[ich], e.art != nil else { return }
        ZimmerSpielDaten.giessen(ich, tag: Datum.text(e.zeit))
    }

    // MARK: Termine (Feature 7)

    private func termine(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let r = Self.termineBrett
        let zeilen = termineHeute
        let name = zeilen.isEmpty ? "Termine-Pinnwand, heute nichts eingetragen" : "Termine-Pinnwand: " + zeilen.joined(separator: ", ")
        return ding(CGPoint(x: r.midX, y: r.midY), s, oben, name: name,
                    menue: [Aktion(titel: "Kalender öffnen", symbol: "calendar") { kalenderOffen = true }],
                    tippen: { kalenderOffen = true }) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                    .fill(Color(red: 0.76, green: 0.58, blue: 0.38))
                    .overlay(RoundedRectangle(cornerRadius: 4 * s, style: .continuous).stroke(Color(red: 0.45, green: 0.30, blue: 0.18), lineWidth: 2 * s))
                VStack(alignment: .leading, spacing: 1 * s) {
                    ForEach(Array(zeilen.prefix(3).enumerated()), id: \.offset) { _, z in
                        Text(z)
                            .font(.system(size: 7 * s, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .padding(.horizontal, 2 * s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 1.5 * s))
                    }
                    if zeilen.isEmpty {
                        Text("heute frei")
                            .font(.system(size: 7 * s, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.9))
                    } else if zeilen.count > 3 {
                        Text("+\(zeilen.count - 3)")
                            .font(.system(size: 7 * s, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                    }
                }
                .foregroundStyle(Pal.tinte.farbe)
                .padding(4 * s)
            }
            .frame(width: r.width * s, height: r.height * s)
            .matchedTransitionSource(id: "termine", in: zoomRaum)
        }
    }

    /// Heutige Termine und Treffen aus dem bestehenden Kalender, je Zeile "HH:mm Titel".
    private var termineHeute: [String] {
        let daten = KalenderModell.shared.zustand.daten
        var zeilen: [String] = []
        for t in daten.termine where t.faelltAuf(heute) {
            zeilen.append((t.start(am: heute).map { $0 + " " } ?? "") + t.titel)
        }
        for t in daten.treffen where t.datum == heute {
            zeilen.append((t.uhrzeit.map { $0 + " " } ?? "") + (t.wasMachenWir ?? "Treffen"))
        }
        return zeilen
    }

    // MARK: Lampe (Feature 11)

    /// Das Fenster zeigt schon Tageszeit und Wetter (`ZimmerLebenBild`); hier leuchtet die Lampe, solange
    /// der Partner online ist.
    @ViewBuilder
    private func lampenGlanz(_ s: CGFloat, _ oben: CGFloat) -> some View {
        if Raum.shared.partnerDa {
            let r = welt.rect(.lampe)
            RadialGradient(colors: [Color.yellow.opacity(0.55), Color.yellow.opacity(0)], center: .center, startRadius: 0, endRadius: 46 * s)
                .frame(width: 92 * s, height: 92 * s)
                .position(x: r.midX * s, y: oben + (r.minY + r.height * 0.35) * s)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel("Die Lampe leuchtet, \(ich.partner.name) ist online")
        }
    }

    // MARK: Zettel auf dem Bett (Feature 15)

    private func zettel(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let bett = welt.rect(.bett)
        let vomPartner = ZimmerSpielDaten.zettel(von: ich.partner, tag: heute)
        let name = vomPartner != nil ? "Zettel von \(ich.partner.name) auf dem Bett, lesen" : "Zettel auf dem Bett, einen Zettel für \(ich.partner.name) schreiben"
        return ding(CGPoint(x: bett.midX, y: bett.minY + bett.height * 0.3), s, oben, name: name,
                    menue: [Aktion(titel: vomPartner != nil ? "Zettel lesen" : "Zettel schreiben", symbol: "note.text") { blatt = .zettel }],
                    tippen: { blatt = .zettel }) {
            Image(systemName: vomPartner != nil ? "heart.text.square.fill" : "note.text")
                .font(.system(size: 17 * s))
                .foregroundStyle(vomPartner != nil ? Color.loveaRose : Color.white.opacity(0.85))
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(0.25), radius: 1.5 * s, y: 1 * s)
        }
    }
}

// MARK: - Blätter

enum ZimmerSpielBlatt: String, Identifiable {
    case zettel
    var id: String { rawValue }
}

struct ZimmerStatistikZiel: Identifiable {
    let person: Person
    var id: String { person.rawValue }
}

extension View {
    /// Das kleine Blatt mit den Zahlen einer Person (Avatar im Kopf oder Topf antippen).
    func zimmerStatistik(_ ziel: Binding<ZimmerStatistikZiel?>) -> some View {
        sheet(item: ziel) { z in
            ZimmerStatistikBlatt(person: z.person)
                .presentationDetents([.medium])
        }
    }
}

/// Zahlen einer Person: Stimmung, Gieß-Serie, Schritte-Serie, Punkte, Tage zusammen.
struct ZimmerStatistikBlatt: View {
    let person: Person

    var body: some View {
        let heute = Datum.text(Date())
        let tage = ZimmerSpielDaten.tage(person)
        let stand = StimmungsPflanzeLogik.stand(tage: Set(tage), heute: heute)
        let jahrestag = KalenderModell.shared.zustand.jahrestag ?? "2026-08-26"
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ProfilAvatar(person: person, online: person == (Raum.shared.ich ?? person) ? Raum.shared.verbunden : Raum.shared.partnerDa, d: 64)
                        Text(person.name).font(.title2.weight(.bold))
                    }
                    .accessibilityElement(children: .combine)
                }
                Section {
                    zeile("Stimmung", SignaleSpeicher.shared.stimmung(von: person)?.name ?? "keine gesetzt", "face.smiling")
                    zeile("Pflanze", stand.haengt ? "hängt, gieß sie wieder" : "\(stand.serie) Tage gegossen", "leaf.fill")
                    zeile("Schritte-Serie", "\(PunkteModell.shared.laufendeSerien[person] ?? 0) Tage", "figure.walk")
                    zeile("Punkte", "\(PunkteModell.shared.verfuegbar(person))", "star.fill")
                    zeile("Zusammen", "\(max(0, Datum.tageZwischen(jahrestag, heute))) Tage", "heart.fill")
                }
            }
            .navigationTitle("\(person.name) im Zimmer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func zeile(_ titel: String, _ wert: String, _ symbol: String) -> some View {
        LabeledContent {
            Text(wert)
        } label: {
            Label(titel, systemImage: symbol)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Zettel auf dem Bett: oben der Zettel des Partners von heute, darunter der eigene für ihn/sie.
struct ZimmerSpielZettelBlatt: View {
    let ich: Person
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private static let hoechstens = 80

    var body: some View {
        let heute = Datum.text(Date())
        let erhalten = ZimmerSpielDaten.zettel(von: ich.partner, tag: heute)
        NavigationStack {
            Form {
                if let erhalten {
                    Section("Von \(ich.partner.name)") {
                        Text(erhalten.text)
                            .font(.title3.weight(.semibold))
                            .accessibilityLabel("Zettel von \(ich.partner.name): \(erhalten.text)")
                    }
                }
                Section("Für \(ich.partner.name)") {
                    TextField("Kurzer Zettel aufs Bett", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .onChange(of: text) { _, neu in
                            if neu.count > Self.hoechstens { text = String(neu.prefix(Self.hoechstens)) }
                        }
                }
            }
            .navigationTitle("Zettel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinlegen") {
                        ZimmerSpielDaten.zettelLegen(von: ich, text: text, tag: heute)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { text = ZimmerSpielDaten.zettel(von: ich, tag: heute)?.text ?? "" }
    }
}

// MARK: - Daten

/// Ein Zettel aufs Bett: Text und der Tag, an dem er hingelegt wurde (gilt nur an dem Tag).
struct ZimmerSpielZettel: Codable, Equatable {
    var text: String
    var tag: String
}

/// Liegt in den gemeinsamen Einstellungen (`ZimmerLebenModell.lesen/schreiben`, neuester Schreiber gewinnt),
/// je ein Schlüssel pro Person, geschrieben wird nur der eigene.
@MainActor
enum ZimmerSpielDaten {
    static func tageSchluessel(_ p: Person) -> String { "zimmer.stimmungstage.\(p.rawValue)" }
    static func zettelSchluessel(_ p: Person) -> String { "zimmer.zettel.\(p.rawValue)" }

    static func tage(_ p: Person) -> [String] {
        ZimmerLebenModell.lesen(tageSchluessel(p), als: [String].self) ?? []
    }

    /// Trägt `tag` als Gieß-Tag ein, nur wenn er noch fehlt (kein unnötiger Schreibvorgang).
    static func giessen(_ p: Person, tag: String) {
        let alt = tage(p)
        guard !alt.contains(tag) else { return }
        ZimmerLebenModell.schreiben(tageSchluessel(p), StimmungsPflanzeLogik.gegossen(alt, heute: tag))
    }

    static func zettel(von p: Person, tag: String) -> ZimmerSpielZettel? {
        guard let z = ZimmerLebenModell.lesen(zettelSchluessel(p), als: ZimmerSpielZettel.self), z.tag == tag, !z.text.isEmpty else { return nil }
        return z
    }

    static func zettelLegen(von p: Person, text: String, tag: String) {
        ZimmerLebenModell.schreiben(zettelSchluessel(p), ZimmerSpielZettel(text: text.trimmingCharacters(in: .whitespacesAndNewlines), tag: tag))
    }
}

// MARK: - Zeichnung

/// Topf mit Pflanze: Stufe 0 Keimling bis 4 mit Blüte; hängt sie, neigen sich Stängel und Blätter nach unten.
private struct ZimmerSpielPflanze: View {
    let stand: StimmungsPflanzeLogik.Stand
    let s: CGFloat

    var body: some View {
        let gruen = stand.haengt ? Color(red: 0.55, green: 0.6, blue: 0.3) : Color(red: 0.25, green: 0.65, blue: 0.35)
        let hoehe = (8 + 7 * CGFloat(stand.stufe)) * s
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Capsule().fill(gruen).frame(width: 3 * s, height: hoehe)
                    .rotationEffect(.degrees(stand.haengt ? 14 : 0), anchor: .bottom)
                ForEach(0..<min(stand.stufe + 1, 4), id: \.self) { i in
                    let links = i.isMultiple(of: 2)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: (9 + CGFloat(i)) * s))
                        .foregroundStyle(gruen)
                        .scaleEffect(x: links ? -1 : 1)
                        .rotationEffect(.degrees(stand.haengt ? (links ? -70 : 70) : (links ? -20 : 20)))
                        .offset(x: (links ? -6 : 6) * s, y: -CGFloat(3 + 6 * i) * s)
                }
                if stand.stufe == StimmungsPflanzeLogik.hoechststufe {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 12 * s))
                        .foregroundStyle(Color.loveaRose)
                        .offset(y: -hoehe + 2 * s)
                }
            }
            .frame(height: 46 * s, alignment: .bottom)
            UnevenRoundedRectangle(topLeadingRadius: 2 * s, bottomLeadingRadius: 5 * s, bottomTrailingRadius: 5 * s, topTrailingRadius: 2 * s)
                .fill(Color(red: 0.78, green: 0.42, blue: 0.3))
                .frame(width: 22 * s, height: 14 * s)
        }
    }
}
