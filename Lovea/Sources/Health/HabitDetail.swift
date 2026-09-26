import SwiftUI

/// Z-35.3, Spec 3.3 "Kachel antippen → Detail": week and month (swipeable, never the future), streak,
/// best streak, 30-day rate, comparison with the partner for "wir beide", marking past days, edit, hide.
struct HabitDetailView: View {
    let habitId: String

    @State private var blatt: HabitBlatt?
    @State private var ausblendenFragen = false
    @Environment(\.dismiss) private var dismiss
    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        Group {
            if let habit = health.habits[habitId] {
                inhalt(habit)
            } else {
                ContentUnavailableView("Habit nicht gefunden", systemImage: "questionmark.circle")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func inhalt(_ habit: Habit) -> some View {
        let heute = Datum.text(Date())
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HabitDetailKopf(habit: habit, werte: health.habitWerte(habit.id, ich), ziel: health.habitZiel(habit.id, ich), heute: heute)
                woche(habit, heute: heute)
                monat(habit, heute: heute)
                if habit.fuer == "beide" { vergleich(habit, heute: heute) }
                aktionen
            }
            .padding(16)
        }
        .navigationTitle(habit.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Bearbeiten") { blatt = .bearbeiten } }
        }
        .sheet(item: $blatt) { art in blattInhalt(art, habit) }
        .confirmationDialog("\(habit.name) ausblenden?", isPresented: $ausblendenFragen, titleVisibility: .visible) {
            Button("Ausblenden", role: .destructive) {
                health.ausblenden(habit.id, true)
                Haptik.leicht()
                dismiss()
            }
        } message: {
            Text("Die Historie bleibt. Über das Auge bei den Habits blendest du sie wieder ein.")
        }
    }

    /// Gym and Wasser are built in: "Bearbeiten" changes their goals (`ziel.gym`, `ziel.wasser`).
    @ViewBuilder
    private func blattInhalt(_ art: HabitBlatt, _ habit: Habit) -> some View {
        switch art {
        case .bearbeiten:
            if habit.istEingebaut { ZieleAendernView() } else { HabitFormular(bestehend: habit) }
        case .vergangeneTage:
            VergangeneTageView(habit: habit)
        }
    }

