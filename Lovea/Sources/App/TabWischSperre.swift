import SwiftUI
import UIKit

/// Wer gewinnt, wenn eine Berührung horizontal wischt: der Tab-Wisch oder etwas Inneres?
/// Frueher: Zeitfenster-Anspruch (0.3 s), den nur 5 von rund 15 horizontalen Bereichen gemeldet
/// haben -- alle anderen (Chips, Karten, Leisten) scrollten UND wechselten den Tab, und Bereiche,
/// die am Anschlag standen, blockierten den Tab-Wechsel trotzdem. Jetzt entscheidet die Struktur
/// beim Start der Berührung, ohne Uhr und ohne Meldepflicht:
/// 1. Liegt unter dem Finger eine horizontal scrollende `UIScrollView` (SwiftUI-`ScrollView`,
///    Panorama, `TabView(.page)`), die in Wischrichtung noch scrollen kann, gehört ihr die Berührung.
///    Steht sie am Anschlag (oder hat nichts zu scrollen), wechselt der Tab.
/// 2. Eigene horizontale Gesten ohne `UIScrollView` (Wegwischen, Wochenstreifen, Halten-zum-
///    Aufnehmen) markieren ihren Bereich mit `.tabWischSperre()`.
@MainActor
final class TabWischSperre {
    static let shared = TabWischSperre()
    private let marken = NSHashTable<UIView>.weakObjects()
    private init() {}

    /// Alt: Aufrufer in `Profile/` melden noch per Zeitfenster. Ihre Bereiche sind ScrollViews und
    /// werden jetzt strukturell erkannt; der Aufruf bleibt wirkungslos, bis dort aufgeräumt wird.
    func beanspruchen() {}

    func anmelden(_ marke: UIView) { marken.add(marke) }

    /// `punkt` in Fensterkoordinaten. Die Geometrie wird erst jetzt abgefragt (kein Mitrechnen beim Scrollen).
    func istMarkiert(bei punkt: CGPoint) -> Bool {
        marken.allObjects.contains { $0.window != nil && $0.convert($0.bounds, to: nil).contains(punkt) }
    }

    /// Gehört die Berührung bei `punkt` (Fensterkoordinaten) einem inneren Bereich, der in
    /// Fingerrichtung etwas damit anfangen kann? `wurzel` ist die View, an der die Geste hängt.
    func innenBelegt(wurzel: UIView, punkt: CGPoint, fingerNachLinks: Bool) -> Bool {
        if istMarkiert(bei: punkt) { return true }
        var aktuell: UIView? = wurzel.hitTest(wurzel.convert(punkt, from: nil), with: nil)
        while let view = aktuell, view !== wurzel {
            if let scroll = view as? UIScrollView, scroll.isScrollEnabled,
               TabWischLogik.kannHorizontalScrollen(
                    offset: scroll.contentOffset.x, inhalt: scroll.contentSize.width, sicht: scroll.bounds.width,
                    insetLinks: scroll.adjustedContentInset.left, insetRechts: scroll.adjustedContentInset.right,
                    fingerNachLinks: fingerNachLinks) {
                return true
            }
            if view is UISlider || view is UIPickerView || view is UIDatePicker { return true }
            aktuell = view.superview
        }
        return false
    }
}

/// Unsichtbare Marke im Hintergrund eines Bereichs, der horizontale Berührungen selbst auswertet.
private struct TabWischSperrMarke: UIViewRepresentable {
    func makeUIView(context: Context) -> MarkeView { MarkeView() }
    func updateUIView(_ uiView: MarkeView, context: Context) {}

    final class MarkeView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { TabWischSperre.shared.anmelden(self) }
        }
    }
}

extension View {
    /// Dieser Bereich wertet horizontale Wischer selbst aus: der Tab-Wisch beginnt hier nicht.
    func tabWischSperre() -> some View {
        background(TabWischSperrMarke())
    }
}
