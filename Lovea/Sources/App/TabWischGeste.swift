import SwiftUI
import UIKit

extension View {
    /// R6 (Ahmed, 01.10.): links/rechts zum Nachbar-Tab wischen, animiert mit Haptik wie bei
    /// Snapchat/Instagram. Nur an der Wurzel-Ansicht eines Tabs anhängen (siehe `TabWischLogik`
    /// für die Randsperre) — auf einem gepushten Screen ist derselbe Rand-Wisch "zurück" und diese
    /// Geste hängt dort gar nicht erst, weil der Root dann nicht sichtbar/getroffen wird.
    /// `vorheriger`/`naechster` sind die `AppTab`-Rohwerte der Nachbartabs, `nil` am jeweiligen Rand.
    /// `simultaneousGesture` statt `gesture`: blockiert nie das System-Zurück-Wischen (siehe
    /// `ZurueckWischenUeberall.swift`), eigene Wisch-Gesten im Inhalt (Wochenstreifen, Kalender)
    /// laufen unverändert weiter — bei einem seltenen, schnellen > 60-pt-Wisch genau dort können
    /// beide zugleich feuern, wie beim bestehenden Rand-Wisch-Fall in `MonatsAnsicht`.
    func tabWischen(vorheriger: String?, naechster: String?) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { wert in
                    let breite = UIScreen.main.bounds.width
                    guard let richtung = TabWischLogik.richtung(
                        dx: wert.translation.width, dy: wert.translation.height,
                        startX: wert.startLocation.x, breite: breite
                    ) else { return }
                    guard let ziel = richtung == .naechsterTab ? naechster : vorheriger else { return }
                    Haptik.auswahl()
                    AppNavigation.shared.tabWunsch = ziel
                }
        )
    }
}
