import SwiftUI

/// Smart Food Rating wie YAZIO Pro: kurze Schilder aus festen, amtlichen Grenzwerten, kein Urteil "gut/schlecht".
/// - Positiv nach EU-Verordnung 1924/2006 (Nährwert- und gesundheitsbezogene Angaben): Eiweiß (≥ 12 % bzw.
///   ≥ 20 % der Energie), Ballaststoffe (≥ 3 bzw. ≥ 6 g pro 100 g oder ≥ 1,5 bzw. 3 g pro 100 kcal), zuckerarm
///   (≤ 5 g, Getränke ≤ 2,5 g), zuckerfrei (≤ 0,5 g), fettarm (≤ 3 g, Getränke ≤ 1,5 g), salzarm (≤ 0,3 g Salz),
///   energiearm (≤ 40 kcal, Getränke ≤ 20 kcal), Vitamine/Mineralstoffe "reich an" ab 30 % der Referenz
///   pro 100 g (Getränke 15 % pro 100 ml, doppelte "Quelle"-Schwelle).
/// - Hinweise nach der britischen Lebensmittelampel (FSA, "hoch" pro 100 g, Getränke halbiert): Zucker > 22,5 g,
///   Fett > 17,5 g, gesättigte Fettsäuren > 5 g, Salz > 1,5 g.
struct FoodSchild: Hashable, Identifiable {
    let text: String
    let positiv: Bool
    var id: String { text }
}

enum FoodRating {
    static func schilder(_ l: Lebensmittel) -> [FoodSchild] {
        let n = l.pro100
        let getraenk = l.fluessig
        var gut: [FoodSchild] = []
        var hinweis: [FoodSchild] = []

        if n.kcal > 0 {
            let eiweissAnteil = n.protein * 4 / n.kcal
            if eiweissAnteil >= 0.20 { gut.append(FoodSchild(text: "Viel Eiweiß", positiv: true)) }
            else if eiweissAnteil >= 0.12 { gut.append(FoodSchild(text: "Eiweißquelle", positiv: true)) }
        }
        if let b = n.ballaststoffe {
            let pro100kcal = n.kcal > 0 ? b / n.kcal * 100 : 0
            if b >= 6 || pro100kcal >= 3 { gut.append(FoodSchild(text: "Ballaststoffreich", positiv: true)) }
            else if b >= 3 || pro100kcal >= 1.5 { gut.append(FoodSchild(text: "Ballaststoffquelle", positiv: true)) }
        }
        if let z = n.zucker {
            if z <= 0.5 { gut.append(FoodSchild(text: "Zuckerfrei", positiv: true)) }
            else if z <= (getraenk ? 2.5 : 5) { gut.append(FoodSchild(text: "Zuckerarm", positiv: true)) }
            else if z > (getraenk ? 11.25 : 22.5) { hinweis.append(FoodSchild(text: "Stark zuckerhaltig", positiv: false)) }
        }
        if n.fett <= (getraenk ? 1.5 : 3) && n.kcal > 0 { gut.append(FoodSchild(text: "Fettarm", positiv: true)) }
        else if n.fett > (getraenk ? 8.75 : 17.5) { hinweis.append(FoodSchild(text: "Viel Fett", positiv: false)) }
        if let g = n.gesFett, g > (getraenk ? 2.5 : 5) { hinweis.append(FoodSchild(text: "Viele gesättigte Fettsäuren", positiv: false)) }
        if let s = n.salz {
            if s <= 0.3 { gut.append(FoodSchild(text: "Salzarm", positiv: true)) }
            else if s > (getraenk ? 0.75 : 1.5) { hinweis.append(FoodSchild(text: "Viel Salz", positiv: false)) }
        }
        if n.kcal > 0 && n.kcal <= (getraenk ? 20 : 40) { gut.append(FoodSchild(text: "Energiearm", positiv: true)) }

        // Bis zu drei Vitamine/Mineralstoffe mit dem höchsten Anteil an der Referenz.
        let schwelle = getraenk ? 0.15 : 0.30
        let reich = Mikro.allCases.compactMap { m -> (Mikro, Double)? in
            guard let r = m.referenz, r > 0, let w = n.wert(m) else { return nil }
            let anteil = w / r
            return anteil >= schwelle ? (m, anteil) : nil
        }
        .sorted { $0.1 > $1.1 }
        .prefix(3)
        for (m, _) in reich { gut.append(FoodSchild(text: "Reich an \(kurzName(m))", positiv: true)) }

        return hinweis + gut
    }

    /// "Vitamin B1 (Thiamin)" -> "Vitamin B1".
    static func kurzName(_ m: Mikro) -> String {
        guard let klammer = m.name.firstIndex(of: "(") else { return m.name }
        return m.name[..<klammer].trimmingCharacters(in: .whitespaces)
    }
}

/// Die Schilder als umbrechende Reihe: Hinweise orange, Positives im Food-Mint.
struct FoodSchilder: View {
    let schilder: [FoodSchild]

    var body: some View {
        FlussLayout(abstand: 6) {
            ForEach(schilder) { s in
                Label(s.text, systemImage: s.positiv ? "plus.circle.fill" : "minus.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(s.positiv ? Color.primary : Color.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((s.positiv ? ErnaehrungStil.akzent : Color.orange).opacity(0.18), in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Einfaches Umbruch-Layout: Kinder nebeneinander, bei Platzmangel in die nächste Zeile.
struct FlussLayout: Layout {
    var abstand: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let breite = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, zeile: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let g = s.sizeThatFits(.unspecified)
            if x > 0 && x + g.width > breite {
                y += zeile + abstand
                x = 0
                zeile = 0
            }
            x += g.width + abstand
            zeile = max(zeile, g.height)
            maxX = max(maxX, x - abstand)
        }
        return CGSize(width: min(maxX, breite), height: y + zeile)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, zeile: CGFloat = 0
        for s in subviews {
            let g = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + g.width > bounds.maxX {
                y += zeile + abstand
                x = bounds.minX
                zeile = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(g))
            x += g.width + abstand
            zeile = max(zeile, g.height)
        }
    }
}
