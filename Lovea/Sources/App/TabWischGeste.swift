import SwiftUI
import UIKit

/// Merkt sich den Startpunkt der Berührung (Fensterkoordinaten); beim Beginn der Geste ist der
/// Finger schon ein Stück weitergewandert.
final class TabWischPanErkenner: UIPanGestureRecognizer {
    private(set) var startImFenster: CGPoint = .zero
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if let touch = touches.first { startImFenster = touch.location(in: nil) }
    }
}

/// UIKit-Pan statt SwiftUI-`DragGesture`: nur so lässt sich beim Start entscheiden, ob eine innere
/// Scroll-Fläche die Berührung bekommt (`gestureRecognizerShouldBegin`). Eine `DragGesture` feuert
/// immer mit und kann nur nachträglich zurückrudern.
private struct TabWischPan: UIGestureRecognizerRepresentable {
    let fensterBreite: () -> CGFloat
    let geaendert: @MainActor (CGFloat) -> Void
    let beendet: @MainActor (_ translation: CGPoint, _ geschwindigkeit: CGPoint, _ startX: CGFloat) -> Void
    let abgebrochen: @MainActor () -> Void

    @MainActor
    final class Koordinator: NSObject, UIGestureRecognizerDelegate {
        var fensterBreite: () -> CGFloat = { 0 }

        func gestureRecognizerShouldBegin(_ erkenner: UIGestureRecognizer) -> Bool {
            guard let pan = erkenner as? TabWischPanErkenner, let wurzel = pan.view else { return false }
            let v = pan.velocity(in: nil)
            let start = pan.startImFenster
            let belegt = TabWischSperre.shared.innenBelegt(wurzel: wurzel, punkt: start, fingerNachLinks: v.x < 0)
            return TabWischLogik.darfBeginnen(
                vx: v.x, vy: v.y, startX: start.x, breite: fensterBreite(),
                aktiv: TabWischLogik.aktiv(), innenBelegt: belegt)
        }

        /// Senkrechtes Scrollen und Taps laufen unverändert weiter.
        func gestureRecognizer(_ a: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith b: UIGestureRecognizer) -> Bool { true }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Koordinator { Koordinator() }

    func makeUIGestureRecognizer(context: Context) -> TabWischPanErkenner {
        let pan = TabWischPanErkenner()
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        context.coordinator.fensterBreite = fensterBreite
        return pan
    }

    func updateUIGestureRecognizer(_ erkenner: TabWischPanErkenner, context: Context) {
        context.coordinator.fensterBreite = fensterBreite
    }

    func handleUIGestureRecognizerAction(_ erkenner: TabWischPanErkenner, context: Context) {
        let t = erkenner.translation(in: nil)
        switch erkenner.state {
        case .began, .changed: geaendert(t.x)
        case .ended: beendet(t, erkenner.velocity(in: nil), erkenner.startImFenster.x)
        case .cancelled, .failed: abgebrochen()
        default: break
        }
    }
}

/// R6: links/rechts zum Nachbar-Tab wischen, animiert mit Haptik wie bei Snapchat/Instagram.
private struct TabWischModifier: ViewModifier {
    let vorheriger: String?
    let naechster: String?
    /// Echte Breite des Containers statt `UIScreen.main.bounds` (Split View/Stage Manager auf iPad).
    @State private var breite: CGFloat = UIScreen.main.bounds.width
    /// Auslenkung des Inhalts während des Wischens: der Inhalt folgt dem Finger 1:1.
    @State private var versatz: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(x: versatz)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { breite = $0 }
            // Neuer Tab nach einem Wisch: startet dort, wo der Finger den alten losgelassen hat
            // (am Rand daneben) und federt in die Mitte. Sonst (Tab-Leiste, Deep Link) steht er mittig;
            // das setzt auch den Versatz zurück, den dieser Tab beim Wegwischen behalten hat.
            .onAppear {
                guard let start = AppNavigation.shared.wischEinflug else { versatz = 0; return }
                AppNavigation.shared.wischEinflug = nil
                guard !reduceMotion else { versatz = 0; return }
                versatz = start
                withAnimation(Feder.wisch) { versatz = 0 }
            }
            // Ob die Geste beginnt, entscheidet `TabWischSperre` beim Start der Berührung (innere
            // Scroll-Flächen gewinnen nur, wenn sie in Wischrichtung scrollen können). Die Geste ist
            // gleichzeitig mit allem anderen erlaubt, damit sie nie das System-Zurück-Wischen
            // (`ZurueckWischenUeberall.swift`) oder senkrechtes Scrollen blockiert.
            .gesture(TabWischPan(
                fensterBreite: { breite },
                geaendert: { dx in
                    guard !reduceMotion else { return }
                    let hatZiel = (dx < 0 ? naechster : vorheriger) != nil
                    // Ohne Nachbar-Tab (Rand der Leiste): gummiartiger Widerstand.
                    versatz = hatZiel ? dx : dx * 0.25
                },
                beendet: { translation, geschwindigkeit, startX in
                    let aktuell = versatz
                    guard let richtung = TabWischLogik.richtung(
                        dx: translation.x + geschwindigkeit.x * 0.1, dy: translation.y,
                        startX: startX, breite: breite, aktiv: TabWischLogik.aktiv()
                    ), let ziel = richtung == .naechsterTab ? naechster : vorheriger else {
                        if versatz != 0 { withAnimation(Feder.wisch) { versatz = 0 } }
                        return
                    }
                    Haptik.auswahl()
                    if !reduceMotion {
                        // Der Nachbar schließt an die Fingerposition an: links gewischt = von rechts.
                        AppNavigation.shared.wischEinflug = aktuell + (richtung == .naechsterTab ? breite : -breite)
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.6))
                            AppNavigation.shared.wischEinflug = nil
                        }
                    }
                    // Der Versatz bleibt stehen (kein Zurückspringen vor dem Wechsel); `onAppear` setzt ihn zurück.
                    AppNavigation.shared.tabWunsch = ziel
                },
                abgebrochen: {
                    if versatz != 0 { withAnimation(Feder.wisch) { versatz = 0 } }
                }
            ))
    }
}

extension View {
    /// `vorheriger`/`naechster` sind die `AppTab`-Rohwerte der Nachbartabs, `nil` am jeweiligen Rand.
    func tabWischen(vorheriger: String?, naechster: String?) -> some View {
        modifier(TabWischModifier(vorheriger: vorheriger, naechster: naechster))
    }
}
