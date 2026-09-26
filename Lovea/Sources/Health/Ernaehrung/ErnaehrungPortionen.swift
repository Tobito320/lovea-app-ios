import SwiftUI

// Mengen-Auswahl der Produktseite (`LebensmittelDetailView`): eine Portion oder Gramm/Milliliter,
// dazu das Rad-Blatt zum Einstellen und das Portionsbeispiele-Blatt (Ahmed, 27.09., YAZIO-Kopie).

/// Eine wählbare Menge: eine bestimmte Portion, oder Gramm/Milliliter direkt.
enum MengenOption: Hashable {
    case portion(LebensmittelPortion)
    case gramm
    case milliliter

    var einheit: Einheit {
        switch self {
        case .portion: .portion
        case .gramm: .g
        case .milliliter: .ml
        }
    }

    /// Portionen zuerst, danach Gramm/Milliliter, die Basis-Einheit des Lebensmittels vor der anderen.
    static func optionen(_ l: Lebensmittel) -> [MengenOption] {
        var liste: [MengenOption] = ErnaehrungLogik.portionsAuswahl(l).map { .portion($0) }
        liste += l.fluessig ? [.milliliter, .gramm] : [.gramm, .milliliter]
        return liste
    }

    /// Passende Option zu einer gespeicherten Menge (Eintrag oder "letzte Menge"). `.packung` läuft
    /// über die gleichnamige Portion aus `portionsAuswahl`.
    static func auswahl(einheit: Einheit, portionName: String?, l: Lebensmittel) -> MengenOption {
        switch einheit {
        case .g: return .gramm
        case .ml: return .milliliter
        case .portion:
            if let name = portionName, let p = ErnaehrungLogik.portionsAuswahl(l).first(where: { $0.name == name }) {
                return .portion(p)
            }
            return .portion(LebensmittelPortion(name: portionName ?? "Portion", gramm: l.portionMenge ?? 100))
        case .packung:
            if let p = ErnaehrungLogik.portionsAuswahl(l).first(where: { $0.name == "Packung" }) { return .portion(p) }
            return .gramm
        }
    }

    /// "ganze, mittelgroß (120 g)", "Gramm", "Milliliter".
    func anzeige(_ l: Lebensmittel) -> String {
        switch self {
        case .portion(let p): "\(p.name) (\(ErnaehrungLogik.zahl(p.gramm)) \(l.basisEinheit.rawValue))"
        case .gramm: "Gramm"
        case .milliliter: "Milliliter"
        }
    }

    /// Zahlen im Mengen-Rad: Portionen in Vierteln bis 1, dann ganze bis 50; Gramm/Milliliter 1 bis 2000.
    var zahlStufen: [Double] {
        switch self {
        case .portion: [0.25, 0.5, 0.75] + (1...50).map(Double.init)
        case .gramm, .milliliter: (1...2000).map(Double.init)
        }
    }

    /// Gramm/Milliliter, die eine Zahl in dieser Option bedeutet.
    static func gramm(_ o: MengenOption, zahl: Double) -> Double {
        if case .portion(let p) = o { return zahl * p.gramm }
        return zahl
    }

    /// Zahl in der neuen Option, die den alten Gramm/Milliliter am nächsten kommt, auf die nächste Stufe gerundet.
    static func zahlNeu(fuer o: MengenOption, alteGramm: Double) -> Double {
        let ziel: Double
        if case .portion(let p) = o, p.gramm > 0 { ziel = alteGramm / p.gramm } else { ziel = alteGramm }
        return o.zahlStufen.min(by: { abs($0 - ziel) < abs($1 - ziel) }) ?? o.zahlStufen[0]
    }

    /// ¼, ½, ¾ als Bruch, sonst eine normale deutsche Zahl.
    static func bruchText(_ x: Double) -> String {
        switch x {
        case 0.25: "¼"
        case 0.5: "½"
        case 0.75: "¾"
        default: ErnaehrungLogik.zahl(x)
        }
    }
}

