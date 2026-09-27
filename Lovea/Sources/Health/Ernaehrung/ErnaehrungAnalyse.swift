import Charts
import SwiftUI

// Analyse wie YAZIO Pro (Ahmed, 27.09.): Zeitraum von einer Woche bis zu 2 Jahren, bei langen
// Zeiträumen Werte je Woche bzw. Monat gemittelt statt Tag für Tag. Kalorien, Makros, Nährstoffe
// (inkl. Mikronährstoffe als % der EU-Referenz), Gewicht, Körperwerte, Top-Lebensmittel, Serie.

// MARK: - Zeitraum

enum AnalyseZeitraum: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case woche = 7, monat = 30, dreiMonate = 90, jahr = 365, zweiJahre = 730

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .woche: "Woche"
        case .monat: "Monat"
        case .dreiMonate: "3 Monate"
        case .jahr: "Jahr"
        case .zweiJahre: "2 Jahre"
        }
    }

    /// Je länger der Zeitraum, desto gröber die Balken: Tag, Woche oder Monat.
    var gruppierung: AnalyseGruppierung {
        switch self {
        case .woche, .monat: .tag
        case .dreiMonate: .woche
        case .jahr, .zweiJahre: .monat
        }
    }
}

enum AnalyseGruppierung: Sendable { case tag, woche, monat }

/// Ein Abschnitt im Diagramm (ein Tag, eine Woche oder ein Monat) mit den Tagen, die hineinfallen.
/// `start` ist der Schlüssel: der Tag selbst, der Montag der Woche oder "yyyy-MM".
struct AnalyseBucket: Identifiable, Sendable, Equatable {
    var start: String
    var tage: [String]
    var id: String { start }
}

// MARK: - Reine Logik

/// Bucket-Bildung, Schnitt nur über Tage mit Einträgen, Serie, Prozent der EU-Referenz. Ohne Modell,
/// ohne Singletons, komplett testbar.
enum AnalyseLogik {
    /// `anzahl` Tage bis einschließlich `bis`, älteste zuerst.
    static func tage(bis: String, anzahl: Int) -> [String] {
        Array((0..<anzahl).map { Datum.addTage(bis, -$0) }.reversed())
    }

    /// Fasst `tage` zu Buckets zusammen: 1:1 pro Tag, ab Montag der Woche oder ab dem 1. des Monats.
    static func buckets(_ tage: [String], gruppierung: AnalyseGruppierung) -> [AnalyseBucket] {
        switch gruppierung {
        case .tag:
            return tage.map { AnalyseBucket(start: $0, tage: [$0]) }
        case .woche:
            return gruppiert(tage) { Datum.montagDerWoche($0) }
        case .monat:
            return gruppiert(tage) { String($0.prefix(7)) }
        }
    }

    private static func gruppiert(_ tage: [String], schluessel: (String) -> String) -> [AnalyseBucket] {
        var reihenfolge: [String] = []
        var gruppen: [String: [String]] = [:]
        for tag in tage {
            let s = schluessel(tag)
            if gruppen[s] == nil { reihenfolge.append(s) }
            gruppen[s, default: []].append(tag)
        }
        return reihenfolge.map { AnalyseBucket(start: $0, tage: gruppen[$0] ?? []) }
    }

    /// Schnitt eines Buckets, nur über die Tage darin, für die `werte` einen Wert hat. nil ohne Werte.
    static func bucketSchnitt(_ bucket: AnalyseBucket, _ werte: [String: Double]) -> Double? {
        let vorhanden = bucket.tage.compactMap { werte[$0] }
        guard !vorhanden.isEmpty else { return nil }
        return vorhanden.reduce(0, +) / Double(vorhanden.count)
    }

    /// Schnitt über alle Tage mit Werten (nicht über Buckets, sonst verzerren lange Lücken).
    static func schnitt(_ werte: [String: Double]) -> Double {
        guard !werte.isEmpty else { return 0 }
        return werte.values.reduce(0, +) / Double(werte.count)
    }

    /// Wie viele der Werte höchstens `toleranz` (Anteil) neben `ziel` liegen.
    static func tageImZiel(_ werte: [Double], ziel: Double, toleranz: Double = 0.1) -> Int {
        guard ziel > 0 else { return 0 }
        return werte.filter { abs($0 - ziel) <= ziel * toleranz }.count
    }

    /// `wert` als Prozent der EU-Tagesreferenz. nil ohne Referenz für diesen Mikronährstoff.
    static func prozentReferenz(_ wert: Double, _ m: Mikro) -> Double? {
        guard let referenz = m.referenz, referenz > 0 else { return nil }
        return wert / referenz * 100
    }

