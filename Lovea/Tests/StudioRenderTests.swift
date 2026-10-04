import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel "gym-studio": Studio-Zeile (FitX, Absolut Fit) und Öffnungs-Warnkarte.
@MainActor
final class StudioRenderTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private func zelle(_ schema: ColorScheme, titel: String, _ inhalt: some View) -> Zelle {
        let ansicht = inhalt
            .padding(18)
            .frame(width: 393, alignment: .top)
            .background(schema == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, schema)
        return (titel: titel, ansicht: AnyView(ansicht))
    }

    func testStudioTafel() {
        let ahmed = VStack(spacing: 12) {
            StudioKopf(studio: .fitxHagenMitte, slotStart: 5 * 60, dauer: 45)
        }
        let w = GymOeffnung.warnungen(.absolutFit, wochentage: [1, 3, 6], start: 5 * 60, dauer: 45)
        let annika = VStack(spacing: 12) {
            StudioKopf(studio: .absolutFit, slotStart: 5 * 60, dauer: 45)
            OeffnungsWarnKarte(studio: .absolutFit, zeilen: GymOeffnung.zeilen(w))
        }
        let ohne = VStack(spacing: 12) {
            StudioKopf(studio: .absolutFit, slotStart: nil, dauer: 45)
            OeffnungsWarnKarte(studio: .absolutFit, zeilen: ["Sa, So: öffnet erst um 09:00"])
        }
        RenderTafel.speichern("gym-studio", spalten: 3, zellen: [
            zelle(.light, titel: "Ahmed, FitX, hell (keine Warnung)", ahmed),
            zelle(.light, titel: "Absolut Fit, Slot 05:00, hell", annika),
            zelle(.dark, titel: "Absolut Fit, ohne Uhrzeit, dunkel", ohne),
        ])
    }
}
