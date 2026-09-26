import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel "ernaehrung": das Tagebuch im YAZIO-Aufbau mit festen Daten, hell und dunkel:
/// leer mit geschätztem Ziel, halber Tag, über dem Ziel, Annikas Tag (nur lesen).
@MainActor
final class RenderGalerieErnaehrungTests: XCTestCase {
    private let heute = "2026-09-26"

    private func zelle(_ titel: String, _ ansicht: some View, _ schema: ColorScheme = .light, breite: CGFloat = 390) -> (titel: String, ansicht: AnyView) {
        (titel, AnyView(ansicht.frame(width: breite).padding(.vertical, 12).background(Color(uiColor: .systemBackground)).environment(\.colorScheme, schema)))
    }

    private func lebensmittel(_ id: String, _ name: String, kcal: Double, protein: Double, kh: Double, fett: Double) -> Lebensmittel {
        Lebensmittel(id: id, name: name, pro100: Naehrwerte(kcal: kcal, protein: protein, kohlenhydrate: kh, fett: fett))
    }

    private func eintrag(_ id: String, _ m: Mahlzeit, _ l: Lebensmittel, menge: Double) -> EssenEintrag {
        EssenEintrag(id: id, datum: heute, mahlzeit: m, menge: menge, einheit: .g, lebensmittel: l, geloescht: nil)
    }

    private func ziele(kcal: Int, protein: Int, kh: Int, fett: Int) -> ErnaehrungsZiele {
        var z = ErnaehrungsZiele()
        z.eingerichtet = true
        z.kcal = kcal
        z.protein = protein
        z.kohlenhydrate = kh
        z.fett = fett
        return z
    }

    func testTagebuchAnsicht() {
        let hafer = lebensmittel("eigen-hafer", "Haferflocken mit Milch", kcal: 120, protein: 5, kh: 18, fett: 3)
        let skyr = lebensmittel("off-1", "Skyr natur", kcal: 62, protein: 11, kh: 4, fett: 0.2)
        let huehnerReis = lebensmittel("eigen-huehner", "Hähnchen mit Reis", kcal: 160, protein: 14, kh: 18, fett: 4)
        let burger = lebensmittel("eigen-burger", "Cheeseburger", kcal: 280, protein: 14, kh: 22, fett: 15)
        let pommes = lebensmittel("eigen-pommes", "Pommes", kcal: 310, protein: 4, kh: 40, fett: 15)

        var leer = TagebuchStand(tag: heute, heute: heute, person: .ahmed, zieleEingerichtet: false)
        leer.ziele = ziele(kcal: 2760, protein: 138, kh: 345, fett: 92)

        var halberTag = TagebuchStand(tag: heute, heute: heute, person: .ahmed, ziele: ziele(kcal: 2200, protein: 140, kh: 240, fett: 70))
        halberTag.eintraege = [
            .fruehstueck: [eintrag("f1", .fruehstueck, hafer, menge: 300), eintrag("f2", .fruehstueck, skyr, menge: 150)],
            .mittag: [eintrag("m1", .mittag, huehnerReis, menge: 350)],
        ]
        halberTag.verbrannt = 320
        halberTag.wasserGlaeser = 3
        halberTag.wasserAusEssenMl = 330
        halberTag.gewicht = GewichtStand(zehntel: 784, datum: "2026-09-22")
        halberTag.koerperwerte = [KoerperwertD(datum: "2026-09-22", art: .koerperfett, wert: 17.5, geloescht: nil), KoerperwertD(datum: "2026-09-22", art: .taille, wert: 84, geloescht: nil)]

        var ueberZiel = TagebuchStand(tag: heute, heute: heute, person: .ahmed, ziele: ziele(kcal: 1500, protein: 130, kh: 150, fett: 50))
        ueberZiel.eintraege = [
            .mittag: [eintrag("b1", .mittag, burger, menge: 250)],
            .abend: [eintrag("p1", .abend, pommes, menge: 300)],
        ]
        ueberZiel.wasserGlaeser = 8
        ueberZiel.wasserAusEssenMl = 637
        ueberZiel.gewicht = GewichtStand(zehntel: 781, datum: heute)

        var partner = halberTag
        partner.person = .annika
        partner.partnerAnsicht = true

        let staende: [(String, TagebuchStand)] = [
            ("Leer, Ziel geschätzt", leer),
            ("Halber Tag", halberTag),
            ("Über dem Ziel", ueberZiel),
            ("Annikas Tag", partner),
        ]

        var zellen: [(titel: String, ansicht: AnyView)] = []
        for schema in [ColorScheme.light, .dark] {
            for (titel, stand) in staende {
                zellen.append(zelle("\(titel), \(schema == .light ? "hell" : "dunkel")", TagebuchAnsicht(stand: stand).padding(.horizontal, 16), schema))
            }
        }
        RenderTafel.speichern("ernaehrung", spalten: 4, zellen: zellen)
    }
}
