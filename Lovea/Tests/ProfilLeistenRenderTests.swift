import SwiftUI
import XCTest
@testable import Lovea

/// p69: the strips under the profile scene as still pictures: the four tabs of the part that
/// scrolls and the cards, at normal and at huge text. The very views the app shows (`ProfilReiterLeiste`, `ProfilKlappKarte`); `ImageRenderer` cannot draw a scroll view, so a strip that is too
/// wide for its row and slides sideways in the app shows only its first look here.
@MainActor
final class ProfilLeistenRenderTests: XCTestCase {
    private func rahmen<V: View>(_ breite: CGFloat, _ schrift: DynamicTypeSize, _ inhalt: V) -> AnyView {
        AnyView(
            inhalt
                .environment(\.dynamicTypeSize, schrift)
                .frame(width: breite)
                .background(Color(uiColor: .systemGroupedBackground))
                .overlay(alignment: .bottom) { Rectangle().fill(Color.red.opacity(0.5)).frame(height: 0.5) }
        )
    }

    private func reiter(_ liste: [ProfilReiter], _ breite: CGFloat, _ schrift: DynamicTypeSize) -> AnyView {
        rahmen(breite, schrift, ProfilReiterLeiste(reiter: liste, aktiv: liste.first) { _ in })
    }

    private func karte(offen: Bool) -> AnyView {
        rahmen(390, .large, ProfilKlappKarte(titel: "Wir", offen: .constant(offen)) {
            AnyView(VStack(alignment: .leading, spacing: 8) {
                Text("An dich gedacht: 12 mal").font(.body)
                Text("Kennengelernt am 04.07.2026").font(.subheadline).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading))
        }
        .padding(16))
    }

    func testLeistenUnterDerSzene() {
        let alle = ProfilReiter.allCases
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Reiter 390 pt, vier Reiter, normal", ansicht: reiter(alle, 390, .large)),
            (titel: "Reiter 390 pt, kleine Schrift", ansicht: reiter(alle, 390, .xSmall)),
            (titel: "Reiter 390 pt, zwei Reiter (Partner ohne Erinnerungen und Quests)", ansicht: reiter([.zimmer, .wir], 390, .large)),
            (titel: "Reiter 390 pt, ganz grosse Schrift: rutscht seitlich (hier nur der Anfang)", ansicht: reiter(alle, 390, .accessibility3)),
            (titel: "Karte zu", ansicht: karte(offen: false)),
            (titel: "Karte offen", ansicht: karte(offen: true)),
        ]
        RenderTafel.speichern("p69-leisten-unter-der-szene", spalten: 1, zellen: zellen)
    }
}
