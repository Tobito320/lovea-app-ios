import SwiftUI
import UIKit

/// R6 (Ahmed, 01.10.; Fix nach Review): links/rechts zum Nachbar-Tab wischen, animiert mit Haptik
/// wie bei Snapchat/Instagram.
private struct TabWischModifier: ViewModifier {
    let vorheriger: String?
    let naechster: String?
    /// Echte Breite des Containers statt `UIScreen.main.bounds` (Review-Minor: bricht sonst bei
    /// Split View/Stage Manager auf iPad, `.sidebarAdaptable` deutet auf iPad-Unterstützung hin).
    /// Startwert: Haupt-Bildschirmbreite, bis die erste Geometrie ankommt.
    @State private var breite: CGFloat = UIScreen.main.bounds.width
    /// Auslenkung des Inhalts während des Wischens: der Inhalt folgt dem Finger 1:1.
    @State private var versatz: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(x: versatz)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { breite = $0 }
            // Neuer Tab nach einem Wisch: startet dort, wo der Finger den alten losgelassen hat
            // (am Rand daneben) und federt in die Mitte. Fehlt der Einflug, bleibt alles wie vorher.
            .onAppear {
                guard let start = AppNavigation.shared.wischEinflug else { return }
                AppNavigation.shared.wischEinflug = nil
                guard !reduceMotion else { return }
                versatz = start
                withAnimation(Feder.wisch) { versatz = 0 }
            }
            // Nur an der Wurzel-Inhalts-View eines Tabs anhängen (siehe `TabWischLogik` für die
            // Randsperre) — auf einem gepushten Screen ist derselbe Rand-Wisch "zurück" und diese
            // Geste hängt dort gar nicht erst, weil der Root dann nicht sichtbar/getroffen wird.
            // `simultaneousGesture` statt `gesture`: blockiert nie das System-Zurück-Wischen (siehe
            // `ZurueckWischenUeberall.swift`). Eigene horizontale Gesten im Inhalt (Wochenstreifen,
            // Kalendermonat, Pünktlich-Karte) beanspruchen die Berührung über `TabWischSperre` —
            // gewinnen sie, bleibt der Tab unverändert (Review 01.10.: beide feuerten vorher zugleich).
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onChanged { wert in
                        guard !reduceMotion else { return }
                        let dx = wert.translation.width
                        let frei = !TabWischSperre.shared.istBeansprucht
                            && TabWischLogik.aktiv()
                            && wert.startLocation.x > TabWischLogik.randAbstand
                            && wert.startLocation.x < breite - TabWischLogik.randAbstand
                            && abs(dx) > 2 * abs(wert.translation.height)
                        guard frei else {
                            if versatz != 0 { withAnimation(Feder.wisch) { versatz = 0 } }
                            return
                        }
                        let hatZiel = (dx < 0 ? naechster : vorheriger) != nil
                        // Ohne Nachbar-Tab (Rand der Leiste): gummiartiger Widerstand.
                        versatz = hatZiel ? dx : dx * 0.25
                    }
                    .onEnded { wert in
                        let aktuell = versatz
                        guard let richtung = TabWischLogik.richtung(
                            dx: wert.predictedEndTranslation.width, dy: wert.translation.height,
                            startX: wert.startLocation.x, breite: breite,
                            beansprucht: TabWischSperre.shared.istBeansprucht,
                            aktiv: TabWischLogik.aktiv()
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
                        versatz = 0
                        AppNavigation.shared.tabWunsch = ziel
                    }
            )
    }
}

extension View {
    /// `vorheriger`/`naechster` sind die `AppTab`-Rohwerte der Nachbartabs, `nil` am jeweiligen Rand.
    func tabWischen(vorheriger: String?, naechster: String?) -> some View {
        modifier(TabWischModifier(vorheriger: vorheriger, naechster: naechster))
    }
}
