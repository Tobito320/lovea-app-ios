import SwiftUI

// Health-Coach: Vorschläge als Chips (leerer Chat und Leiste über der Eingabe) und die kleine Logik dazu.

/// Reine Logik der Chat-Oberfläche. Nichts hier liest Modelle oder die Uhr.
enum CoachVorschlag {
    /// Das Symbol zu einer Schnellfrage.
    static func symbol(fuer frage: String) -> String {
        if frage == CoachLokal.wochenrueckblick { return "calendar" }
        if frage == CoachLokal.luecken { return "checklist" }
        if frage.contains("Training") { return "figure.strengthtraining.traditional" }
        if frage.contains("essen") { return "fork.knife" }
        if frage.contains("Tagesbericht") { return "doc.text.magnifyingglass" }
        return "sparkles"
    }

    /// Im leeren Chat mehr Auswahl als in der Leiste: die Fragen der Tageszeit zuerst, dann die übrigen bekannten
    /// Schnellfragen, ohne Doppelte, höchstens sechs.
    static func leerFragen(_ fragen: [String]) -> [String] {
        var alle = fragen
        for frage in CoachRegeln.schnellfragen + [CoachLokal.wochenrueckblick, CoachLokal.luecken] where !alle.contains(frage) {
            alle.append(frage)
        }
        return Array(alle.prefix(6))
    }

    /// Der Zähler erscheint erst ab vier Fünfteln der erlaubten Länge, vorher wäre er Lärm.
    static func zaehlerSichtbar(anzahl: Int, maximal: Int) -> Bool {
        anzahl * 5 >= maximal * 4
    }

    /// Die letzten 50 Zeichen färben den Zähler.
    static func zaehlerWarnt(anzahl: Int, maximal: Int) -> Bool {
        anzahl >= maximal - 50
    }
}

/// Ein Vorschlag als Glas-Kapsel. Im leeren Chat mit Symbol, in der Leiste über der Eingabe ohne.
struct CoachVorschlagChip: View {
    let frage: String
    var symbol: String?
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HabitFarbe.mint.farbe)
                        .accessibilityHidden(true)
                }
                Text(frage)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// Bricht Chips in Zeilen um und zentriert jede Zeile. Jedes Chip bekommt höchstens die volle Breite, damit eine lange
/// Frage bei großer Schrift umbricht statt über den Rand zu laufen.
struct CoachChipFluss: Layout {
    var abstand: CGFloat = 8

    private struct Reihe {
        var teile: [(index: Int, groesse: CGSize)] = []
        var breite: CGFloat = 0
        var hoehe: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Die angebotene Breite zurückgeben, nicht die der breitesten Reihe: Messen und Platzieren brechen dann gleich um.
        let breite: CGFloat = proposal.width ?? 320
        let reihen = anordnen(breite, subviews)
        let hoehen: CGFloat = reihen.reduce(0) { $0 + $1.hoehe }
        let luecken: CGFloat = abstand * CGFloat(max(reihen.count - 1, 0))
        return CGSize(width: breite, height: hoehen + luecken)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for reihe in anordnen(bounds.width, subviews) {
            var x = bounds.minX + (bounds.width - reihe.breite) / 2
            for teil in reihe.teile {
                subviews[teil.index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: teil.groesse.width, height: teil.groesse.height)
                )
                x += teil.groesse.width + abstand
            }
            y += reihe.hoehe + abstand
        }
    }

    private func anordnen(_ breite: CGFloat, _ subviews: Subviews) -> [Reihe] {
        var reihen: [Reihe] = []
        var aktuell = Reihe()
        for index in subviews.indices {
            let groesse = subviews[index].sizeThatFits(ProposedViewSize(width: breite, height: nil))
            if !aktuell.teile.isEmpty, aktuell.breite + abstand + groesse.width > breite {
                reihen.append(aktuell)
                aktuell = Reihe()
            }
            aktuell.breite += (aktuell.teile.isEmpty ? 0 : abstand) + groesse.width
            aktuell.hoehe = max(aktuell.hoehe, groesse.height)
            aktuell.teile.append((index: index, groesse: groesse))
        }
        if !aktuell.teile.isEmpty { reihen.append(aktuell) }
        return reihen
    }
}
