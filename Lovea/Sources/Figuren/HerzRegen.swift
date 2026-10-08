import SwiftUI

/// Herzregen über der App, wenn ein "Denk an dich" ankommt oder gesendet wird (`FigurenModell.herzEreignis`).
/// Nutzt `SteigendeHerzen` aus dem Kuss-Paar, fasst nichts an und räumt sich nach 3 Sekunden weg.
struct HerzRegen: View {
    @State private var zeigen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack { if zeigen { SteigendeHerzen() } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: FigurenModell.shared.herzEreignis) {
                guard FigurenModell.shared.herzEreignis > 0, !reduceMotion else { return }
                zeigen = true
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { zeigen = false }
            }
    }
}
