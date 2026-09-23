import SwiftUI

/// Z-35.3 "Vergangene Tage markieren" (wie Runde 2, jetzt für jede Habit): tapping a past day ticks
/// it (counting habits: up to the daily goal) or clears it again. Only own days.
struct VergangeneTageView: View {
    let habit: Habit

    @Environment(\.dismiss) private var dismiss
    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MonatsPager { zurueck in monat(zurueck).padding(.horizontal, 16) }
                    Text(hinweis).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Vergangene Tage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
    }

    /// Spec 4.1 (Runde 2): Gym and Wasser marked more than 7 days late give no points (`PunkteLogik`).
    private var hinweis: String {
        habit.istEingebaut
            ? "Nur Tage der letzten 7 Tage geben noch Punkte. Ältere werden grün, ohne Punkte."
            : "Eigene Habits geben keine Punkte, sie zählen für Serie und Quote."
    }

    private func monat(_ zurueck: Int) -> some View {
        let heute = Datum.text(Date())
        let gitter = HealthLogik.monatsGitter(heute: heute, monateZurueck: zurueck)
        let zellen = gitter + [String?](repeating: nil, count: max(0, 42 - gitter.count))
        return VStack(alignment: .leading, spacing: 10) {
            Text(HealthText.monat(gitter)).font(.title3.weight(.semibold))
            WochentagsKopf()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(zellen.enumerated()), id: \.offset) { _, tag in
                    if let tag, tag <= heute { tagKnopf(tag) } else { Color.clear.frame(height: 44) }
                }
            }
        }
    }

    private func tagKnopf(_ tag: String) -> some View {
        let ziel = health.habitZiel(habit.id, ich)
        let an = HabitLogik.erledigt(habit, wert: health.habitWert(habit.id, ich, tag), ziel: ziel)
        return Button {
            health.setzeHabit(habit.id, datum: tag, wert: an ? 0 : (habit.zaehlen ? max(1, ziel ?? habit.tagesziel ?? 1) : 1))
            if an { Haptik.leicht() } else { Haptik.erfolg() }
        } label: {
            Text(HealthText.tagesnummer(tag))
                .font(.subheadline.weight(an ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(an ? Color.aufHabitFarbe : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(an ? habit.tint : Color(uiColor: .tertiarySystemFill)))
        }
        .buttonStyle(.federnd)
        .accessibilityLabel("\(Datum.anzeige(tag)), \(habit.name)")
        .accessibilityValue(an ? "erledigt" : "offen")
    }
}

/// Own goals (steps, Gym per week, Wasser per day) and the shared weekly steps goal. For Gym and
/// Wasser this is also their "Bearbeiten".
struct ZieleAendernView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var schritte: Int
    @State private var gym: Int
    @State private var wasser: Int
    @State private var gemeinsamWoche: Int

    init() {
        let h = HealthModell.shared
        _schritte = State(initialValue: h.zielSchritte())
        _gym = State(initialValue: h.zielGym())
        _wasser = State(initialValue: h.zielWasser())
        _gemeinsamWoche = State(initialValue: h.zielGemeinsamWoche)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Eigene Ziele") {
                    Stepper(value: $schritte, in: 1_000...30_000, step: 500) {
                        Text("Schritte: \(HealthText.zahl(schritte))")
                    }
                    Stepper("Gym pro Woche: \(gym)×", value: $gym, in: 1...7)
                    Stepper("Wasser pro Tag: \(wasser) Gläser", value: $wasser, in: 1...20)
                }
                Section("Gemeinsam") {
                    Stepper(value: $gemeinsamWoche, in: 10_000...500_000, step: 10_000) {
                        Text("Wöchentliches Ziel: \(HealthText.zahl(gemeinsamWoche))")
                    }
                }
            }
            .navigationTitle("Ziele ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { speichern(); dismiss() } }
            }
        }
    }

    private func speichern() {
        let h = HealthModell.shared
        if schritte != h.zielSchritte() { h.setzeZiel("ziel.schritte", schritte) }
        if gym != h.zielGym() { h.setzeZiel("ziel.gym", gym) }
        if wasser != h.zielWasser() { h.setzeZiel("ziel.wasser", wasser) }
        if gemeinsamWoche != h.zielGemeinsamWoche { h.setzeZiel("ziel.gemeinsamWoche", gemeinsamWoche) }
        Haptik.erfolg()
    }
}
