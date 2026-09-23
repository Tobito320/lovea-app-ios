import SwiftUI
import UIKit

/// Z-27.1: "Gute Nacht"/"Guten Morgen" button on Home. Sends `gruss`, own figure sleeps/wakes
/// (`FigurenModell.anzeige`), partner gets a sweet push (server `regeln.js`).
struct GrussKnopfCard: View {
    // NOT `anzeige(ich).haupt == .schlaeft` — that's also true from Sleep Focus (22-7 Uhr,
    // `Anwesenheit`) or a fresh geste echo, so the button would flip to "Guten Morgen" while
    // actually asleep from Focus, or briefly after any geste. Read the manual override directly.
    private var schlaeft: Bool {
        guard let ich = Raum.shared.ich, let bis = FigurenModell.shared.grussSchlaeft[ich] else { return false }
        return bis > Date()
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            FigurenModell.shared.grussSenden(schlaeft ? "morgen" : "nacht")
        } label: {
            Label(schlaeft ? "Guten Morgen" : "Gute Nacht", systemImage: schlaeft ? "sun.max.fill" : "moon.stars.fill")
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .tint(schlaeft ? .orange : .indigo)
    }
}