    private func woche(_ habit: Habit, heute: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Woche").font(.headline).accessibilityAddTraits(.isHeader)
            HabitWochenReihe(titel: "Du", habit: habit, werte: health.habitWerte(habit.id, ich), ziel: health.habitZiel(habit.id, ich), heute: heute)
            if habit.fuer == "beide" {
                let partner = ich.partner
                HabitWochenReihe(titel: partner.name, habit: habit, werte: health.habitWerte(habit.id, partner), ziel: health.habitZiel(habit.id, partner), heute: heute)
            }
        }
        .padding(16)
        .healthKarte()
    }

    private func monat(_ habit: Habit, heute: String) -> some View {
        let werte = health.habitWerte(habit.id, ich)
        let ziel = health.habitZiel(habit.id, ich)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Monat").font(.headline).accessibilityAddTraits(.isHeader).padding(.horizontal, 16)
            MonatsPager { zurueck in
                HabitMonat(habit: habit, werte: werte, ziel: ziel, heute: heute, monateZurueck: zurueck).padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .healthKarte()
    }

    private func vergleich(_ habit: Habit, heute: String) -> some View {
        let partner = ich.partner
        return VStack(alignment: .leading, spacing: 12) {
            Text("Vergleich").font(.headline).accessibilityAddTraits(.isHeader)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("")
                    Text("Du").foregroundStyle(Color.person(ich))
                    Text(partner.name).foregroundStyle(Color.person(partner))
                }
                .font(.subheadline.weight(.semibold))
                GridRow {
                    Text("Serie").foregroundStyle(.secondary)
                    Text(serieText(habit, ich, heute: heute))
                    Text(serieText(habit, partner, heute: heute))
                }
                GridRow {
                    Text("Quote 30 Tage").foregroundStyle(.secondary)
                    Text(quoteText(habit, ich, heute: heute))
                    Text(quoteText(habit, partner, heute: heute))
                }
            }
            .font(.subheadline)
            .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte()
    }

    private func serieText(_ habit: Habit, _ person: Person, heute: String) -> String {
        HabitDetailKopf.serieText(habit, HabitLogik.serie(habit, werte: health.habitWerte(habit.id, person), ziel: health.habitZiel(habit.id, person), heute: heute))
    }

    private func quoteText(_ habit: Habit, _ person: Person, heute: String) -> String {
        HabitLogik.quote30(habit, werte: health.habitWerte(habit.id, person), ziel: health.habitZiel(habit.id, person), heute: heute)
            .formatted(.percent.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE")))
    }

    private var aktionen: some View {
        VStack(spacing: 10) {
            Button { blatt = .vergangeneTage } label: {
                Label("Vergangene Tage markieren", systemImage: "calendar.badge.checkmark").frame(maxWidth: .infinity, minHeight: 44)
            }
            Button(role: .destructive) { ausblendenFragen = true } label: {
                Label("Ausblenden", systemImage: "eye.slash").frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .buttonStyle(.bordered)
    }
}

private enum HabitBlatt: String, Identifiable {
    case bearbeiten, vergangeneTage
    var id: String { rawValue }
}

/// Symbol, frequency and the three numbers: streak, best streak, 30-day rate.
private struct HabitDetailKopf: View {
    let habit: Habit
    let werte: [String: Int]
    let ziel: Int?
    let heute: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: habit.symbol)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(habit.tint)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(habit.tint.opacity(0.18)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(HabitLogik.haeufigkeitText(habit, ziel: ziel)).font(.headline)
                    Text(habit.fuer == "ich" ? "Nur ich" : "Wir beide").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                zahl("Serie", Self.serieText(habit, HabitLogik.serie(habit, werte: werte, ziel: ziel, heute: heute)), symbol: "flame.fill")
                zahl("Beste", Self.serieText(habit, HabitLogik.besteSerie(habit, werte: werte, ziel: ziel, heute: heute)), symbol: "trophy.fill")
                zahl("30 Tage", HabitLogik.quote30(habit, werte: werte, ziel: ziel, heute: heute).formatted(.percent.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE"))), symbol: "chart.bar.fill")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(habit.tint)
    }

    private func zahl(_ titel: String, _ wert: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(titel, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(habit.tint)
            Text(wert).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// "x pro Woche" counts weeks, the others days.
    static func serieText(_ habit: Habit, _ n: Int) -> String {
        if case .proWoche = habit.haeufigkeit { return n == 1 ? "1 Woche" : "\(n) Wochen" }
        return n == 1 ? "1 Tag" : "\(n) Tage"
    }
}

/// One person's Mo…So squares, bigger than on the tile.
struct HabitWochenReihe: View {
    let titel: String
    let habit: Habit
    let werte: [String: Int]
    let ziel: Int?
    let heute: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titel).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(HabitLogik.wochenTage(heute: heute), id: \.self) { tag in feld(tag) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel): \(HabitLogik.wochenTage(heute: heute).filter { $0 <= heute && HabitLogik.erledigt(habit, wert: werte[$0] ?? 0, ziel: ziel) }.count) Tage erledigt diese Woche")
    }

    private func feld(_ tag: String) -> some View {
        let anteil = tag > heute ? 0 : HabitLogik.anteil(habit, wert: werte[tag] ?? 0, ziel: ziel)
        let form = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return VStack(spacing: 4) {
            form.fill(habit.tint.opacity(tag > heute ? 0.06 : 0.16))
                .overlay(alignment: .bottom) {
                    GeometryReader { geo in
                        Rectangle().fill(habit.tint).frame(height: geo.size.height * anteil).frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .clipShape(form)
                .overlay { if anteil >= 1 { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Color.aufHabitFarbe) } }
                .aspectRatio(1, contentMode: .fit)
            Text(HabitLogik.wochentagKuerzel[Datum.wochentag(tag) - 1]).font(.caption2).foregroundStyle(tag == heute ? Color.primary : Color.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// GitHub-like month grid of one habit (Spec 3.3), always 6 rows so swiping keeps the height.
struct HabitMonat: View {
    let habit: Habit
    let werte: [String: Int]
    let ziel: Int?
    let heute: String
    let monateZurueck: Int

    var body: some View {
        let gitter = HealthLogik.monatsGitter(heute: heute, monateZurueck: monateZurueck)
        let zellen = gitter + [String?](repeating: nil, count: max(0, 42 - gitter.count))
        VStack(alignment: .leading, spacing: 8) {
            Text(HealthText.monat(gitter)).font(.subheadline.weight(.semibold))
            WochentagsKopf()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(zellen.enumerated()), id: \.offset) { _, tag in feld(tag) }
            }
        }
    }

    @ViewBuilder
    private func feld(_ tag: String?) -> some View {
        if let tag, tag <= heute {
            let anteil = HabitLogik.anteil(habit, wert: werte[tag] ?? 0, ziel: ziel)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(habit.tint.opacity(anteil > 0 ? 0.3 + 0.7 * anteil : 0.1))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Text(HealthText.tagesnummer(tag))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(anteil >= 1 ? Color.aufHabitFarbe : Color.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Datum.anzeige(tag)): \(HabitLogik.erledigt(habit, wert: werte[tag] ?? 0, ziel: ziel) ? "erledigt" : "offen")")
        } else {
            Color.clear.aspectRatio(1, contentMode: .fit)
        }
    }
}
