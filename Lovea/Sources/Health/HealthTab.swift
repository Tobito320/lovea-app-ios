import SwiftUI

/// Where Health navigates. Everything is pushed onto the one stack of `HeuteView` (the Health tab).
enum HealthZiel: Hashable {
    case habit(String), schritte(Person), schritteVergleich, punkte
    case trainingsPlan(Person), gymSession(String), gymVerlauf
}

/// Die Seite zu einem `HealthZiel`, registriert im Stapel von Health.
struct HealthZielAnsicht: View {
    let ziel: HealthZiel

    var body: some View {
        switch ziel {
        case .habit(let id): HabitDetailView(habitId: id)
        case .schritte(let person): SchritteDetailView(person: person)
        case .schritteVergleich: SchritteVergleichView()
        case .punkte: PunkteVerlaufView()
        case .trainingsPlan(let person): TrainingsPlanView(person: person)
        case .gymSession(let id): GymSessionView(sessionId: id)
        case .gymVerlauf: GymVerlaufView()
        }
    }
}

/// Training (aus Health geöffnet): Energie, Training, laufende Challenges. Schritte liegen auf der
/// Schritte-Seite (`SchritteUebersicht`), Habits und Schlaf in Health selbst.
struct TrainingSeite: View {
    let oeffnen: (HealthZiel) -> Void

    @State private var zieleOffen = false
    @State private var zeigtKonfetti = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EnergieKarte()
                TrainingKarte(oeffnen: oeffnen)
                LaufendeChallengesCard()
            }
            .padding(16)
        }
        .navigationTitle("Training")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { oeffnen(.punkte) } label: {
                    PunkteKnopf(person: Raum.shared.ich ?? .ahmed)
                }
                .buttonStyle(.federnd)
                .accessibilityHint("Zeigt, wofür es Punkte gab")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Ziele ändern", systemImage: "target") { zieleOffen = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Mehr")
            }
        }
        .sheet(isPresented: $zieleOffen) { ZieleAendernView() }
        .onAppear {
            HealthModell.shared.sicherstellen()
            pruefeKonfetti()
        }
        .onChange(of: PunkteModell.shared.stand) { _, _ in pruefeKonfetti() }
        .overlay {
            if zeigtKonfetti { SpielKonfetti() }
        }
    }

    /// Feiert einen frisch abgeschlossenen Duell-/Gemeinsam-/Serien-Meilenstein genau einmal
    /// (`ChallengeKonfetti`, Z-22.2) — beim Öffnen und bei jeder Punktestand-Änderung.
    private func pruefeKonfetti() {
        guard ChallengeKonfetti.neuAbgeschlossen() else { return }
        zeigtKonfetti = true
        Task {
            try? await Task.sleep(for: .seconds(5))
            zeigtKonfetti = false
        }
    }
}

/// Schritte (Kachel in Health): beide mit Ringen, Tipp öffnet die Tagesansicht der Person, darunter die Woche.
struct SchritteUebersicht: View {
    let oeffnen: (HealthZiel) -> Void
    @Namespace private var zoom

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SchritteKarte(zoom: zoom, oeffnen: oeffnen)
                SchritteWocheKarte()
            }
            .padding(16)
        }
        .navigationTitle("Schritte")
    }
}
