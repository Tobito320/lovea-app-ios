import SwiftUI

/// Platzhalter für den Health-Tab (Z-19.1). Block 21 füllt Ringe, Habits, Verlauf usw.
struct HealthTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Health", systemImage: "heart.text.square")
                .navigationTitle("Health")
        }
    }
}
