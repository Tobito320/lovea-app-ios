import SwiftUI
import UIKit

/// One vocabulary for chat haptics (Block 18), so the same action always feels the same.
/// Z-31.1: routed through `Haptik`, so the "Haptik" switch silences the chat too.
@MainActor
enum ChatHaptik {
    static func leicht() { Haptik.leicht() }
    static func mittel() { Haptik.mittel() }
    static func weich() { if Haptik.an { UIImpactFeedbackGenerator(style: .soft).impactOccurred() } }
    static func auswahl() { Haptik.auswahl() }
}

@MainActor
enum ChatTastatur {
    static func schliessen() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// R7: whether a visible-height change in the message list should re-pin it to the bottom.
/// `onScrollGeometryChange` fires for every height change — including every frame of an
/// interactive keyboard dismiss drag (`.scrollDismissesKeyboard(.interactively)` shrinks/grows
/// the keyboard inset as the finger moves). Re-pinning during that drag fights the user's own
/// gesture, which is the glitch Ahmed described. Only a real size change (input bar growing,
/// keyboard opening non-interactively) while already at the bottom — and not mid-drag — should
/// jump back down.
enum ListenAutoScroll {
    static func sollNachUntenSpringen(sichtbarGeaendert: Bool, warAmEnde: Bool, nutzerZiehtGerade: Bool) -> Bool {
        sichtbarGeaendert && warAmEnde && !nutzerZiehtGerade
    }
}

extension View {
    /// Swipe down over non-scrolling chrome (header, pinned bar, input bar) closes the keyboard.
    /// The message list itself uses `.scrollDismissesKeyboard(.interactively)` instead.
    func tastaturWischen() -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 16).onEnded { wert in
                if wert.translation.height > 30, wert.translation.height > abs(wert.translation.width) { ChatTastatur.schliessen() }
            }
        )
    }
}
