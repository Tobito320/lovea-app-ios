import SwiftUI

/// Last night of both plus week bars, in the Health card look (indigo tint, SF Rounded numbers).
/// Only hand-entered times count (`HealthModell.schlafMinuten`).
struct SchlafCard: View {
    private var health: HealthModell { HealthModell.shared }

    var body: some View {
        let heute = Datum.text(Date())
        VStack(alignment: .leading, spacing: 14) {
            Label("Ihr beide", systemImage: "moon.zzz.fill")
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
        let minuten = health.schlafMinuten(person, heute)
        let zeiten = minuten == nil ? nil : health.schlafZeitenAm(person, heute)
        return VStack(alignment: .leading, spacing: 2) {
            Text(person.name).font(.caption.weight(.semibold)).foregroundStyle(Color.person(person))
            Text(minuten.map(EnergieLogik.dauer) ?? "–")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
            if let zeiten {
                Text("\(Datum.uhrzeit(zeiten.bett))–\(Datum.uhrzeit(zeiten.auf))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(minuten.map { "\(person.name): \(EnergieLogik.dauer($0))" } ?? "\(person.name): nichts eingetragen")
    }

    private func wocheBalken(heute: String) -> some View {
        let tage = HabitLogik.wochenTage(heute: heute)
        let alleMinuten = tage.flatMap { tag in Person.allCases.compactMap { health.schlafMinuten($0, tag) } }
        let maxMinuten = max(alleMinuten.max() ?? 480, 60)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(tage, id: \.self) { tag in
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 3) {
                        balken(health.schlafMinuten(.ahmed, tag), hoechstwert: maxMinuten, farbe: Color.person(.ahmed))
                        balken(health.schlafMinuten(.annika, tag), hoechstwert: maxMinuten, farbe: Color.person(.annika))
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

/// Heute → Schlaf: letzte Nacht mit Eintragen-Knopf, beide Personen mit Woche, die letzten 30 Nächte
/// (Tipp = bearbeiten), eine ältere Nacht nachtragen, Schlaf gegen Leistung.
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nacht nachtragen", systemImage: "plus") { eintragen = SchlafNachtWahl(id: heute) }
            }
        }
        .sheet(item: $eintragen) { wahl in
            SchlafEintragenView(tag: wahl.id).presentationDetents([.large])
        }
    }

    // MARK: Letzte Nacht

    private var letzteNacht: some View {
        let minuten = health.schlafMinuten(ich, heute)
        let woche = (0..<7).compactMap { health.schlafMinuten(ich, Datum.addTage(heute, -$0)) }
        let zeiten = minuten == nil ? nil : health.schlafZeitenAm(ich, heute)
        return VStack(alignment: .leading, spacing: 12) {
            Label("Letzte Nacht", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(farbe)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 4) {
                Text(minuten.map(EnergieLogik.dauer) ?? "Noch nichts eingetragen")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                if let zeiten {
                    Text("Im Bett \(Datum.uhrzeit(zeiten.bett)) bis \(Datum.uhrzeit(zeiten.auf))")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                Text(sollText(minuten)).font(.subheadline).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            if !woche.isEmpty {
                Text("Schnitt der letzten 7 Nächte: \(EnergieLogik.dauer(woche.reduce(0, +) / woche.count))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button { eintragen = SchlafNachtWahl(id: heute) } label: {
                Label(minuten == nil ? "Schlaf eintragen" : "Eintrag ändern", systemImage: "bed.double.fill")
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

    // MARK: Letzte 30 Nächte

    private var naechte: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Letzte 30 Nächte").font(.title3.bold()).accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(0..<30, id: \.self) { i in
                    nachtZeile(Datum.addTage(heute, -i))
                    if i < 29 { Divider() }
                }
            }
            .padding(.horizontal, 16)
            .healthKarte(farbe)
            Text("Tipp auf eine Nacht, um sie zu ändern oder zu löschen. Ältere Nächte über das Plus oben.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func nachtZeile(_ tag: String) -> some View {
        let minuten = health.schlafMinuten(ich, tag)
        let zeiten = minuten == nil ? nil : health.schlafZeitenAm(ich, tag)
        let teile = tag.split(separator: "-")
        let kurz = teile.count == 3 ? "\(teile[2]).\(teile[1])." : tag
        let wenig = (minuten ?? 480) < 360
        return Button { eintragen = SchlafNachtWahl(id: tag) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(HabitLogik.wochentagKuerzel[Datum.wochentag(tag) - 1]), \(kurz)").font(.subheadline)
                    Text(zeiten.map { "\(Datum.uhrzeit($0.bett)) bis \(Datum.uhrzeit($0.auf))" } ?? "nichts eingetragen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
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
        .accessibilityHint("Nacht eintragen, ändern oder löschen")
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
