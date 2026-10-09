import SwiftUI

/// Z-35.3, Spec 3.3 "Habit anlegen": name, 40 symbols, 8 colors, frequency, tick or count with a
/// daily goal, "nur ich" / "wir beide". With `bestehend` it edits (`habit.aendern`, same id).
struct HabitFormular: View {
    let bestehend: Habit?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var symbol: String
    @State private var farbe: HabitFarbe
    @State private var art: HaeufigkeitArt
    @State private var proWoche: Int
    @State private var tage: Set<Int>
    @State private var zaehlen: Bool
    @State private var tagesziel: Int
    @State private var nurIch: Bool

    init(bestehend: Habit?) {
        self.bestehend = bestehend
        let h = bestehend
        _name = State(initialValue: h?.name ?? "")
        _symbol = State(initialValue: h?.symbol ?? "star.fill")
        _farbe = State(initialValue: h.map { HabitFarbe.von($0.farbe) } ?? .amber)
        _zaehlen = State(initialValue: h?.zaehlen ?? false)
        _tagesziel = State(initialValue: h?.tagesziel ?? 3)
        _nurIch = State(initialValue: h?.fuer == "ich")
        switch h?.haeufigkeit ?? .taeglich {
        case .taeglich:
            _art = State(initialValue: .taeglich); _proWoche = State(initialValue: 3); _tage = State(initialValue: [1, 3, 5])
        case .proWoche(let n):
            _art = State(initialValue: .proWoche); _proWoche = State(initialValue: n); _tage = State(initialValue: [1, 3, 5])
        case .tage(let t):
            _art = State(initialValue: .tage); _proWoche = State(initialValue: 3); _tage = State(initialValue: Set(t))
        }
    }

    private var sauberName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var gueltig: Bool { !sauberName.isEmpty && (art != .tage || !tage.isEmpty) }

    private var entwurf: Habit {
        let haeufigkeit: Haeufigkeit = switch art {
        case .taeglich: .taeglich
        case .proWoche: .proWoche(proWoche)
        case .tage: .tage(tage.sorted())
        }
        return Habit(
            id: bestehend?.id ?? "h-\(UUID().uuidString.lowercased())",
            name: sauberName.isEmpty ? "Neue Habit" : sauberName, symbol: symbol, farbe: farbe.rawValue,
            zaehlen: zaehlen, tagesziel: zaehlen ? tagesziel : nil, haeufigkeit: haeufigkeit, fuer: nurIch ? "ich" : "beide"
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { vorschau }
                Section("Name") { TextField("z. B. Lesen", text: $name).textInputAutocapitalization(.sentences) }
                Section("Symbol") { symbolGitter }
                Section("Farbe") { farbReihe }
                haeufigkeitSektion
                artSektion
                Section("Für") {
                    Picker("Für", selection: $nurIch) {
                        Text("Wir beide").tag(false)
                        Text("Nur ich").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(bestehend == nil ? "Neue Habit" : "Habit bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(bestehend == nil ? "Anlegen" : "Sichern") { sichern() }.disabled(!gueltig)
                }
            }
        }
    }

    /// Live tile, the same view as on the Health tab.
    private var vorschau: some View {
        HabitKachel(habit: entwurf, ziel: nil, werte: [:], heute: Datum.text(Date()))
            .frame(width: 170, height: 170)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .listRowBackground(Color.clear)
    }

    private var symbolGitter: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 4) {
            ForEach(HabitSymbole.alle, id: \.self) { name in
                let gewaehlt = name == symbol
                Button { symbol = name; Haptik.auswahl() } label: {
                    Image(systemName: name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(gewaehlt ? Color.aufHabitFarbe : Color.primary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(gewaehlt ? farbe.farbe : Color.clear))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name)
                .accessibilityAddTraits(gewaehlt ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private var farbReihe: some View {
        HStack(spacing: 0) {
            ForEach(HabitFarbe.allCases, id: \.self) { f in
                Button { farbe = f; Haptik.auswahl() } label: {
                    Circle().fill(f.farbe)
                        .frame(width: 30, height: 30)
                        .overlay { if f == farbe { Circle().strokeBorder(Color.primary, lineWidth: 2.5).padding(-5) } }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(f.rawValue.capitalized)
                .accessibilityAddTraits(f == farbe ? .isSelected : [])
            }
        }
    }

    private var haeufigkeitSektion: some View {
        Section("Häufigkeit") {
            Picker("Häufigkeit", selection: $art) {
                Text("Jeden Tag").tag(HaeufigkeitArt.taeglich)
                Text("Pro Woche").tag(HaeufigkeitArt.proWoche)
                Text("Feste Tage").tag(HaeufigkeitArt.tage)
            }
            .pickerStyle(.segmented)
            if art == .proWoche {
                Stepper("\(proWoche) Tage pro Woche", value: $proWoche, in: 1...7)
            } else if art == .tage {
                wochentage
            }
        }
    }

    private var wochentage: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { tag in
                let an = tage.contains(tag)
                Button {
                    if an { tage.remove(tag) } else { tage.insert(tag) }
                    Haptik.auswahl()
                } label: {
                    Text(HabitLogik.wochentagKuerzel[tag - 1])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(an ? Color.aufHabitFarbe : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(an ? farbe.farbe : Color(uiColor: .tertiarySystemFill)))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(an ? .isSelected : [])
            }
        }
    }

    private var artSektion: some View {
        Section("Art") {
            Picker("Art", selection: $zaehlen) {
                Text("Abhaken").tag(false)
                Text("Zählen").tag(true)
            }
            .pickerStyle(.segmented)
            if zaehlen {
                Stepper("Tagesziel: \(tagesziel)", value: $tagesziel, in: 1...50)
            }
        }
    }

    private func sichern() {
        let habit = entwurf
        if bestehend == nil { HealthModell.shared.anlegen(habit) } else { HealthModell.shared.aendern(habit) }
        Haptik.erfolg()
        dismiss()
    }
}

private enum HaeufigkeitArt: Hashable { case taeglich, proWoche, tage }
