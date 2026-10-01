import Observation
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

/// "Chat-Tempo (Test)": the switch in the settings (default on, off = the old behaviour) and the
/// flag "the message list is moving". While it moves, the main thread only scrolls: the particle
/// backdrop pauses, the live figures draw slower and GIFs hold still. Read it only in those leaf
/// views, never in the list, so a flip re-renders nothing else.
@MainActor
@Observable
final class ChatTempo {
    static let shared = ChatTempo()
    nonisolated static let schluessel = "lovea.chat.tempo"
    /// Frame rate of the live figures while the list moves.
    nonisolated static let bildrateImScrollen = 10.0

    /// Local to the device, no op. Same pattern as `Haptik.an`; the settings toggle binds the same key.
    nonisolated static var an: Bool { UserDefaults.standard.object(forKey: schluessel) as? Bool ?? true }

    private(set) var scrollt = false

    func phase(_ phase: ScrollPhase) {
        let neu = Self.scrolltBei(phase)
        if neu != scrollt { scrollt = neu }
    }

    func zuruecksetzen() { scrollt = false }

    /// True while the list is dragged, flung or scrolled by code; only `.idle` is rest.
    nonisolated static func scrolltBei(_ phase: ScrollPhase) -> Bool { phase != .idle }

    /// Frame rate for a live figure: the normal one, slower while the list moves (switch on).
    nonisolated static func bildrate(normal: Double, an: Bool, scrollt: Bool) -> Double {
        an && scrollt ? min(normal, bildrateImScrollen) : normal
    }

    /// Reading `scrollt` here registers the caller for changes; with the switch off nothing is read.
    static func pausiert() -> Bool { an && shared.scrollt }
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
