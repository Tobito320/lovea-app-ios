import SwiftUI

/// Karte oben in Health: der Plantag von heute, "Tag 3 diese Woche: Upper". Tippen öffnet das Gym.
struct PlantagKarteInhalt: View {
    let stand: PlantagStand

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: stand.heute ? "figure.strengthtraining.traditional" : "moon.zzz")
                .font(.title3)
                .foregroundStyle(stand.heute ? Color.accentColor : Color.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(stand.titel).font(.headline).foregroundStyle(Color.primary).lineLimit(2)
                Text(stand.unter).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Liest den eigenen Plan; ohne Plan oder ohne feste Wochentage bleibt die Karte weg.
struct PlantagKarte: View {
    var oeffnen: () -> Void = {}

    var body: some View {
        let ich = Raum.shared.ich ?? .ahmed
        if let stand = SplitFrei.plantag(TrainingModell.shared.plan(ich), datum: Datum.text(Date())) {
            Button(action: oeffnen) { PlantagKarteInhalt(stand: stand) }
                .buttonStyle(.plain)
                .accessibilityHint("Öffnet das Gym")
        }
    }
}

/// Reiner Inhalt (Render-Tafel): Name des Splits, Zahl der Tage, ein Namensfeld je Tag.
struct SplitFreiInhalt: View {
    @Binding var name: String
    @Binding var tage: Int
    @Binding var namen: [String]

    var body: some View {
        Form {
            Section("Split") {
                TextField("Name, z. B. Mein Split", text: $name)
            }
            Section {
                Stepper(value: $tage, in: SplitFrei.tageBereich) {
                    Text("\(tage) \(tage == 1 ? "Tag" : "Tage") pro Woche").monospacedDigit()
                }
            }
            Section {
                ForEach(0..<tage, id: \.self) { i in
                    TextField(SplitFrei.standardName(i + 1), text: $namen[i])
                        .submitLabel(.next)
                }
            } header: {
                Text("Namen der Tage")
            } footer: {
                Text("Die Wochentage und Übungen stellst du danach pro Tag ein.")
            }
        }
    }
}

/// Frischer eigener Split anlegen. Ersetzt den jetzigen Plan (nach Rückfrage, wenn er Tage hat).
struct SplitFreiView: View {
    /// Nach dem Anlegen, z. B. weiter in den Editor.
    var angelegt: () -> Void = {}

    @State private var name = ""
    @State private var tage = 3
    @State private var namen = Array(repeating: "", count: SplitFrei.tageBereich.upperBound)
    @State private var frage = false
    private var modell: TrainingModell { TrainingModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        SplitFreiInhalt(name: $name, tage: $tage, namen: $namen)
            .navigationTitle("Neuer Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") {
                        if modell.plan(ich).tage.isEmpty { anlegen() } else { frage = true }
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Dein jetziger Plan wird ersetzt.", isPresented: $frage, titleVisibility: .visible) {
                Button("Plan ersetzen", role: .destructive) { anlegen() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Deine bisherigen Trainingstage und Gewichte im Plan gehen verloren. Der Verlauf bleibt.")
            }
    }

    private func anlegen() {
        modell.planSichern(SplitFrei.anlegen(name: name, tage: Array(namen.prefix(tage))))
        Haptik.erfolg()
        angelegt()
    }
}
