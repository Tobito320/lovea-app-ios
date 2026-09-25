import SwiftUI

/// Where the Health tab navigates; also the zoom source id of the tile or ring it came from.
enum HealthZiel: Hashable {
    case habit(String), schritte(Person), schritteVergleich, punkte
    case trainingsPlan(Person), gymSession(String), gymVerlauf
}

/// Spec 3.1, HabitLink style: date eyebrow and "Health", the points chip with the Lovea coin, step
/// duel, week, habits, challenges and sleep. Tiles and rings zoom into their detail.
struct HealthTab: View {
    @State private var pfad: [HealthZiel] = []
    @State private var zieleOffen = false
    @State private var zeigtKonfetti = false
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    kopf
                    TrainingKarte(oeffnen: oeffnen)
                    SchritteKarte(zoom: zoom, oeffnen: oeffnen)
                    SchritteWocheKarte()
                    HabitsSektion(zoom: zoom, oeffnen: oeffnen)
                    LaufendeChallengesCard()
                    SchlafCard()
                }
                .padding(16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HealthZiel.self) { ziel in
                ansicht(ziel).navigationTransition(.zoom(sourceID: ziel, in: zoom))
            }
            .sheet(isPresented: $zieleOffen) { ZieleAendernView() }
        }
        .onAppear {
            HealthModell.shared.sicherstellen()
            pruefeKonfetti()
        }
        .onChange(of: PunkteModell.shared.stand) { _, _ in pruefeKonfetti() }
        .overlay {
            if zeigtKonfetti { SpielKonfetti() }
        }
    }

    /// "MITTWOCH, 23. SEPTEMBER" above a large "Health", points chip and goals menu on the right.
    private var kopf: some View {
        HStack(alignment: .center, spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Datum.anzeige(Datum.text(Date())).uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Health").font(.largeTitle.bold())
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Button { oeffnen(.punkte) } label: {
                PunkteKnopf(person: Raum.shared.ich ?? .ahmed).frame(minHeight: 44)
            }
            .buttonStyle(.federnd)
            .matchedTransitionSource(id: HealthZiel.punkte, in: zoom)
            .accessibilityHint("Zeigt, wofür es Punkte gab")
            Menu {
                Button("Ziele ändern", systemImage: "target") { zieleOffen = true }
            } label: {
                Image(systemName: "ellipsis").font(.body.weight(.semibold)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Mehr")
        }
    }

    @ViewBuilder
    private func ansicht(_ ziel: HealthZiel) -> some View {
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

    private func oeffnen(_ ziel: HealthZiel) { pfad.append(ziel) }

    /// Feiert einen frisch abgeschlossenen Duell-/Gemeinsam-/Serien-Meilenstein genau einmal
    /// (`ChallengeKonfetti`, Z-22.2) — ausgelöst beim Öffnen des Tabs und bei jeder Punktestand-Änderung.
    private func pruefeKonfetti() {
        guard ChallengeKonfetti.neuAbgeschlossen() else { return }
        zeigtKonfetti = true
        Task {
            try? await Task.sleep(for: .seconds(5))
            zeigtKonfetti = false
        }
    }
}
