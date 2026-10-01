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

    /// Statische Vorschau der Hinzufügen-Seite mit festen Werten, ohne `ErnaehrungModell.shared`:
    /// Häufig-Liste (yazio-05), Such-Modus "Eier" mit Marken-Karten (yazio-09), Erstellen-Blatt (yazio-04).
    private struct HinzufuegenSchau: View {
        var body: some View {
            VStack(spacing: 0) {
                HinzuKopf(titel: "Frühstück", zaehler: 0, schliessen: {})
                KachelReihe(aktiv: .suche, tippen: { _ in })
                SuchFeldKnopf(platzhalter: "Was hattest du zum Frühstück?", tippen: {})
                HStack(spacing: 10) {
                    AuswahlKnopf(wert: .constant(HinzuTyp.lebensmittel))
                    AuswahlKnopf(wert: .constant(HinzuSortierung.haeufig))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                VStack(spacing: 0) {
                    ForEach(RenderGalerieErnaehrungTests.haeufigListe, id: \.id) { l in
                        HinzuZeile(lebensmittel: l, tippen: {}, plus: {})
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private struct SucheSchau: View {
        var body: some View {
            VStack(spacing: 0) {
                SuchKopf(text: .constant("Eier"), abbrechen: {})
                SuchChips(auswahl: .constant(nil), partner: .annika)
                VStack(spacing: 12) {
                    ForEach(RenderGalerieErnaehrungTests.eierKarten, id: \.0.id) { l, _, typ in
                        SuchKarte(lebensmittel: l, typLabel: typ, plus: {}, tippen: {})
                    }
                }
                .padding(16)
            }
        }
    }

    private static let haeufigListe: [Lebensmittel] = [
        Lebensmittel(id: "bls-kaffee", name: "Schwarzer Kaffee", pro100: Naehrwerte(kcal: 1, protein: 0, kohlenhydrate: 0, fett: 0),
                     portionMenge: 200, portionName: "Tasse, mittelgroß"),
        Lebensmittel(id: "bls-ei", name: "Hühnerei, Eier, gekocht", pro100: Naehrwerte(kcal: 137, protein: 11.8, kohlenhydrate: 1.5, fett: 9.3),
                     portionMenge: 60, portionName: "Ei, mittelgroß"),
        Lebensmittel(id: "bls-banane", name: "Banane (ohne Schale), frisch", pro100: Naehrwerte(kcal: 93, protein: 1.1, kohlenhydrate: 20, fett: 0.2),
                     portionMenge: 150, portionName: "Frucht, mittelgroß"),
        Lebensmittel(id: "bls-butter", name: "Butter", pro100: Naehrwerte(kcal: 741, protein: 0.7, kohlenhydrate: 0.6, fett: 83),
                     portionMenge: 10, portionName: "Aufstrich"),
        Lebensmittel(id: "bls-milch", name: "Fettarme Kuhmilch 1,5% Fett", pro100: Naehrwerte(kcal: 48, protein: 3.3, kohlenhydrate: 4.8, fett: 1.5),
                     portionMenge: 200, portionName: "Glas"),
        Lebensmittel(id: "bls-apfel", name: "Apfel (mit Schale), frisch", pro100: Naehrwerte(kcal: 65, protein: 0.3, kohlenhydrate: 14, fett: 0.4),
                     portionMenge: 130, portionName: "Frucht, mittelgroß"),
        Lebensmittel(id: "bls-hafer", name: "Haferflocken", pro100: Naehrwerte(kcal: 372, protein: 13, kohlenhydrate: 59, fett: 7),
                     portionMenge: 40, portionName: "Portion"),
        Lebensmittel(id: "bls-broetchen", name: "Weizenbrötchen (Semmel)", pro100: Naehrwerte(kcal: 292, protein: 9, kohlenhydrate: 56, fett: 1.5),
                     portionMenge: 60, portionName: "Brötchen, ganz"),
    ]

    private static let eierKarten: [(Lebensmittel, String, String)] = [
        (Lebensmittel(id: "off-1", name: "frische Eier aus Bodenhaltung", marke: "Aldi",
                      pro100: Naehrwerte(kcal: 153, protein: 13, kohlenhydrate: 0.7, fett: 11), portionMenge: 68, portionName: "Stück"), "Aldi", "Lebensmittel"),
        (Lebensmittel(id: "off-2", name: "10 Frische Eier", marke: "Rewe (Beste Wahl)",
                      pro100: Naehrwerte(kcal: 155, protein: 13, kohlenhydrate: 0.7, fett: 11), portionMenge: 60, portionName: "Ei"), "Rewe", "Lebensmittel"),
        (Lebensmittel(id: "off-3", name: "Bio-Eier (L)", marke: "Gut Bio (Aldi)",
                      pro100: Naehrwerte(kcal: 153, protein: 13, kohlenhydrate: 0.7, fett: 11), portionMenge: 60, portionName: "Stück"), "Aldi", "Lebensmittel"),
        (Lebensmittel(id: "off-4", name: "Eier Spätzle", marke: "Settele",
                      pro100: Naehrwerte(kcal: 150, protein: 6, kohlenhydrate: 27, fett: 2), portionMenge: 60, portionName: "Portion"), "Settele", "Lebensmittel"),
        (Lebensmittel(id: "off-5", name: "Bunte gekochte Eier", marke: "Lidl",
                      pro100: Naehrwerte(kcal: 154, protein: 13, kohlenhydrate: 0.7, fett: 11), portionMenge: 52, portionName: "Ei"), "Lidl", "Lebensmittel"),
    ]

    func testHinzufuegenYazio() {
        var zellen: [(titel: String, ansicht: AnyView)] = []
        for schema in [ColorScheme.light, .dark] {
            let hell = schema == .light ? "hell" : "dunkel"
            zellen.append(zelle("Hinzufügen, \(hell)", HinzufuegenSchau(), schema))
            zellen.append(zelle("Suche \"Eier\", \(hell)", SucheSchau(), schema))
            zellen.append(zelle("Erstellen, \(hell)", ErstellenListe(tippen: { _ in }), schema))
        }
        RenderTafel.speichern("hinzufuegen", spalten: 3, zellen: zellen)
    }
}