/// Zwei Räder nebeneinander: Zahl links, Einheit rechts. Wechsel der Einheit rechnet die Zahl um.
struct MengenRadBlatt: View {
    let lebensmittel: Lebensmittel
    @Binding var auswahl: MengenOption
    @Binding var zahl: Double
    @Environment(\.dismiss) private var dismiss

    private var optionen: [MengenOption] { MengenOption.optionen(lebensmittel) }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Menge", selection: $zahl) {
                    ForEach(auswahl.zahlStufen, id: \.self) { z in
                        Text(MengenOption.bruchText(z)).tag(z)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Picker("Einheit", selection: $auswahl) {
                    ForEach(optionen, id: \.self) { o in
                        Text(o.anzeige(lebensmittel)).tag(o)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Menge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .onChange(of: auswahl) { alt, neu in
                guard alt != neu else { return }
                zahl = MengenOption.zahlNeu(fuer: neu, alteGramm: MengenOption.gramm(alt, zahl: zahl))
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}

/// Richtwerte nach der Handregel des Bundeszentrums für Ernährung.
struct Portionsbeispiel: Identifiable {
    let name: String
    let gramm: Double
    let kcal: Int
    let symbol: String
    let hand: String
    var id: String { name }

    static let alle: [Portionsbeispiel] = [
        Portionsbeispiel(name: "Gemüse", gramm: 150, kcal: 45, symbol: "carrot.fill", hand: "2 Hände voll"),
        Portionsbeispiel(name: "Obst", gramm: 125, kcal: 65, symbol: "leaf.fill", hand: "1 Hand voll"),
        Portionsbeispiel(name: "Kartoffeln", gramm: 200, kcal: 150, symbol: "circle.grid.2x2.fill", hand: "2 Fäuste"),
        Portionsbeispiel(name: "Nudeln, gekocht", gramm: 180, kcal: 270, symbol: "fork.knife", hand: "2 Hände voll"),
        Portionsbeispiel(name: "Reis, gekocht", gramm: 150, kcal: 195, symbol: "takeoutbag.and.cup.and.straw.fill", hand: "2 Hände voll"),
        Portionsbeispiel(name: "Brot", gramm: 50, kcal: 120, symbol: "square.fill", hand: "1 Scheibe, Handfläche"),
        Portionsbeispiel(name: "Fleisch und Fisch", gramm: 120, kcal: 180, symbol: "fish.fill", hand: "1 Handfläche"),
        Portionsbeispiel(name: "Käse", gramm: 30, kcal: 110, symbol: "triangle.fill", hand: "2 Finger"),
        Portionsbeispiel(name: "Nüsse", gramm: 25, kcal: 160, symbol: "circle.hexagongrid.fill", hand: "1 Handmulde"),
        Portionsbeispiel(name: "Öl und Butter", gramm: 10, kcal: 90, symbol: "drop.fill", hand: "1 Daumenspitze"),
    ]
}

/// Von unten: Richtwerte, wie groß eine Portion ungefähr ist.
struct PortionsbeispieleBlatt: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Eine Portion ist ungefähr so groß wie deine Hand. Richtwerte.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    VStack(spacing: 0) {
                        ForEach(Portionsbeispiel.alle) { p in
                            zeile(p)
                            if p.id != Portionsbeispiel.alle.last?.id { Divider().padding(.leading, 68) }
                        }
                    }
                }
            }
            .navigationTitle("Portionsbeispiele")
            .navigationBarTitleDisplayMode(.inline)
            .fontDesign(.rounded)
        }
        .presentationDetents([.fraction(0.4), .large])
        .presentationDragIndicator(.visible)
    }

    private func zeile(_ p: Portionsbeispiel) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(uiColor: .tertiarySystemFill))
                Image(systemName: p.symbol).foregroundStyle(.secondary)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(.subheadline.weight(.semibold))
                Text("1 Portion = \(ErnaehrungLogik.zahl(p.gramm)) g").font(.caption).foregroundStyle(.secondary)
                Text("≈ \(p.kcal) kcal").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "hand.raised.fill").foregroundStyle(.secondary)
                Text(p.hand).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(width: 64)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
