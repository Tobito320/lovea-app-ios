import SwiftUI
import UIKit

/// Z-27.1: "Gute Nacht"/"Guten Morgen" button on Home. Sends `gruss`, own figure sleeps/wakes
/// (`FigurenModell.anzeige`), partner gets a sweet push (server `regeln.js`).
struct GrussKnopfCard: View {
    private var schlaeft: Bool {
        guard let ich = Raum.shared.ich else { return false }
        return FigurenModell.shared.anzeige(ich).haupt == .schlaeft
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
