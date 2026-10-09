import Charts
import SwiftUI

// Rekorde, Verlauf und Diagramm pro Übung wie in Hevy (Teil 3). Alles wird aus den vorhandenen
// Einheiten gerechnet, nichts Neues gespeichert. Akku: nur beim Öffnen der Seite, kein Hintergrund.

/// Eine Einheit, in der die Übung gemacht wurde, mit ihren gezählten Sätzen.
struct UebungTag: Identifiable, Equatable, Sendable {
    var id: String
    var datum: Date
    var saetze: [PlanSatz]
}

enum RekordArt: String, CaseIterable, Identifiable, Sendable {
    case gewicht, e1rm, satzVolumen, sitzungsVolumen

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .gewicht: "Schwerstes Gewicht"
        case .e1rm: "One-Rep-Max"
        case .satzVolumen: "Bestes Satzvolumen"
        case .sitzungsVolumen: "Bestes Sitzungsvolumen"
        }
    }
}

enum RekordLogik {
    /// Alle Einheiten mit gezählten Sätzen dieser Übung, älteste zuerst. Katalog-Übungen über die
    /// Katalog-id (egal an welchem Tag), eigene über ihren Plan-Eintrag.
    static func tage(katalogId: String, planId: String? = nil, in sessions: [GymSession]) -> [UebungTag] {
        sessions.sorted { $0.start < $1.start }.compactMap { s in
            let passend = s.laeufe.filter { katalogId == PlanUebung.eigen ? $0.plan == planId : $0.uebung == katalogId }
            let saetze = passend.flatMap { $0.fertig ? $0.saetze ?? [] : [] }
            return saetze.isEmpty ? nil : UebungTag(id: s.id, datum: s.start, saetze: saetze)
        }
    }

    /// kg × Wdh; ohne Gewicht nil.
    static func volumen(_ s: PlanSatz) -> Double? {
        guard let kg = s.kg, kg > 0, s.wdh > 0 else { return nil }
        return kg * Double(s.wdh)
    }

    /// Der Wert einer Einheit für eine Rekordart; nil, wenn kein Satz ein Gewicht hat.
    static func wert(_ saetze: [PlanSatz], _ art: RekordArt) -> Double? {
        switch art {
        case .gewicht: return saetze.compactMap(\.kg).filter { $0 > 0 }.max()
        case .e1rm: return saetze.compactMap(VerlaufLogik.e1rm).max()
        case .satzVolumen: return saetze.compactMap(volumen).max()
        case .sitzungsVolumen:
            let summe = saetze.compactMap(volumen).reduce(0, +)
            return summe > 0 ? summe : nil
        }
    }

    static func rekord(_ tage: [UebungTag], _ art: RekordArt) -> Double? {
        tage.compactMap { wert($0.saetze, art) }.max()
    }

    /// Welche Rekorde `saetze` gegenüber allem davor brechen. Das erste Mal ist kein Rekord.
    static func neue(_ saetze: [PlanSatz], gegen frueher: [UebungTag], arten: [RekordArt] = RekordArt.allCases) -> [RekordArt] {
        arten.filter { art in
            guard let neu = wert(saetze, art), let alt = rekord(frueher, art) else { return false }
            return neu > alt
        }
    }

    /// In wie vielen Übungen dieses Training einen Rekord gebrochen hat (für die Mitteilung beim Beenden).
    static func anzahl(_ liste: [WorkoutUebung], frueher: [GymSession]) -> Int {
        liste.filter { u in
            let saetze = u.saetze.filter(\.zaehlt)
            guard !saetze.isEmpty else { return false }
            return !neue(saetze, gegen: tage(katalogId: u.planUebung.uebung, planId: u.id, in: frueher)).isEmpty
        }.count
    }

    /// "80 kg", "1.250 kg", ohne Wert "–".
    static func text(_ wert: Double?) -> String {
        wert.map { "\(TrainingLogik.kgText($0)) kg" } ?? "–"
    }
}

/// Eine Übung im Detail: oben die Animation, darunter drei Reiter wie in Hevy. Zusammenfassung
/// (Diagramm und persönliche Rekorde), Historie (jede Einheit mit ihren Sätzen), So geht's (Muskeln
/// und Gerät).
struct UebungDetail: View {
    let uebung: Uebung
    var hinzufuegen: (() -> Void)? = nil

