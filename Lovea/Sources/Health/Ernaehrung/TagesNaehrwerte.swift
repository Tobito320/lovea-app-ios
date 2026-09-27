import Charts
import SwiftUI

/// Alle Nährwerte eines Tages: Kalorien, Makros, Ballaststoffe/Zucker/Salz/gesättigte Fettsäuren,
/// dann Vitamine, Mineralstoffe und Weitere mit Menge und % der EU-Referenz, dazu die Kalorien je
/// Mahlzeit. Reine Summe aller Einträge des Tages, kein Ziel-Vergleich (der lebt im Tagebuch).
struct TagesNaehrwerteView: View {
    let tag: String
    let person: Person

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var farbe: Color { ErnaehrungStil.akzent }
    private var eintraege: [EssenEintrag] { modell.eintraege(person, tag) }
    private var summe: Naehrwerte { ErnaehrungLogik.summe(eintraege) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kalorienUndMakroKarte
                grundNaehrstoffeKarte
                mikroKarte("Vitamine", .vitamine)
                mikroKarte("Mineralstoffe", .mineralstoffe)
                mikroKarte("Weitere", .weitere)
                mahlzeitKarte
            }
            .padding(16)
        }
        .fontDesign(.rounded)
        .navigationTitle(Datum.anzeige(tag))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Kalorien und Makros

    private var kalorienUndMakroKarte: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kalorien").font(.headline)
            Text("\(Int(summe.kcal.rounded())) kcal").font(.title.weight(.heavy)).monospacedDigit()
            Divider()
            makroZeile("Kohlenhydrate", summe.kohlenhydrate)
            makroZeile("Eiweiß", summe.protein)
            makroZeile("Fett", summe.fett)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    private func makroZeile(_ name: String, _ gramm: Double) -> some View {
        HStack {
            Text(name).font(.subheadline)
            Spacer(minLength: 8)
            Text("\(Int(gramm.rounded())) g").font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Grund-Nährstoffe

    private var grundNaehrstoffeKarte: some View {
        let felder: [(name: String, wert: Double?)] = [
            ("Ballaststoffe", summe.ballaststoffe), ("Zucker", summe.zucker),
            ("Salz", summe.salz), ("Gesättigte Fettsäuren", summe.gesFett),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            Text("Weitere Nährwerte").font(.headline)
            if felder.allSatisfy({ $0.wert == nil }) {
                Text("Keine Angaben für diesen Tag.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(felder, id: \.name) { feld in
                    if let wert = feld.wert {
                        naehrstoffZeile(NaehrstoffZeile(id: feld.name, name: feld.name, menge: "\(ErnaehrungLogik.zahl(wert)) g", prozent: nil))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    // MARK: Mikronährstoffe

    private func mikroZeilen(_ gruppe: Mikro.Gruppe) -> [NaehrstoffZeile] {
        Mikro.allCases.filter { $0.gruppe == gruppe }.compactMap { m in
            guard let wert = summe.wert(m) else { return nil }
            return NaehrstoffZeile(id: m.rawValue, name: m.name, menge: "\(ErnaehrungLogik.zahl(wert)) \(m.einheit)",
                                   prozent: AnalyseLogik.prozentReferenz(wert, m))
        }
    }

    @ViewBuilder private func mikroKarte(_ titel: String, _ gruppe: Mikro.Gruppe) -> some View {
        let zeilen = mikroZeilen(gruppe)
        if !zeilen.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(titel).font(.headline)
                ForEach(zeilen) { naehrstoffZeile($0) }
                if gruppe == .vitamine, ohneVitamine > 0 {
                    Text(ohneVitamine == 1 ? "1 Eintrag ohne Angaben zu Vitaminen." : "\(ohneVitamine) Einträge ohne Angaben zu Vitaminen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .healthKarte(farbe)
        }
    }

    private func naehrstoffZeile(_ zeile: NaehrstoffZeile) -> some View {
        HStack {
            Text(zeile.name).font(.subheadline)
            Spacer(minLength: 8)
            Text(zeile.menge).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            if let prozent = zeile.prozent {
                Text("\(Int(prozent.rounded())) %").font(.subheadline.weight(.semibold)).monospacedDigit().frame(width: 46, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Einträge ohne jede Angabe zu einem Vitamin (weder ein Wert noch 0).
    private var ohneVitamine: Int {
        let vitamine = Mikro.allCases.filter { $0.gruppe == .vitamine }
        return eintraege.filter { e in !vitamine.contains { e.naehrwerte.wert($0) != nil } }.count
    }

    // MARK: Mahlzeiten

    private func kcal(_ m: Mahlzeit) -> Double { ErnaehrungLogik.summe(eintraege.filter { $0.mahlzeit == m }).kcal }

    private var mahlzeitKarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kalorien je Mahlzeit").font(.headline)
            Chart {
                ForEach(Mahlzeit.allCases) { m in
                    BarMark(x: .value("kcal", kcal(m)), y: .value("Mahlzeit", m.name))
                        .foregroundStyle(farbe)
                        .cornerRadius(4)
                }
            }
            .chartXAxis { AxisMarks(position: .bottom) }
            .frame(height: 140)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }
}
