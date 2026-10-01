import SwiftUI

// Mengen-Auswahl der Produktseite (`LebensmittelDetailView`): eine Portion oder Gramm/Milliliter,
// dazu die Mengen-Leiste zum Einstellen und das Portionsbeispiele-Blatt (Ahmed, 27.09./01.10., YAZIO-Kopie).

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
}

/// Drei Spalten wie YAZIO: Ganzzahl, Bruch, Einheit. Das Feld darüber nimmt jede Zahl, das Rad klemmt am Rand.
enum MengenRad {
    static let maxGanz = 2000
    static let brueche: [(text: String, wert: Double)] = [
        ("–", 0), ("⅛", 0.125), ("¼", 0.25), ("⅓", 1.0 / 3), ("½", 0.5), ("⅔", 2.0 / 3), ("¾", 0.75), ("⅞", 0.875),
    ]

    static func zahl(ganz: Int, bruch: Int) -> Double { Double(ganz) + brueche[min(max(bruch, 0), brueche.count - 1)].wert }

    static func zerlegen(_ zahl: Double) -> (ganz: Int, bruch: Int) {
        let z = max(0, zahl)
        let ganz = min(Int(z.rounded(.down)), maxGanz)
        let rest = ganz == maxGanz ? 0 : z - Double(ganz)
        let bruch = brueche.indices.min { abs(brueche[$0].wert - rest) < abs(brueche[$1].wert - rest) } ?? 0
        return (ganz, bruch)
    }

    /// Bis 3 Nachkommastellen, deutsches Komma, ohne Nullen am Ende: 721,875 / 500 / 0,5.
    static func feldText(_ zahl: Double) -> String {
        var t = String(format: "%.3f", zahl)
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t.replacingOccurrences(of: ".", with: ",")
    }
}

/// Feste Leiste unten auf `LebensmittelDetailView`: Zahlenfeld + Einheit oben, Speichern-Knopf, darunter
/// das Dreier-Rad (Ahmed, 01.10., YAZIO 1:1). Tippt jemand ins Feld, verschwindet das Rad für die Tastatur.
struct MengenLeiste: View {
    let lebensmittel: Lebensmittel
    @Binding var auswahl: MengenOption
    @Binding var zahl: Double
    let knopf: String
    let aktion: () -> Void

    @State private var feld = ""
    @State private var ganz = 1
    @State private var bruch = 0
    @FocusState private var tippt: Bool

    private var optionen: [MengenOption] { MengenOption.optionen(lebensmittel) }

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(.secondary.opacity(0.5)).frame(width: 40, height: 5).padding(.top, 8)
            HStack(spacing: 2) {
                TextField("0", text: $feld)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($tippt)
                    .font(.title3)
                    .frame(width: 70)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(uiColor: .tertiarySystemFill), in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22))
                HStack {
                    Text(auswahl.anzeige(lebensmittel))
                        .font(.body)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color(uiColor: .tertiarySystemFill), in: UnevenRoundedRectangle(bottomTrailingRadius: 22, topTrailingRadius: 22))
                .allowsHitTesting(false)
            }
            Button(action: aktion) {
                Text(knopf).font(.title3.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(zahl <= 0)
            if !tippt {
                HStack(spacing: 0) {
                    Picker("Ganz", selection: $ganz) { ForEach(0...MengenRad.maxGanz, id: \.self) { Text("\($0)").tag($0) } }
                        .frame(width: 80)
                    Picker("Bruch", selection: $bruch) { ForEach(MengenRad.brueche.indices, id: \.self) { Text(MengenRad.brueche[$0].text).tag($0) } }
                        .frame(width: 60)
                    Picker("Einheit", selection: $auswahl) { ForEach(optionen, id: \.self) { Text($0.anzeige(lebensmittel)).tag($0) } }
                        .frame(maxWidth: .infinity)
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 200)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
        .background(Color(uiColor: .secondarySystemBackground), in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
        .onAppear { vonZahl() }
        .onChange(of: feld) { _, neu in if tippt, let z = ErnaehrungLogik.eingabe(neu) { zahl = z } else if tippt { zahl = 0 } }
        .onChange(of: tippt) { _, an in if !an { vonZahl() } }
        .onChange(of: ganz) { _, _ in if !tippt { zahl = MengenRad.zahl(ganz: ganz, bruch: bruch); feld = MengenRad.feldText(zahl) } }
        .onChange(of: bruch) { _, _ in if !tippt { zahl = MengenRad.zahl(ganz: ganz, bruch: bruch); feld = MengenRad.feldText(zahl) } }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { tippt = false } } }
    }

    private func vonZahl() {
        feld = MengenRad.feldText(zahl)
        let z = MengenRad.zerlegen(zahl)
        ganz = z.ganz
        bruch = z.bruch
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
