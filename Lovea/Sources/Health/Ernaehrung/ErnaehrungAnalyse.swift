import Charts
import SwiftUI

/// Analyse (Teil 5): 7 oder 30 Tage, kcal je Tag gegen das Ziel, Schnittwerte, Tage im Ziel, Top 5.
struct ErnaehrungAnalyseView: View {
    @State private var zeitraum = 7

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var ich: Person { modell.ich }
    private var heute: String { Datum.text(Date()) }
    private var farbe: Color { TagesForm.protein.farbe }

    private var tage: [String] { Array((0..<zeitraum).map { Datum.addTage(heute, -$0) }.reversed()) }
    private var ziel: Int { modell.ziele(ich).kcal }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                zeitraumWahl
                kcalKarte
                schnittKarte
                topLebensmittelKarte
            }
            .padding(16)
        }
        .navigationTitle("Analyse")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var zeitraumWahl: some View {
        Picker("Zeitraum", selection: $zeitraum) {
            Text("7 Tage").tag(7)
            Text("30 Tage").tag(30)
        }
        .pickerStyle(.segmented)
    }

    private func kcalTag(_ tag: String) -> Double { ErnaehrungLogik.summe(modell.eintraege(ich, tag)).kcal }

    // MARK: kcal-Diagramm

    private var kcalKarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kalorien je Tag").font(.headline)
            Chart {
                ForEach(tage, id: \.self) { tag in balken(tag) }
                zielLinie
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    private func balken(_ tag: String) -> some ChartContent {
        BarMark(x: .value("Tag", Datum.datum(tag), unit: .day), y: .value("kcal", kcalTag(tag)))
            .foregroundStyle(farbe)
            .cornerRadius(4)
    }

    private var zielLinie: some ChartContent {
        RuleMark(y: .value("Ziel", ziel))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundStyle(.secondary)
    }

    // MARK: Schnitt

    private var tageMitEintraegen: [String] { tage.filter { !modell.eintraege(ich, $0).isEmpty } }

    private var schnittKarte: some View {
        let mitEintraegen = tageMitEintraegen
        let anzahl = max(mitEintraegen.count, 1)
        let summen = mitEintraegen.map { ErnaehrungLogik.summe(modell.eintraege(ich, $0)) }
        let kcalSchnitt = summen.reduce(0.0) { $0 + $1.kcal } / Double(anzahl)
        let proteinSchnitt = summen.reduce(0.0) { $0 + $1.protein } / Double(anzahl)
        let kohlenhydrateSchnitt = summen.reduce(0.0) { $0 + $1.kohlenhydrate } / Double(anzahl)
        let fettSchnitt = summen.reduce(0.0) { $0 + $1.fett } / Double(anzahl)
        let imZiel = mitEintraegen.filter { abs(kcalTag($0) - Double(ziel)) <= Double(ziel) * 0.1 }.count
        return VStack(alignment: .leading, spacing: 4) {
            Text("Im Schnitt").font(.headline)
            LabeledContent("Kalorien", value: "\(Int(kcalSchnitt.rounded())) kcal")
            LabeledContent("Protein", value: "\(Int(proteinSchnitt.rounded())) g")
            LabeledContent("Kohlenhydrate", value: "\(Int(kohlenhydrateSchnitt.rounded())) g")
            LabeledContent("Fett", value: "\(Int(fettSchnitt.rounded())) g")
            LabeledContent("Tage im Ziel", value: "\(imZiel) von \(mitEintraegen.count)")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    // MARK: Top 5

    private var topLebensmittel: [(name: String, kcal: Double)] {
        var summeJe: [String: (name: String, kcal: Double)] = [:]
        for e in tage.flatMap({ modell.eintraege(ich, $0) }) {
            let bisher = summeJe[e.lebensmittel.id]?.kcal ?? 0
            summeJe[e.lebensmittel.id] = (name: e.lebensmittel.anzeigeName, kcal: bisher + e.naehrwerte.kcal)
        }
        return Array(summeJe.values.sorted { $0.kcal > $1.kcal }.prefix(5))
    }

    private var topLebensmittelKarte: some View {
        let top = topLebensmittel
        return VStack(alignment: .leading, spacing: 4) {
            Text("Meiste Kalorien").font(.headline)
            if top.isEmpty {
                Text("Noch nichts eingetragen").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(top.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.name).font(.subheadline)
                            Spacer(minLength: 8)
                            Text("\(Int(item.kcal.rounded())) kcal").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }
}
