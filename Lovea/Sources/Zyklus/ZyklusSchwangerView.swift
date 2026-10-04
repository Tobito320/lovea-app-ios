import SwiftUI

/// Schwangerschaft: Woche aus Periodenstart oder Termin, Größenvergleich, Termin, Symptome von heute.
/// `termin` ist ein vom Arzt genannter Termin; ohne ihn rechnet die Ansicht 280 Tage ab der letzten Periode.
struct ZyklusSchwangerView: View {
    let speicher: any ZyklusSpeicher
    var termin: String?
    var heute: String = Datum.text(Date())
    var scrollt = true

    @Environment(\.colorScheme) private var schema

    private static let symptome: [(Symptom, String)] = [
        (.uebelkeit, "Übelkeit"), (.muedigkeit, "Müdigkeit"), (.rueckenschmerzen, "Rücken"),
        (.heisshunger, "Heißhunger"), (.schwindel, "Schwindel"), (.kopfschmerzen, "Kopf"),
        (.brustspannen, "Brust"), (.verstopfung, "Verdauung")
    ]

    private var stand: ZyklusModiLogik.SchwangerStand? {
        let start = termin.map { Datum.addTage($0, -ZyklusModiLogik.schwangerschaftsTage) }
            ?? speicher.logik(heute: heute).letzterPeriodenStart
        guard let start else { return nil }
        return ZyklusModiLogik.schwangerStand(start: start, termin: termin, heute: heute)
    }

    var body: some View {
        ZStack {
            ZyklusHintergrund()
            if scrollt { ScrollView { inhalt } } else { inhalt }
        }
    }

    private var inhalt: some View {
        VStack(spacing: 16) {
            if let stand {
                ZyklusRing(fortschritt: Double(stand.woche * 7 + stand.tag) / Double(ZyklusModiLogik.schwangerschaftsTage),
                           phase: .luteal,
                           titel: ZyklusModiLogik.wochenText(stand),
                           untertitel: "\(stand.trimester). Trimester")
                if let vergleich = ZyklusModiLogik.groessenVergleich(woche: stand.woche) {
                    ZyklusKarte(akzent: ZyklusFarbe.pfirsich.farbe(schema)) {
                        kopf("So groß wie \(vergleich)", symbol: "leaf.fill")
                        leise("Dein Baby wächst jeden Tag ein Stück.")
                    }
                }
                ZyklusKarte {
                    kopf("Termin: \(Datum.anzeige(stand.termin))", symbol: "calendar")
                    leise(terminText(stand.tageBisTermin))
                }
            } else {
                ZyklusKarte {
                    kopf("Noch ohne Datum", symbol: "calendar")
                    leise("Trag deinen ersten Periodentag ein oder nenne den Termin, dann zähle ich die Wochen.")
                }
            }
            ZyklusKarte {
                kopf("Wie geht es dir heute?", symbol: "heart.fill")
                ZyklusModiChips(eintraege: Self.symptome.map { $0.1 }, gewaehlt: gewaehlt) { i in umschalten(Self.symptome[i].0) }
            }
        }
        .padding(16)
    }

    private func terminText(_ tage: Int) -> String {
        switch tage {
        case ..<0: "Der Termin ist \(-tage) Tage her."
        case 0: "Heute ist der Termin."
        case 1: "Noch 1 Tag."
        default: "Noch \(tage) Tage."
        }
    }

    private func gewaehlt(_ i: Int) -> Bool {
        speicher.tage[heute]?.symptome.contains(Self.symptome[i].0) == true
    }

    private func umschalten(_ s: Symptom) {
        var tag = speicher.tage[heute] ?? ZyklusTag(id: heute)
        if tag.symptome.contains(s) { tag.symptome.remove(s) } else { tag.symptome.insert(s) }
        speicher.setze(tag)
    }

    private func kopf(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(ZyklusFarbe.tinte(schema))
    }

    private func leise(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
    }
}

/// Chips in Reihen zu je zwei; kein Lazy-Container, damit der Render-Test sie zeichnet.
struct ZyklusModiChips: View {
    let eintraege: [String]
    var gewaehlt: (Int) -> Bool
    var tippen: (Int) -> Void

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(stride(from: 0, to: eintraege.count, by: 2)), id: \.self) { start in
                GridRow {
                    ForEach(start..<min(start + 2, eintraege.count), id: \.self) { i in
                        Button { tippen(i) } label: { ZyklusChip(titel: eintraege[i], gewaehlt: gewaehlt(i)) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
