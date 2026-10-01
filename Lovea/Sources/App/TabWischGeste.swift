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

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { breite = $0 }
            // Nur an der Wurzel-Inhalts-View eines Tabs anhängen (siehe `TabWischLogik` für die
            // Randsperre) — auf einem gepushten Screen ist derselbe Rand-Wisch "zurück" und diese
            // Geste hängt dort gar nicht erst, weil der Root dann nicht sichtbar/getroffen wird.
            // `simultaneousGesture` statt `gesture`: blockiert nie das System-Zurück-Wischen (siehe
            // `ZurueckWischenUeberall.swift`). Eigene horizontale Gesten im Inhalt (Wochenstreifen,
            // Kalendermonat, Pünktlich-Karte) beanspruchen die Berührung über `TabWischSperre` —
            // gewinnen sie, bleibt der Tab unverändert (Review 01.10.: beide feuerten vorher zugleich).
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onEnded { wert in
                        guard let richtung = TabWischLogik.richtung(
                            dx: wert.translation.width, dy: wert.translation.height,
                            startX: wert.startLocation.x, breite: breite,
                            beansprucht: TabWischSperre.shared.istBeansprucht
                        ) else { return }
                        guard let ziel = richtung == .naechsterTab ? naechster : vorheriger else { return }
                        Haptik.auswahl()
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
