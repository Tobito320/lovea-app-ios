import SwiftUI
import UIKit

/// Z-31.1: one spring set for the whole app (Spec 9). `schnell` answers a touch, `weich` carries
/// transitions, `federnd` is for moments of joy. Under Reduce Motion callers crossfade instead.
enum Feder {
    static let schnell: Animation = .snappy(duration: 0.28)
    static let weich: Animation = .smooth(duration: 0.38)
    static let federnd: Animation = .bouncy(duration: 0.42, extraBounce: 0.12)
}

/// Buttons give way while pressed (scale 0.96). Reduce Motion: no scale, a dimmed crossfade instead,
/// so a custom button still has a press state (HIG buttons.md).
struct FederKnopfStil: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SpringButtonBody(configuration: configuration)
    }
}

@MainActor
extension ButtonStyle where Self == FederKnopfStil {
    static var federnd: FederKnopfStil { FederKnopfStil() }
}

private struct SpringButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.6 : 1)
            .animation(Feder.schnell, value: configuration.isPressed)
    }
}

/// Haptics with a fixed meaning (Spec 9): send = leicht, reaction = mittel, habit done = erfolg,
/// bars/pickers = auswahl, error = warnung. Every signal checks the "Haptik" switch first.
@MainActor
enum Haptik {
    /// Local to the device, no op (Zielplan "Schnittstellen"). The settings toggle binds the same key.
    static var an: Bool {
        get { UserDefaults.standard.object(forKey: "lovea.haptik") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "lovea.haptik") }
    }

    static func leicht() { if an { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    static func mittel() { if an { UIImpactFeedbackGenerator(style: .medium).impactOccurred() } }
    static func erfolg() { if an { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func auswahl() { if an { UISelectionFeedbackGenerator().selectionChanged() } }
    static func warnung() { if an { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }
}
