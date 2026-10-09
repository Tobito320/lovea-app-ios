import SwiftUI
import XCTest
@testable import Lovea

/// p47: Tafeln `shop-annika.png` und `shop-ahmed.png` (Artefakt render-galerie): die Kategorie-Leiste
/// mit den drei Gruppen und jede Kachel des aufgeräumten Katalogs, so wie sie im Shop-Gitter stehen.
@MainActor
final class ShopRenderTests: XCTestCase {
    private func katalog() throws -> [ShopArtikel] {
        let bundle = Bundle(for: FigurenModell.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "katalog", withExtension: "json")
                ?? bundle.url(forResource: "katalog", withExtension: "json", subdirectory: "Shop")
        )
        return try JSONDecoder().decode([ShopArtikel].self, from: try Data(contentsOf: url))
    }

    func testShopHatVierGruppenOhnePoseUndTanz() {
        XCTAssertEqual(ShopKategorie.allCases.map(\.titel), ["Mode", "Schmuck", "Taschen", "Haustiere", "Zimmer"])
        XCTAssertFalse(ShopKategorie.allCases.contains { $0.titel.contains("Pose") || $0.titel.contains("Tänze") })
    }

    func testShopTafeln() throws {
        let alle = try katalog()
        for (name, person) in [("shop-annika", Person.annika), ("shop-ahmed", Person.ahmed)] {
            let leiste = HStack(spacing: 8) {
                ForEach(ShopKategorie.allCases) { k in
                    Label(k.titel, systemImage: k.symbol)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(k == .mode ? Color.loveaRose.opacity(0.18) : Color(uiColor: .secondarySystemBackground)))
                        .foregroundStyle(k == .mode ? Color.loveaRose : Color.primary)
                }
            }
            var zellen: [(titel: String, ansicht: AnyView)] = [(titel: "Kategorie-Leiste", ansicht: AnyView(leiste))]
            for k in ShopKategorie.allCases {
                for a in alle where a.kategorie == k.rawValue && a.sichtbar(fuer: person) {
                    let kachel = ArtikelKachel(artikel: a, besitzt: false, vorschauAussehen: FigurAussehen.standard(for: person).mitVorschau(a))
                    zellen.append((titel: "\(k.titel): \(a.name)", ansicht: AnyView(kachel)))
                }
            }
            XCTAssertGreaterThan(zellen.count, 10, name)
            RenderTafel.speichern(name, spalten: 5, zellen: zellen)
        }
    }
}
