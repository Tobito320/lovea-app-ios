import SwiftUI

/// Z-36.3, Spec 3.4: last night of both (duration, asleep, awake) plus week bars, in the Health card
/// look (indigo tint, SF Rounded numbers). Read-only — `HealthModell` gets sleep only from HealthKit.
struct SchlafCard: View {
    private var health: HealthModell { HealthModell.shared }

    var body: some View {
        let heute = Datum.text(Date())
        VStack(alignment: .leading, spacing: 14) {
            Label("Schlaf", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(HabitFarbe.indigo.farbe)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: 16) {
                schlafPerson(.ahmed, heute: heute)
                schlafPerson(.annika, heute: heute)
            }
            wocheBalken(heute: heute)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(HabitFarbe.indigo.farbe)
    }

    private func schlafPerson(_ person: Person, heute: String) -> some View {
        let nacht = health.schlafNacht(person, heute)
        let zeiten = health.schlafZeitenAm(person, heute)
        return VStack(alignment: .leading, spacing: 2) {
            Text(person.name).font(.caption.weight(.semibold)).foregroundStyle(Color.person(person))
            Text(nacht.map { dauerText($0.minuten) } ?? zeiten.map { EnergieLogik.dauer(EnergieLogik.imBett($0)) } ?? "–")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
            if let nacht {
                Text("\(uhrzeit(nacht.von))–\(uhrzeit(nacht.bis))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            if let zeiten {
                Text("Im Bett \(uhrzeit(zeiten.bett))–\(uhrzeit(zeiten.auf))").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nacht.map { "\(person.name): \(dauerText($0.minuten)), \(uhrzeit($0.von)) bis \(uhrzeit($0.bis))" } ?? "\(person.name): keine Schlafdaten")
    }

    private func dauerText(_ minuten: Int) -> String { "\(minuten / 60) h \(minuten % 60) min" }

    private func uhrzeit(_ datum: Date) -> String {
        datum.formatted(.dateTime.hour().minute().locale(Locale(identifier: "de_DE")))
    }

    private func wocheBalken(heute: String) -> some View {
        let tage = HabitLogik.wochenTage(heute: heute)
        let alleMinuten = tage.flatMap { tag in Person.allCases.compactMap { health.schlafNacht($0, tag)?.minuten } }
        let maxMinuten = max(alleMinuten.max() ?? 480, 60)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(tage, id: \.self) { tag in
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 3) {
                        balken(health.schlafNacht(.ahmed, tag)?.minuten, hoechstwert: maxMinuten, farbe: Color.person(.ahmed))
                        balken(health.schlafNacht(.annika, tag)?.minuten, hoechstwert: maxMinuten, farbe: Color.person(.annika))
                    }
                    .frame(height: 56)
                    Text(HabitLogik.wochentagKuerzel[Datum.wochentag(tag) - 1])
                        .font(.caption2)
                        .foregroundStyle(tag == heute ? Color.primary : Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func balken(_ minuten: Int?, hoechstwert: Int, farbe: Color) -> some View {
        let hoehe = minuten.map { CGFloat($0) / CGFloat(hoechstwert) * 56 } ?? 3
        return Capsule()
            .fill(minuten != nil ? farbe : farbe.opacity(0.15))
            .frame(width: 7, height: max(3, hoehe))
    }
}

private struct SchlafNachtWahl: Identifiable { let id: String }

/// Heute → Schlaf: letzte Nacht mit Eintragen-Knopf, beide Personen mit Woche, die letzten 14 Nächte
/// (Tipp = nachtragen) und Schlaf gegen Leistung.
struct SchlafDetailView: View {
    @State private var eintragen: SchlafNachtWahl?

    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var heute: String { Datum.text(Date()) }
    private var farbe: Color { HabitFarbe.indigo.farbe }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                letzteNacht
                SchlafCard()
                naechte
                leistung
            }
            .padding(16)
        }
        .navigationTitle("Schlaf")
        .sheet(item: $eintragen) { wahl in
            SchlafEintragenView(tag: wahl.id).presentationDetents([.medium, .large])
        }
    }

    // MARK: Letzte Nacht

    private var letzteNacht: some View {
        let minuten = health.schlafMinuten(ich, heute)
        let woche = (0..<7).compactMap { health.schlafMinuten(ich, Datum.addTage(heute, -$0)) }
        let eingetragen = health.schlafZeitenAm(ich, heute) != nil
        return VStack(alignment: .leading, spacing: 12) {
            Label("Letzte Nacht", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(farbe)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 4) {
                Text(minuten.map(EnergieLogik.dauer) ?? "Noch nichts da")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(sollText(minuten)).font(.subheadline).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            quellen(heute)
            if !woche.isEmpty {
                Text("Schnitt der letzten 7 Nächte: \(EnergieLogik.dauer(woche.reduce(0, +) / woche.count))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button { eintragen = SchlafNachtWahl(id: heute) } label: {
                Label(eingetragen ? "Eintrag ändern" : "Schlaf eintragen", systemImage: "bed.double.fill")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(farbe)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(farbe)
    }

    private func sollText(_ minuten: Int?) -> String {
        guard let minuten else { return "Trag ein, wann du ins Bett bist und wann du aufgestanden bist." }
        let fehlt = TagesformLogik.schlafSollMinuten - minuten
        return fehlt > 0 ? "\(EnergieLogik.dauer(fehlt)) unter 8 h" : "8 h geschafft"
    }

    /// Apple Health = echter Schlaf, eingetragen = Zeit im Bett. Gibt es beides, rechnet die App mit Apple Health.
    @ViewBuilder
    private func quellen(_ tag: String) -> some View {
        let nacht = health.schlafNacht(ich, tag)
        let zeiten = health.schlafZeitenAm(ich, tag)
        if nacht != nil || zeiten != nil {
            VStack(alignment: .leading, spacing: 4) {
                if let nacht {
                    Label("Geschlafen \(EnergieLogik.dauer(nacht.minuten)), \(Datum.uhrzeit(nacht.von))–\(Datum.uhrzeit(nacht.bis)) (Apple Health)",
                          systemImage: "heart.fill")
                }
                if let zeiten {
                    Label("Im Bett \(EnergieLogik.dauer(EnergieLogik.imBett(zeiten))), \(Datum.uhrzeit(zeiten.bett))–\(Datum.uhrzeit(zeiten.auf)) (eingetragen)",
                          systemImage: "bed.double.fill")
                }
                if nacht != nil && zeiten != nil {
                    Text("Die App rechnet mit Apple Health.").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Letzte 14 Nächte

    private var naechte: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Letzte 14 Nächte").font(.title3.bold()).accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(0..<14, id: \.self) { i in
                    nachtZeile(Datum.addTage(heute, -i))
                    if i < 13 { Divider() }
                }
            }
            .padding(.horizontal, 16)
            .healthKarte(farbe)
            Text("Tipp auf eine Nacht, um sie nachzutragen oder zu ändern.").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func nachtZeile(_ tag: String) -> some View {
        let minuten = health.schlafMinuten(ich, tag)
        let ausHealth = health.schlafNacht(ich, tag) != nil
        let eingetragen = health.schlafZeitenAm(ich, tag) != nil
        let quelle: String = ausHealth && eingetragen ? "Apple Health und eingetragen" : ausHealth ? "Apple Health" : eingetragen ? "eingetragen" : "fehlt"
        let teile = tag.split(separator: "-")
        let kurz = teile.count == 3 ? "\(teile[2]).\(teile[1])." : tag
        let wenig = (minuten ?? 480) < 360
        return Button { eintragen = SchlafNachtWahl(id: tag) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(HabitLogik.wochentagKuerzel[Datum.wochentag(tag) - 1]), \(kurz)").font(.subheadline)
                    Text(quelle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(minuten.map(EnergieLogik.dauer) ?? "–")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(wenig ? Color.orange : Color.primary)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Nacht nachtragen oder ändern")
    }

    // MARK: Schlaf und Training

    private var leistungsPunkte: [SchlafPunkt] {
        var schlaf: [String: Int] = [:]
        for i in 0..<90 {
            let tag = Datum.addTage(heute, -i)
            if let minuten = health.schlafMinuten(ich, tag) { schlaf[tag] = minuten }
        }
        return SchlafLeistung.punkte(TrainingModell.shared.sessions(ich), schlafMinuten: schlaf)
    }

    @ViewBuilder
    private var leistung: some View {
        let punkte = leistungsPunkte
        if punkte.count >= 3 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Schlaf und Training").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                Text("Jeder Punkt ist eine Einheit: Schlaf der Nacht davor gegen deine Leistung.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                SchlafDiagramm(punkte: punkte)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .healthKarte(farbe)
        }
    }
}