    @State private var reiter = 0
    @State private var art = RekordArt.gewicht

    var body: some View {
        let tage = RekordLogik.tage(katalogId: uebung.id, in: TrainingModell.shared.sessions(Raum.shared.ich ?? .ahmed))
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                UebungGif(id: uebung.id)
                    .aspectRatio(1.4, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 20, style: .continuous))
                    .accessibilityLabel("Animation: \(uebung.name)")
                VStack(alignment: .leading, spacing: 4) {
                    Text(uebung.name).font(.title2.bold())
                    Text("Primär: \(uebung.muskel)").font(.subheadline).foregroundStyle(.secondary)
                }
                Picker("Ansicht", selection: $reiter) {
                    Text("Übersicht").tag(0)
                    Text("Historie").tag(1)
                    Text("So geht's").tag(2)
                }
                .pickerStyle(.segmented)
                switch reiter {
                case 0: zusammenfassung(tage)
                case 1: historie(tage)
                default: soGehts
                }
                if let hinzufuegen {
                    Button(action: hinzufuegen) {
                        Label("Hinzufügen", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .navigationTitle(uebung.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Zusammenfassung

    private struct Punkt: Identifiable {
        var id: String
        var datum: Date
        var wert: Double
    }

    @ViewBuilder
    private func zusammenfassung(_ tage: [UebungTag]) -> some View {
        let punkte = tage.compactMap { t in RekordLogik.wert(t.saetze, art).map { Punkt(id: t.id, datum: t.datum, wert: $0) } }
        Picker("Wert im Diagramm", selection: $art) {
            ForEach(RekordArt.allCases) { a in Text(a.titel).tag(a) }
        }
        .pickerStyle(.menu)
        if punkte.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar").font(.largeTitle).foregroundStyle(.secondary)
                Text("Noch keine Daten. Mach die Übung einmal mit Gewicht, dann steht sie hier.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .padding(.horizontal, 16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
        } else {
            Chart(punkte) { p in
                LineMark(x: .value("Datum", p.datum), y: .value("kg", p.wert))
                PointMark(x: .value("Datum", p.datum), y: .value("kg", p.wert))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 180)
            .accessibilityLabel("\(art.titel) über die Zeit")
        }
        Label("Persönliche Rekorde", systemImage: "medal.fill")
            .font(.headline)
            .padding(.top, 4)
        VStack(spacing: 0) {
            ForEach(RekordArt.allCases) { a in
                LabeledContent(a.titel, value: RekordLogik.text(RekordLogik.rekord(tage, a)))
                    .padding(.vertical, 12)
                if a != RekordArt.allCases.last { Divider() }
            }
        }
        .padding(.horizontal, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
    }

    // MARK: Historie

    @ViewBuilder
    private func historie(_ tage: [UebungTag]) -> some View {
        if tage.isEmpty {
            Text("Noch nie gemacht.").font(.subheadline).foregroundStyle(.secondary)
        }
        ForEach(tage.reversed()) { t in
            VStack(alignment: .leading, spacing: 6) {
                Text(Datum.anzeige(Datum.text(t.datum))).font(.headline)
                ForEach(t.saetze.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        Text(WorkoutLogik.nummer(t.saetze, i))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .leading)
                        Text(WorkoutLogik.satzText(t.saetze[i])).monospacedDigit()
                        Spacer(minLength: 8)
                        if let rpe = t.saetze[i].rpe {
                            Text("RPE \(TrainingLogik.kgText(rpe))").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: So geht's

    private var soGehts: some View {
        VStack(spacing: 0) {
            LabeledContent("Zielmuskel", value: uebung.muskel).padding(.vertical, 12)
            Divider()
            LabeledContent("Gerät", value: uebung.geraet).padding(.vertical, 12)
            if !uebung.neben.isEmpty {
                Divider()
                LabeledContent("Hilft mit", value: uebung.neben.joined(separator: ", ")).padding(.vertical, 12)
            }
            Divider()
            LabeledContent("Englisch", value: uebung.en.capitalized).padding(.vertical, 12)
        }
        .padding(.horizontal, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
    }
}
