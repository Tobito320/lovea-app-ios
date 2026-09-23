import SwiftUI

/// Block 21/22: Health-Tab — Ahmed-vs-Annika-Ringe, laufende Challenges, Habits Heute, Schlaf,
/// Habit-Historie über die einzelnen Zeilen, "…"-Menü (vergangene Tage, Ziele) und Punkte.
struct HealthTab: View {
    @State private var blatt: HealthBlatt?
    @State private var zeigtKonfetti = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    kopf
                    VerlaufCard()
                    LaufendeChallengesCard()
                    HabitsHeuteCard()
                    SchlafCard()
                }
                .padding(16)
            }
            .navigationTitle("Health")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Vergangene Tage markieren") { blatt = .vergangeneTage }
                        Button("Ziele ändern") { blatt = .ziele }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Mehr")
                }
            }
            .sheet(item: $blatt) { b in
                switch b {
                case .vergangeneTage: VergangeneTageView()
                case .ziele: ZieleAendernView()
                }
            }
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

    private var kopf: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Ahmed vs. Annika").font(.headline)
                Spacer()
                PunkteChip(person: Raum.shared.ich ?? .ahmed)
            }
            HStack(spacing: 28) {
                SchritteRing(person: .ahmed)
                SchritteRing(person: .annika)
            }
            .frame(maxWidth: .infinity)
            NavigationLink("Wofür?") { PunkteVerlaufView() }
                .font(.caption.weight(.semibold))
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

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

private enum HealthBlatt: String, Identifiable {
    case vergangeneTage, ziele
    var id: String { rawValue }
}