    /// Tage in Folge mit mindestens einem Eintrag, endend bei `heute` (oder gestern, falls heute
    /// noch nichts eingetragen ist – die Serie reißt erst, wenn ein Tag wirklich leer bleibt).
    static func serie(_ tageMitEintraegen: Set<String>, heute: String) -> Int {
        var tag = tageMitEintraegen.contains(heute) ? heute : Datum.addTage(heute, -1)
        var anzahl = 0
        while tageMitEintraegen.contains(tag) {
            anzahl += 1
            tag = Datum.addTage(tag, -1)
        }
        return anzahl
    }

    /// Beschriftung im Diagramm je Gruppierung: "23" (Tag), "23.09." (Wochenstart), "Sep. 26" (Monat).
    static func label(_ bucket: AnalyseBucket, _ gruppierung: AnalyseGruppierung) -> String {
        switch gruppierung {
        case .tag:
            return HealthText.tagesnummer(bucket.start)
        case .woche:
            let teile = bucket.start.split(separator: "-")
            return teile.count == 3 ? "\(teile[2]).\(teile[1])." : bucket.start
        case .monat:
            let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
            return Datum.datum(bucket.start + "-01").formatted(stil.month(.abbreviated).year(.twoDigits))
        }
    }
}

/// Eine Zeile "Name, Menge, % der EU-Referenz" für Nährstoff-Listen (Analyse und Tagesblatt).
struct NaehrstoffZeile: Identifiable {
    var id: String
    var name: String
    var menge: String
    var prozent: Double?
}

// MARK: - View

struct ErnaehrungAnalyseView: View {
    @State private var zeitraum: AnalyseZeitraum = .woche

    private var modell: ErnaehrungModell { ErnaehrungModell.shared }
    private var ich: Person { modell.ich }
    private var person: Person { ich }
    private var heute: String { Datum.text(Date()) }
    private var farbe: Color { ErnaehrungStil.akzent }
    private var ziele: ErnaehrungsZiele { modell.ziele(person) }

    private var tageImZeitraum: [String] { AnalyseLogik.tage(bis: heute, anzahl: zeitraum.rawValue) }
    private var buckets: [AnalyseBucket] { AnalyseLogik.buckets(tageImZeitraum, gruppierung: zeitraum.gruppierung) }

    /// Alle Einträge des Zeitraums, einmal geholt statt in jeder Teilauswertung neu.
    private var alleEintraege: [EssenEintrag] { tageImZeitraum.flatMap { modell.eintraege(person, $0) } }
    // ponytail: eine `eintraege(p, tag)`-Anfrage pro Tag filtert jedes Mal über alle je gespeicherten
    // Einträge der Person. Bei 2 Jahren Verlauf mit sehr vielen Einträgen kann das spürbar werden –
    // dann lohnt ein Tag-Index in `ErnaehrungFaltung`.

