import SwiftUI

/// Z-35.2, Spec 3.3: "Habits" with a plus, tiles in two columns, each the size of a small widget.
/// Tapping a tile zooms into its detail.
struct HabitsSektion: View {
    let zoom: Namespace.ID
    let oeffnen: (HealthZiel) -> Void

    @State private var anlegenOffen = false
    @Environment(\.dynamicTypeSize) private var schrift
    private var health: HealthModell { HealthModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            kopf
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: schrift.isAccessibilitySize ? 1 : 2), spacing: 12) {
                ForEach(health.sichtbareHabits(fuer: ich)) { habit in kachel(habit) }
            }
        }
        .sheet(isPresented: $anlegenOffen) { HabitFormular(bestehend: nil) }
    }

    private var kopf: some View {
        HStack(spacing: 4) {
            Text("Habits").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Spacer()
            if !ausgeblendete.isEmpty { einblenden }
            Button { anlegenOffen = true } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(uiColor: .tertiarySystemFill)))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.federnd)
            .accessibilityLabel("Neue Habit")
        }
    }

    /// Built-ins are "nur ausblendbar" (Spec 3.3), so hiding must always be undoable.
    private var ausgeblendete: [Habit] {
        health.habits.values
            .filter { $0.ausgeblendet && ($0.fuer != "ich" || $0.von == ich.rawValue) }
            .sorted { $0.name < $1.name }
    }

    private var einblenden: some View {
        Menu {
            ForEach(ausgeblendete) { habit in
                Button("\(habit.name) einblenden", systemImage: habit.symbol) { health.ausblenden(habit.id, false) }
            }
        } label: {
            Image(systemName: "eye.slash").font(.body.weight(.semibold)).frame(width: 44, height: 44)
        }
        .accessibilityLabel("Ausgeblendete Habits")
    }

    @ViewBuilder
    private func kachel(_ habit: Habit) -> some View {
        let heute = Datum.text(Date())
        let partner = ich.partner
        let partnerFertig = habit.fuer == "beide"
            && HabitLogik.erledigt(habit, wert: health.habitWert(habit.id, partner, heute), ziel: health.habitZiel(habit.id, partner))
        let ansicht = HabitKachel(
            habit: habit, ziel: health.habitZiel(habit.id, ich), werte: health.habitWerte(habit.id, ich), heute: heute,
            partner: partnerFertig ? partner : nil,
            oeffnen: { oeffnen(.habit(habit.id)) },
            setzen: { health.setzeHabit(habit.id, datum: heute, wert: $0) }
        )
        .matchedTransitionSource(id: HealthZiel.habit(habit.id), in: zoom)
        if schrift.isAccessibilitySize { ansicht } else { ansicht.aspectRatio(1, contentMode: .fit) }
    }
}

