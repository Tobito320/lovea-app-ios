import SwiftUI
import XCTest
@testable import Lovea

/// Render board "ernaehrung": the pure `TagebuchAnsicht` in fixed states — goals not set up and empty,
/// half a day with breakfast and lunch, over the goal with fasting running, and the partner's read-only
/// view. Light and dark, no singletons.
@MainActor
final class RenderGalerieErnaehrungTests: XCTestCase {
    private let heute = "2026-09-26"
    private var jetzt: Date { Datum.datum(heute).addingTimeInterval(19 * 3600) }

    private func zelle(_ titel: String, _ ansicht: some View, _ schema: ColorScheme = .light, breite: CGFloat = 390) -> (titel: String, ansicht: AnyView) {
        (titel, AnyView(ansicht.frame(width: breite).padding(12).background(Color(uiColor: .systemGroupedBackground)).environment(\.colorScheme, schema)))
    }

    private func lebensmittel(_ id: String, _ name: String, kcal: Double, protein: Double, kh: Double, fett: Double) -> Lebensmittel {
        Lebensmittel(id: id, name: name, pro100: Naehrwerte(kcal: kcal, protein: protein, kohlenhydrate: kh, fett: fett))
    }

    private func eintrag(_ id: String, _ m: Mahlzeit, _ l: Lebensmittel, menge: Double) -> EssenEintrag {
        EssenEintrag(id: id, datum: heute, mahlzeit: m, menge: menge, einheit: .g, lebensmittel: l, geloescht: nil)
    }

    private func ziele(kcal: Int, protein: Int, kh: Int, fett: Int, fasten: Int = 0) -> ErnaehrungsZiele {
        var z = ErnaehrungsZiele()
        z.eingerichtet = true
        z.kcal = kcal
        z.protein = protein
        z.kohlenhydrate = kh
        z.fett = fett
        z.fastenStunden = fasten
        return z
    }

    func testTagebuchAnsicht() {
        let hafer = lebensmittel("eigen-hafer", "Haferflocken mit Milch", kcal: 120, protein: 5, kh: 18, fett: 3)
        let huehnerReis = lebensmittel("eigen-huehner", "Hähnchen mit Reis", kcal: 160, protein: 14, kh: 18, fett: 4)
        let burger = lebensmittel("eigen-burger", "Cheeseburger", kcal: 280, protein: 14, kh: 22, fett: 15)
        let pommes = lebensmittel("eigen-pommes", "Pommes", kcal: 310, protein: 4, kh: 40, fett: 15)

        let leer = TagebuchStand(ich: .ahmed, tag: heute, heute: heute, jetzt: jetzt, zieleEingerichtet: false)

        var halberTag = TagebuchStand(ich: .ahmed, tag: heute, heute: heute, jetzt: jetzt,
                                      ziele: ziele(kcal: 2200, protein: 140, kh: 240, fett: 70))
        halberTag.eintraege = [
            .fruehstueck: [eintrag("f1", .fruehstueck, hafer, menge: 300)],
            .mittag: [eintrag("m1", .mittag, huehnerReis, menge: 350)],
        ]
        halberTag.verbrannt = 320
        halberTag.wasser = 3
        halberTag.wasserZiel = 8

        var ueberZiel = TagebuchStand(ich: .ahmed, tag: heute, heute: heute, jetzt: jetzt,
                                      ziele: ziele(kcal: 1800, protein: 130, kh: 180, fett: 60, fasten: 16))
        ueberZiel.eintraege = [
            .mittag: [eintrag("b1", .mittag, burger, menge: 250)],
            .snack: [eintrag("p1", .snack, pommes, menge: 200)],
        ]
        ueberZiel.fasten = FastenD(start: jetzt.addingTimeInterval(-5 * 3600), ende: nil)
        ueberZiel.wasser = 6
        ueberZiel.wasserZiel = 8

        var partner = halberTag
        partner.partnerAnsicht = true

        let staende: [(String, TagebuchStand)] = [
            ("Ziele fehlen, leer", leer),
            ("Halber Tag", halberTag),
            ("Über dem Ziel, Fasten läuft", ueberZiel),
            ("Partner-Ansicht", partner),
        ]

        var zellen: [(titel: String, ansicht: AnyView)] = []
        for schema in [ColorScheme.light, .dark] {
            for (titel, stand) in staende {
                zellen.append(zelle("\(titel), \(schema == .light ? "hell" : "dunkel")", TagebuchAnsicht(stand: stand), schema))
            }
        }
        RenderTafel.speichern("ernaehrung", spalten: 4, zellen: zellen)
    }
}
