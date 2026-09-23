import SwiftUI
import UIKit

/// One vocabulary for chat haptics (Block 18), so the same action always feels the same.
@MainActor
enum ChatHaptik {
    static func leicht() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func mittel() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func weich() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func auswahl() { UISelectionFeedbackGenerator().selectionChanged() }
}

@MainActor
enum ChatTastatur {
    static func schliessen() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
