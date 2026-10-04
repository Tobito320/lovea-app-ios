import SwiftUI

struct ZyklusRingText: Equatable {
    var titel: String
    var untertitel: String
    var ton: ZyklusPhasenTon
    var fortschritt: Double
}

struct ZyklusEintragZeile: Equatable, Identifiable {
    var symbol: String
    var titel: String
    var id: String { titel }
}

/// Reine Texte und Rechnungen der Heute-Ansicht.
enum ZyklusHeuteLogik {
    static func ton(_ phase: Phase) -> ZyklusPhasenTon {
        switch phase {
        case .periode: .periode
        case .follikel: .follikel
        case .fruchtbar: .fruchtbar
        case .eisprung: .eisprung
        case .luteal: .luteal
        }
    }

    static func tageBis(_ von: String, _ bis: String) -> Int {
        Datum.kalender.dateComponents([.day], from: Datum.datum(von), to: Datum.datum(bis)).day ?? 0
    }

    static func ringText(logik: ZyklusLogik, heute: String) -> ZyklusRingText {
        guard let nummer = logik.zyklusTagNummer(am: heute), let phase = logik.phase(am: heute) else {
            if let d = logik.verspaetung {
                return ZyklusRingText(titel: "Spät dran", untertitel: d == 1 ? "Periode 1 Tag später" : "Periode \(d) Tage später", ton: .luteal, fortschritt: 1)
            }
            return ZyklusRingText(titel: "Hallo", untertitel: "Trag deine erste Periode ein", ton: .periode, fortschritt: 0)
        }
        let fortschritt = Double(nummer) / Double(max(logik.mittlereZyklusLaenge, 1))
        let untertitel: String
        switch phase {
        case .eisprung:
            untertitel = "Eisprung"
        case .fruchtbar:
            untertitel = "Fruchtbar"
        case .periode:
            untertitel = "Periode"
        case .follikel, .luteal:
            if let d = logik.verspaetung {
                untertitel = d == 1 ? "Periode 1 Tag später" : "Periode \(d) Tage später"
            } else if let n = logik.naechstePeriode {
                let tage = tageBis(heute, n)
                untertitel = tage <= 0 ? "Periode kommt heute" : (tage == 1 ? "Periode in 1 Tag" : "Periode in \(tage) Tagen")
            } else {
                untertitel = "Periode bald"
            }
        }
        return ZyklusRingText(titel: "Tag \(nummer)", untertitel: untertitel, ton: ton(phase), fortschritt: min(fortschritt, 1))
    }

    static func eintraege(_ tag: ZyklusTag?) -> [ZyklusEintragZeile] {
        guard let t = tag else { return [] }
        var z: [ZyklusEintragZeile] = []
        if let b = t.blutung {
            let n: String
            switch b {
            case .schmierblutung: n = "Schmierblutung"
            case .leicht: n = "Leichte Blutung"
            case .mittel: n = "Mittlere Blutung"
            case .stark: n = "Starke Blutung"
            }
            z.append(ZyklusEintragZeile(symbol: "drop.fill", titel: n))
        }
        for s in Symptom.allCases where t.symptome.contains(s) {
            z.append(ZyklusEintragZeile(symbol: "cross.case.fill", titel: symptomName(s)))
        }
        for s in Stimmung.allCases where t.stimmung.contains(s) {
            z.append(ZyklusEintragZeile(symbol: "face.smiling", titel: stimmungName(s)))
        }
        if let a = t.ausfluss, a != .keiner {
            z.append(ZyklusEintragZeile(symbol: "sparkles", titel: "Ausfluss \(ausflussName(a))"))
        }
        if let g = t.temperatur {
            z.append(ZyklusEintragZeile(symbol: "thermometer.medium", titel: String(format: "%.2f Grad", g).replacingOccurrences(of: ".", with: ",")))
        }
        if let e = t.eisprungTest {
            z.append(ZyklusEintragZeile(symbol: "checkmark.circle", titel: e == .positiv ? "Eisprungtest positiv" : "Eisprungtest negativ"))
        }
        if let e = t.schwangerschaftsTest {
            z.append(ZyklusEintragZeile(symbol: "checkmark.circle", titel: e == .positiv ? "Schwangerschaftstest positiv" : "Schwangerschaftstest negativ"))
        }
        if let s = t.sex {
            z.append(ZyklusEintragZeile(symbol: "heart.fill", titel: s == .geschuetzt ? "Zweisamkeit geschützt" : "Zweisamkeit ungeschützt"))
        }
        if t.pille == true { z.append(ZyklusEintragZeile(symbol: "pills.fill", titel: "Pille genommen")) }
        if let w = t.wasserMl { z.append(ZyklusEintragZeile(symbol: "drop", titel: "\(w) ml Wasser")) }
        if let m = t.schlafMin { z.append(ZyklusEintragZeile(symbol: "bed.double.fill", titel: "\(m / 60) Std \(m % 60) Min Schlaf")) }
        if let g = t.gewicht {
            z.append(ZyklusEintragZeile(symbol: "scalemass.fill", titel: String(format: "%.1f kg", g).replacingOccurrences(of: ".", with: ",")))
        }
        return z
    }