/// One HabitLink tile (Spec 3.3): symbol top left, check (or "+1" ring) top right with the partner's
/// head beside it once they are done today, name, frequency, the 7 squares of this week and the
/// streak flame. Pure — values and closures come in (render board, form preview).
struct HabitKachel: View {
    let habit: Habit
    let ziel: Int?
    let werte: [String: Int]
    let heute: String
    var partner: Person? = nil
    var oeffnen: () -> Void = {}
    var setzen: (Int) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var wertHeute: Int { werte[heute] ?? 0 }
    private var erledigt: Bool { HabitLogik.erledigt(habit, wert: wertHeute, ziel: ziel) }
    private var serie: Int { HabitLogik.serie(habit, werte: werte, ziel: ziel, heute: heute) }
    private var zielWert: Int { max(1, ziel ?? habit.tagesziel ?? 1) }
    private var bewegung: Animation { reduceMotion ? .easeInOut(duration: 0.2) : Feder.federnd }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: oeffnen) { inhalt }
                .buttonStyle(.federnd)
                .accessibilityLabel(beschreibung)
                .accessibilityHint("Öffnet die Details")
            HStack(spacing: 2) {
                if let partner {
                    FigurKopf(person: partner, groesse: 28)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("\(partner.name) hat heute erledigt")
                }
                if habit.zaehlen { zaehlKnopf } else { hakenKnopf }
            }
            .padding(10) // check centre on the symbol's centre line (12 + 40 / 2)
            .animation(bewegung, value: partner)
        }
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: habit.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(habit.tint)
                .frame(height: 40)
            Spacer(minLength: 6)
            Text(habit.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(untertitel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .monospacedDigit()
            HStack(spacing: 4) {
                woche
                Spacer(minLength: 2)
                flamme
            }
            .padding(.top, 10)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .healthKarte(habit.tint)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var untertitel: String {
        let text = HabitLogik.haeufigkeitText(habit, ziel: ziel)
        return habit.zaehlen ? "\(wertHeute)/\(zielWert) · \(text)" : text
    }

    private var woche: some View {
        HStack(spacing: 3) {
            ForEach(HabitLogik.wochenTage(heute: heute), id: \.self) { tag in
                kaestchen(tag > heute ? 0 : HabitLogik.anteil(habit, wert: werte[tag] ?? 0, ziel: ziel), istHeute: tag == heute)
            }
        }
        .accessibilityHidden(true)
    }

    /// Counting habits fill from the bottom (Spec 3.3 "füllen sich anteilig").
    private func kaestchen(_ anteil: Double, istHeute: Bool) -> some View {
        let form = RoundedRectangle(cornerRadius: 3.5, style: .continuous)
        return form.fill(habit.tint.opacity(0.18))
            .frame(width: 13, height: 13)
            .overlay(alignment: .bottom) { Rectangle().fill(habit.tint).frame(height: 13 * anteil) }
            .clipShape(form)
            .overlay { if istHeute { form.strokeBorder(habit.tint, lineWidth: 1) } }
    }

    private var flamme: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill").font(.caption.weight(.bold))
            Text("\(serie)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(serie)))
        }
        .foregroundStyle(serie > 0 ? habit.tint : Color.secondary)
        .accessibilityHidden(true)
    }

    private var hakenKnopf: some View {
        Button {
            let neu = erledigt ? 0 : 1
            withAnimation(bewegung) { setzen(neu) }
            if neu > 0 { Haptik.erfolg() } else { Haptik.leicht() }
        } label: {
            ZStack {
                Circle().strokeBorder(habit.tint.opacity(0.55), lineWidth: 2)
                Circle().fill(habit.tint).scaleEffect(erledigt ? 1 : 0.3).opacity(erledigt ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.aufHabitFarbe)
                    .scaleEffect(erledigt ? 1 : 0.4)
                    .opacity(erledigt ? 1 : 0)
            }
            .frame(width: 34, height: 34)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.federnd)
        .accessibilityLabel("\(habit.name) heute")
        .accessibilityValue(erledigt ? "erledigt" : "offen")
        .accessibilityHint(erledigt ? "Nimmt den Haken zurück" : "Hakt heute ab")
    }

    /// Spec 3.3: tap = +1, the ring fills up to the daily goal; press and hold sets the number.
    private var zaehlKnopf: some View {
        Menu {
            Picker("Anzahl", selection: Binding(get: { wertHeute }, set: { zaehlen(auf: $0) })) {
                ForEach(0...max(zielWert + 4, wertHeute), id: \.self) { n in Text("\(n)").tag(n) }
            }
        } label: {
            zaehlRing
        } primaryAction: {
            zaehlen(auf: wertHeute + 1)
        }
        .menuIndicator(.hidden)
        .accessibilityLabel("\(habit.name): \(wertHeute) von \(zielWert)")
        .accessibilityHint("Tippen zählt eins dazu, gedrückt halten setzt die Anzahl")
    }

    private var zaehlRing: some View {
        ZStack {
            Circle().stroke(habit.tint.opacity(0.22), lineWidth: 3)
            Circle()
                .trim(from: 0, to: HabitLogik.anteil(habit, wert: wertHeute, ziel: ziel))
                .stroke(habit.tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if erledigt {
                Circle().fill(habit.tint).padding(5)
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.aufHabitFarbe)
            } else {
                Text("+1").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(habit.tint)
            }
        }
        .frame(width: 32, height: 32)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }

    private func zaehlen(auf neu: Int) {
        let vorher = erledigt
        withAnimation(bewegung) { setzen(max(0, neu)) }
        if !vorher && HabitLogik.erledigt(habit, wert: neu, ziel: ziel) { Haptik.erfolg() } else { Haptik.leicht() }
    }

    private var beschreibung: String {
        "\(habit.name), \(untertitel), Serie \(serie), heute \(erledigt ? "erledigt" : "offen")"
    }
}