    /// Tagessummen, nur für Tage mit mindestens einem Eintrag (so zählt der Schnitt nur diese Tage).
    private var tagesSummen: [String: Naehrwerte] {
        Dictionary(grouping: alleEintraege, by: \.datum).mapValues(ErnaehrungLogik.summe)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                zeitraumWahl
                kalorienKarte
                makroKarte
                naehrstoffeKarte
                gewichtKarte
                koerperKarten
                serieUndTopKarte
            }
            .padding(16)
        }
        .navigationTitle("Analyse")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Zeitraum

    private var zeitraumWahl: some View {
        Menu {
            Picker("Zeitraum", selection: $zeitraum) {
                ForEach(AnalyseZeitraum.allCases) { z in Text(z.name).tag(z) }
            }
        } label: {
            HStack {
                Text("Zeitraum").font(.headline)
                Spacer(minLength: 8)
                Label(zeitraum.name, systemImage: "chevron.up.chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(farbe)
            }
            .contentShape(.rect)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    // MARK: Kalorien

    private var kalorienWerte: [String: Double] { tagesSummen.mapValues(\.kcal) }

    private var kalorienKarte: some View {
        let schnitt = AnalyseLogik.schnitt(kalorienWerte)
        let imZiel = AnalyseLogik.tageImZiel(Array(kalorienWerte.values), ziel: Double(ziele.kcal))
        return VStack(alignment: .leading, spacing: 12) {
            Text("Kalorien").font(.headline)
            Chart {
                ForEach(buckets) { bucket in
                    if let wert = AnalyseLogik.bucketSchnitt(bucket, kalorienWerte) {
                        BarMark(x: .value("Zeit", AnalyseLogik.label(bucket, zeitraum.gruppierung)), y: .value("kcal", wert))
                            .foregroundStyle(farbe)
                            .cornerRadius(3)
                    }
                }
                RuleMark(y: .value("Ziel", ziele.kcal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.secondary)
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
            HStack {
                statistik("Schnitt", "\(Int(schnitt.rounded())) kcal")
                Spacer()
                statistik("Tage im Ziel", "\(imZiel) von \(kalorienWerte.count)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    private func statistik(_ titel: String, _ wert: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(wert).font(.title3.weight(.bold)).monospacedDigit()
            Text(titel).font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: Makros

    private struct MakroSchnitt { var name: String; var gramm: Double; var ziel: Int; var kcalJeGramm: Double; var farbe: Color }

    private var makroSchnitte: [MakroSchnitt] {
        [
            MakroSchnitt(name: "Kohlenhydrate", gramm: AnalyseLogik.schnitt(tagesSummen.mapValues(\.kohlenhydrate)),
                        ziel: ziele.kohlenhydrate, kcalJeGramm: 4, farbe: farbe),
            MakroSchnitt(name: "Eiweiß", gramm: AnalyseLogik.schnitt(tagesSummen.mapValues(\.protein)),
                        ziel: ziele.protein, kcalJeGramm: 4, farbe: farbe.opacity(0.65)),
            MakroSchnitt(name: "Fett", gramm: AnalyseLogik.schnitt(tagesSummen.mapValues(\.fett)),
                        ziel: ziele.fett, kcalJeGramm: 9, farbe: farbe.opacity(0.35)),
        ]
    }

    private var makroKarte: some View {
        let schnitte = makroSchnitte
        let energieGesamt = schnitte.reduce(0.0) { $0 + $1.gramm * $1.kcalJeGramm }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Makros im Schnitt").font(.headline)
            HStack(alignment: .center, spacing: 16) {
                if energieGesamt > 0 {
                    Chart(schnitte, id: \.name) { m in
                        SectorMark(angle: .value(m.name, m.gramm * m.kcalJeGramm), innerRadius: .ratio(0.62), angularInset: 1.5)
                            .foregroundStyle(m.farbe)
                            .cornerRadius(3)
                    }
                    .frame(width: 88, height: 88)
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(schnitte, id: \.name) { m in
                        makroZeile(m, anteil: energieGesamt > 0 ? m.gramm * m.kcalJeGramm / energieGesamt : 0)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    private func makroZeile(_ m: MakroSchnitt, anteil: Double) -> some View {
        HStack {
            Circle().fill(m.farbe).frame(width: 10, height: 10)
            Text(m.name).font(.subheadline)
            Spacer(minLength: 8)
            Text("\(Int(m.gramm.rounded())) / \(m.ziel) g").font(.subheadline.weight(.semibold)).monospacedDigit()
            Text("\(Int((anteil * 100).rounded())) %").font(.footnote).foregroundStyle(.secondary).frame(width: 42, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Nährstoffe

    /// Schnitt eines optionalen Feldes, nur über Tage, an denen es einen Wert hat.
    private func schnittOptional(_ zugriff: (Naehrwerte) -> Double?) -> Double? {
        var werte: [String: Double] = [:]
        for (tag, summe) in tagesSummen { if let w = zugriff(summe) { werte[tag] = w } }
        return werte.isEmpty ? nil : AnalyseLogik.schnitt(werte)
    }

    private var naehrstoffGrundZeilen: [NaehrstoffZeile] {
        let felder: [(name: String, einheit: String, zugriff: (Naehrwerte) -> Double?)] = [
            ("Ballaststoffe", "g", { $0.ballaststoffe }),
            ("Zucker", "g", { $0.zucker }),
            ("Salz", "g", { $0.salz }),
            ("Gesättigte Fettsäuren", "g", { $0.gesFett }),
        ]
        return felder.compactMap { feld in
            guard let schnitt = schnittOptional(feld.zugriff) else { return nil }
            return NaehrstoffZeile(id: feld.name, name: feld.name, menge: "\(ErnaehrungLogik.zahl(schnitt)) \(feld.einheit)", prozent: nil)
        }
    }

    private func mikroZeilen(_ gruppe: Mikro.Gruppe) -> [NaehrstoffZeile] {
        Mikro.allCases.filter { $0.gruppe == gruppe && $0.referenz != nil }.compactMap { m in
            guard let schnitt = schnittOptional({ $0.wert(m) }) else { return nil }
            return NaehrstoffZeile(id: m.rawValue, name: m.name, menge: "\(ErnaehrungLogik.zahl(schnitt)) \(m.einheit)",
                                   prozent: AnalyseLogik.prozentReferenz(schnitt, m))
        }
    }

    private var naehrstoffeKarte: some View {
        let grund = naehrstoffGrundZeilen
        let vitamine = mikroZeilen(.vitamine)
        let mineralstoffe = mikroZeilen(.mineralstoffe)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Nährstoffe im Schnitt").font(.headline)
            if grund.isEmpty && vitamine.isEmpty && mineralstoffe.isEmpty {
                Text("Noch keine Nährwertangaben in diesem Zeitraum.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) { ForEach(grund) { naehrstoffZeile($0) } }
                if !vitamine.isEmpty { abschnitt("Vitamine", vitamine) }
                if !mineralstoffe.isEmpty { abschnitt("Mineralstoffe", mineralstoffe) }
                Text("Nur Lebensmittel mit Angaben dazu zählen in den Schnitt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    private func abschnitt(_ titel: String, _ zeilen: [NaehrstoffZeile]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titel).font(.subheadline.weight(.semibold)).padding(.top, 4)
            ForEach(zeilen) { naehrstoffZeile($0) }
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

    // MARK: Gewicht

    private var gewichtsReihe: [(tag: String, zehntel: Int)] {
        guard let start = tageImZeitraum.first, let ende = tageImZeitraum.last else { return [] }
        return HealthModell.shared.habitWerte(Habit.gewicht.id, person)
            .filter { $0.value > 0 && $0.key >= start && $0.key <= ende }
            .sorted { $0.key < $1.key }
            .map { (tag: $0.key, zehntel: $0.value) }
    }

    @ViewBuilder private var gewichtKarte: some View {
        let reihe = gewichtsReihe
        if let erstes = reihe.first, let letztes = reihe.last {
            let veraenderung = letztes.zehntel - erstes.zehntel
            VStack(alignment: .leading, spacing: 12) {
                Text("Gewicht").font(.headline)
                Chart(reihe, id: \.tag) { punkt in
                    LineMark(x: .value("Tag", Datum.datum(punkt.tag)), y: .value("kg", Double(punkt.zehntel) / 10))
                        .foregroundStyle(farbe)
                    PointMark(x: .value("Tag", Datum.datum(punkt.tag)), y: .value("kg", Double(punkt.zehntel) / 10))
                        .foregroundStyle(farbe)
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 140)
                HStack {
                    statistik("Start", "\(ErnaehrungLogik.zahl(Double(erstes.zehntel) / 10)) kg")
                    Spacer()
                    statistik("Aktuell", "\(ErnaehrungLogik.zahl(Double(letztes.zehntel) / 10)) kg")
                    Spacer()
                    statistik("Veränderung", "\(veraenderung > 0 ? "+" : "")\(ErnaehrungLogik.zahl(Double(veraenderung) / 10)) kg")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .healthKarte(farbe)
        }
    }

    // MARK: Körperwerte

    /// Nur echte Einträge in diesem Zeitraum (nicht der fortgeschriebene letzte Wert): `koerperwert(bis:)`
    /// zählt nur, wenn sein Datum genau der abgefragte Tag ist.
    private func koerperReihe(_ art: KoerperArt) -> [(tag: String, wert: Double)] {
        tageImZeitraum.compactMap { tag in
            guard let w = modell.koerperwert(person, art, bis: tag), w.datum == tag else { return nil }
            return (tag: tag, wert: w.wert)
        }
    }

    private var koerperKarten: some View {
        ForEach(KoerperArt.allCases) { art in
            let reihe = koerperReihe(art)
            if !reihe.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(art.name).font(.headline)
                    Chart(reihe, id: \.tag) { punkt in
                        LineMark(x: .value("Tag", Datum.datum(punkt.tag)), y: .value(art.einheit, punkt.wert))
                            .foregroundStyle(farbe)
                        PointMark(x: .value("Tag", Datum.datum(punkt.tag)), y: .value(art.einheit, punkt.wert))
                            .foregroundStyle(farbe)
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                    .chartYAxis { AxisMarks(position: .leading) }
                    .frame(height: 100)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .healthKarte(farbe)
            }
        }
    }

    // MARK: Serie und Top-Lebensmittel

    private var topLebensmittel: [(name: String, kcal: Double)] {
        var summeJe: [String: (name: String, kcal: Double)] = [:]
        for e in alleEintraege {
            let bisher = summeJe[e.lebensmittel.id]?.kcal ?? 0
            summeJe[e.lebensmittel.id] = (name: e.lebensmittel.anzeigeName, kcal: bisher + e.naehrwerte.kcal)
        }
        return Array(summeJe.values.sorted { $0.kcal > $1.kcal }.prefix(10))
    }

    private var serieUndTopKarte: some View {
        let top = topLebensmittel
        let serie = AnalyseLogik.serie(modell.tage(person), heute: heute)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meiste Kalorien").font(.headline)
                Spacer()
                Label("\(serie) Tage in Folge", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(farbe)
            }
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