    static func symptomName(_ s: Symptom) -> String {
        switch s {
        case .kopfschmerzen: "Kopfschmerzen"
        case .kraempfe: "Krämpfe"
        case .rueckenschmerzen: "Rückenschmerzen"
        case .brustspannen: "Brustspannen"
        case .uebelkeit: "Übelkeit"
        case .blaehbauch: "Blähbauch"
        case .akne: "Unreine Haut"
        case .muedigkeit: "Müde"
        case .heisshunger: "Heißhunger"
        case .schwindel: "Schwindel"
        case .verstopfung: "Verstopfung"
        case .durchfall: "Durchfall"
        }
    }

    static func stimmungName(_ s: Stimmung) -> String {
        switch s {
        case .froehlich: "Fröhlich"
        case .ruhig: "Ruhig"
        case .energiegeladen: "Voller Energie"
        case .empfindlich: "Empfindlich"
        case .gereizt: "Gereizt"
        case .traurig: "Traurig"
        case .aengstlich: "Ängstlich"
        case .gestresst: "Gestresst"
        }
    }

    static func ausflussName(_ a: Ausfluss) -> String {
        switch a {
        case .keiner: "keiner"
        case .klebrig: "klebrig"
        case .cremig: "cremig"
        case .waessrig: "wässrig"
        case .eiweissartig: "eiweißartig"
        }
    }

    /// Schnellknopf: Periode beginnt an diesem Tag. Ändert nur, wenn noch keine Blutung steht.
    static func periodeStart(_ id: String, tage: [String: ZyklusTag]) -> ZyklusTag? {
        var t = tage[id] ?? ZyklusTag(id: id)
        guard t.blutung == nil else { return nil }
        t.blutung = .mittel
        return t
    }
}

struct ZyklusAuswahl: Identifiable {
    let id: String
}

/// Zeilenumbruch für Chips.
private struct ZyklusFluss: Layout {
    var abstand: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        zeilen(breite: proposal.width ?? 320, subviews: subviews).groesse
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = zeilen(breite: bounds.width, subviews: subviews)
        for (i, p) in r.orte.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func zeilen(breite: CGFloat, subviews: Subviews) -> (groesse: CGSize, orte: [CGPoint]) {
        var orte: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var hoehe: CGFloat = 0
        var maxX: CGFloat = 0
        for s in subviews {
            let g = s.sizeThatFits(.unspecified)
            if x > 0, x + g.width > breite {
                x = 0
                y += hoehe + abstand
                hoehe = 0
            }
            orte.append(CGPoint(x: x, y: y))
            x += g.width + abstand
            hoehe = max(hoehe, g.height)
            maxX = max(maxX, x - abstand)
        }
        return (CGSize(width: maxX, height: y + hoehe), orte)
    }
}

/// Heute: Phasen-Ring, heutige Einträge, Schnellknöpfe. Abhängigkeiten kommen als Parameter.
struct ZyklusHeuteView: View {
    let speicher: any ZyklusSpeicher
    let eintragBlatt: (String) -> AnyView
    let heute: String
    @State private var blatt: ZyklusAuswahl?
    @State private var stand = 0
    @Environment(\.colorScheme) private var schema

    init(speicher: any ZyklusSpeicher, eintragBlatt: @escaping (String) -> AnyView, heute: String = Datum.text(Date())) {
        self.speicher = speicher
        self.eintragBlatt = eintragBlatt
        self.heute = heute
    }

    var body: some View {
        ZStack {
            ZyklusHintergrund()
            ScrollView { inhalt.padding(.horizontal, 16).padding(.vertical, 12) }
        }
        .sheet(item: $blatt, onDismiss: { stand += 1 }) { a in eintragBlatt(a.id) }
    }

    var inhalt: some View {
        let _ = stand
        let logik = speicher.logik(heute: heute)
        let ring = ZyklusHeuteLogik.ringText(logik: logik, heute: heute)
        let zeilen = ZyklusHeuteLogik.eintraege(speicher.tage[heute])
        return VStack(spacing: 16) {
            Text(Datum.anzeige(heute))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(ZyklusFarbe.tinte(schema))
                .frame(maxWidth: .infinity, alignment: .leading)
            ZyklusRing(fortschritt: ring.fortschritt, phase: ring.ton, titel: ring.titel, untertitel: ring.untertitel)
            if let hinweis = logik.verspaetungHinweis {
                ZyklusKarte(akzent: ZyklusPhasenTon.luteal.farbe(schema)) {
                    Text(hinweis)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(ZyklusFarbe.tinte(schema))
                }
            }
            ZyklusKarte {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Heute bei dir")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(ZyklusFarbe.tinte(schema))
                    if zeilen.isEmpty {
                        Text("Noch nichts eingetragen. Wie geht es dir?")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                    } else {
                        ZyklusFluss {
                            ForEach(zeilen) { z in ZyklusChip(titel: z.titel, symbol: z.symbol) }
                        }
                    }
                    if let notiz = speicher.tage[heute]?.notiz, !notiz.isEmpty {
                        Text(notiz)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                    }
                }
            }
            ZyklusKnopf(titel: "Heute eintragen", symbol: "plus") { blatt = ZyklusAuswahl(id: heute) }
            if speicher.tage[heute]?.blutung == nil {
                ZyklusKnopf(titel: "Periode beginnt heute", symbol: "drop.fill", leise: true) {
                    if let t = ZyklusHeuteLogik.periodeStart(heute, tage: speicher.tage) {
                        speicher.setze(t)
                        stand += 1
                    }
                }
            }
        }
    }
}
