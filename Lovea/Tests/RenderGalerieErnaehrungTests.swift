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

    /// Für die Tafel: hält die Bindings, die `MengenLeiste` braucht, mit einem festen Startwert.
    private struct MengenLeisteSchau: View {
        let lebensmittel: Lebensmittel
        let start: MengenOption
        let zahl: Double

        @State private var auswahl: MengenOption
        @State private var zahlWert: Double

        init(lebensmittel: Lebensmittel, start: MengenOption, zahl: Double) {
            self.lebensmittel = lebensmittel
            self.start = start
            self.zahl = zahl
            _auswahl = State(initialValue: start)
            _zahlWert = State(initialValue: zahl)
        }

        var body: some View {
            MengenLeiste(lebensmittel: lebensmittel, auswahl: $auswahl, zahl: $zahlWert, knopf: "Hinzufügen", aktion: {})
        }
    }

    func testMengenLeiste() {
        let banane = Lebensmittel(id: "bls-banane", name: "Banane (ohne Schale), frisch",
                                   pro100: Naehrwerte(kcal: 93, protein: 1.1, kohlenhydrate: 20, fett: 0.2),
                                   portionen: [LebensmittelPortion(name: "Frucht, klein", gramm: 75),
                                               LebensmittelPortion(name: "Frucht, mittelgroß", gramm: 150),
                                               LebensmittelPortion(name: "Frucht, groß", gramm: 200)])
        let huehnerei = Lebensmittel(id: "bls-huehnerei", name: "Hühnerei, Eier, gekocht",
                                      pro100: Naehrwerte(kcal: 137, protein: 11.8, kohlenhydrate: 1.5, fett: 9.3),
                                      portionen: [LebensmittelPortion(name: "Ei, mittelgroß", gramm: 60),
                                                  LebensmittelPortion(name: "Ei, groß", gramm: 70)])
        let mittelgross = MengenOption.portion(LebensmittelPortion(name: "Frucht, mittelgroß", gramm: 150))
        let klein = MengenOption.portion(LebensmittelPortion(name: "Frucht, klein", gramm: 75))
        let eiMittelgross = MengenOption.portion(LebensmittelPortion(name: "Ei, mittelgroß", gramm: 60))

        let staende: [(String, Lebensmittel, MengenOption, Double)] = [
            ("Banane, 1 × mittelgroß", banane, mittelgross, 1),
            ("Banane, 721 ⅞ × klein", banane, klein, 721.875),
            ("Hühnerei, 1 × mittelgroß", huehnerei, eiMittelgross, 1),
        ]

        var zellen: [(titel: String, ansicht: AnyView)] = []
        for schema in [ColorScheme.light, .dark] {
            for (titel, l, start, zahl) in staende {
                zellen.append(zelle("\(titel), \(schema == .light ? "hell" : "dunkel")",
                                     MengenLeisteSchau(lebensmittel: l, start: start, zahl: zahl), schema))
            }
        }
        RenderTafel.speichern("mengen", spalten: 3, zellen: zellen)
    }
}
