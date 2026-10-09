import XCTest
@testable import Lovea

/// Health-Coach: Zeilen-Erkennung der Antworten, Trennzeilen und Begrüßung (`CoachText.swift`). Reine Logik.
final class CoachTextTests: XCTestCase {

    private func arten(_ roh: String) -> [CoachText.Art] { CoachText.zeilen(roh).map(\.art) }

    // MARK: - Zeilen

    func testAbsatzBleibtAbsatz() {
        XCTAssertEqual(CoachText.zeilen("Du hast heute 8.200 Schritte."),
                       [CoachText.Zeile(art: .absatz, text: "Du hast heute 8.200 Schritte.")])
    }

    func testLeereZeilenUndTrennlinienFallenWeg() {
        XCTAssertEqual(arten("Eins\n\n---\n   \nZwei"), [.absatz, .absatz])
    }

    func testPunkteMitAllenMarken() {
        XCTAssertEqual(CoachText.zeilen("- Reis\n* Hähnchen\n• Quark"),
                       [CoachText.Zeile(art: .punkt, text: "Reis"),
                        CoachText.Zeile(art: .punkt, text: "Hähnchen"),
                        CoachText.Zeile(art: .punkt, text: "Quark")])
    }

    func testFettAmZeilenanfangIstKeinPunkt() {
        XCTAssertEqual(CoachText.zeilen("**Wichtig** zuerst trinken"),
                       [CoachText.Zeile(art: .absatz, text: "**Wichtig** zuerst trinken")])
    }

    func testNummernMitPunktUndKlammer() {
        XCTAssertEqual(CoachText.zeilen("1. Aufwärmen\n2) Beugen\n12. Dehnen"),
                       [CoachText.Zeile(art: .nummer(1), text: "Aufwärmen"),
                        CoachText.Zeile(art: .nummer(2), text: "Beugen"),
                        CoachText.Zeile(art: .nummer(12), text: "Dehnen")])
    }

    func testZahlOhnePunktUndDezimalzahlSindKeineNummer() {
        XCTAssertEqual(arten("2026 war gut\n3,5 Liter trinken\n1.5 Liter"), [.absatz, .absatz, .absatz])
    }

    func testUeberschrift() {
        XCTAssertEqual(CoachText.zeilen("## Training\n#Kein Titel"),
                       [CoachText.Zeile(art: .ueberschrift, text: "Training"),
                        CoachText.Zeile(art: .absatz, text: "#Kein Titel")])
    }

    func testGemischteAntwortBehaeltReihenfolge() {
        let roh = "Kurz gesagt:\n\n- Protein hoch\n- Schlaf\n\n1. Heute Beine"
        XCTAssertEqual(arten(roh), [.absatz, .punkt, .punkt, .nummer(1)])
    }

    func testLeerUndNurLeerzeichenGebenNichts() {
        XCTAssertTrue(CoachText.zeilen("").isEmpty)
        XCTAssertTrue(CoachText.zeilen(" \n\t\n ").isEmpty)
    }

    // MARK: - Inline

    func testInlineMarkdownWirdFett() {
        let text = CoachText.inline("Das ist **fett**")
        XCTAssertEqual(String(text.characters), "Das ist fett")
    }

    func testInlineBehaeltZeilenumbrueche() {
        XCTAssertEqual(String(CoachText.inline("Zeile eins\nZeile zwei").characters), "Zeile eins\nZeile zwei")
    }

    // MARK: - Trennzeile

    private var kalender: Calendar { Datum.kalender }
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    func testErsteNachrichtBekommtTrennzeile() {
        XCTAssertTrue(CoachText.trennerNoetig(vorher: nil, jetzt: start, kalender: kalender))
    }

    func testKurzeAbstaendeAmSelbenTagBekommenKeine() {
        let spaeter = start.addingTimeInterval(20 * 60)
        XCTAssertFalse(CoachText.trennerNoetig(vorher: start, jetzt: spaeter, kalender: kalender))
    }

    func testLangePauseBekommtTrennzeile() {
        XCTAssertTrue(CoachText.trennerNoetig(vorher: start, jetzt: start.addingTimeInterval(7 * 3600), kalender: kalender))
    }

    func testNeuerTagBekommtTrennzeile() {
        XCTAssertTrue(CoachText.trennerNoetig(vorher: start, jetzt: start.addingTimeInterval(24 * 3600), kalender: kalender))
    }

    // MARK: - Begrüßung

    func testBegruessungNachTageszeit() {
        XCTAssertEqual(CoachText.begruessung(stunde: 5), "Guten Morgen")
        XCTAssertEqual(CoachText.begruessung(stunde: 10), "Guten Morgen")
        XCTAssertEqual(CoachText.begruessung(stunde: 11), "Hallo")
        XCTAssertEqual(CoachText.begruessung(stunde: 17), "Hallo")
        XCTAssertEqual(CoachText.begruessung(stunde: 18), "Guten Abend")
        XCTAssertEqual(CoachText.begruessung(stunde: 22), "Guten Abend")
        XCTAssertEqual(CoachText.begruessung(stunde: 23), "Hallo")
        XCTAssertEqual(CoachText.begruessung(stunde: 3), "Hallo")
    }

    // MARK: - Tabellen und Aufgaben

    func testTabelleWirdEineZeile() {
        let roh = "Hier:\n| Tag | Schritte |\n|---|---|\n| Mo | 8200 |\n| Di | 9100 |\nDanach"
        XCTAssertEqual(CoachText.zeilen(roh), [
            CoachText.Zeile(art: .absatz, text: "Hier:"),
            CoachText.Zeile(art: .tabelle(kopf: ["Tag", "Schritte"], zeilen: [["Mo", "8200"], ["Di", "9100"]]), text: ""),
            CoachText.Zeile(art: .absatz, text: "Danach"),
        ])
    }

    func testTabelleMitKurzerUndLangerZeileBleibtRechteckig() {
        let roh = "| a | b |\n|:--|--:|\n| 1 |\n| 1 | 2 | 3 |"
        XCTAssertEqual(CoachText.zeilen(roh), [
            CoachText.Zeile(art: .tabelle(kopf: ["a", "b"], zeilen: [["1", ""], ["1", "2"]]), text: ""),
        ])
    }

    func testEinzelneStrichzeileOhneTrennerIstKeineTabelle() {
        XCTAssertEqual(arten("| a | b |"), [.absatz])
        XCTAssertEqual(arten("| a | b |\n| 1 | 2 |"), [.absatz, .absatz])
    }

    func testAufgabeMitKaestchen() {
        XCTAssertEqual(CoachText.zeilen("- [ ] Kniebeugen 3x8\n- [x] Dehnen\n- Normal"),
                       [CoachText.Zeile(art: .aufgabe, text: "Kniebeugen 3x8"),
                        CoachText.Zeile(art: .aufgabe, text: "Dehnen"),
                        CoachText.Zeile(art: .punkt, text: "Normal")])
    }

    // MARK: - Vorschau

    func testVorschauOhneMarkdownUndMarker() {
        let roh = "**Hallo** du\n- Reis\n[[weiter: A | B | C]]"
        XCTAssertEqual(CoachText.vorschau(roh), "Hallo du Reis")
    }

    func testVorschauKuerztMitPunkten() {
        XCTAssertEqual(CoachText.vorschau("abcdefghij", maximal: 5), "abcde…")
        XCTAssertEqual(CoachText.vorschau("abcde", maximal: 5), "abcde")
    }

    // MARK: - Zahlen mit Einheit

    private func zahlen(_ text: String) -> [String] {
        let zeichen = Array(text)
        return CoachText.zahlBereiche(text).map { String(zeichen[$0]) }
    }

    func testZahlenMitEinheitWerdenGefunden() {
        XCTAssertEqual(zahlen("Du hast 8.200 Schritte und 120 g Protein, 85 % Ziel"),
                       ["8.200 Schritte", "120 g", "85 %"])
        XCTAssertEqual(zahlen("Schlaf 7,5 h und 3 Sätze"), ["7,5 h", "3 Sätze"])
    }

    func testZahlenOhneEinheitBleibenUnberuehrt() {
        XCTAssertTrue(zahlen("Im Jahr 2026 am 12.10. war es gut").isEmpty)
        XCTAssertTrue(zahlen("Das sind 5 Hammer").isEmpty)
    }

    // MARK: - Wort für Wort

    func testWoerterZaehlen() {
        XCTAssertEqual(CoachText.woerter("Hallo schöne  Welt\nheute"), 4)
        XCTAssertEqual(CoachText.woerter("  "), 0)
    }

    func testPraefixLaenge() {
        XCTAssertEqual(CoachText.praefixLaenge("Hallo schöne Welt", woerter: 0), 0)
        XCTAssertEqual(CoachText.praefixLaenge("Hallo schöne Welt", woerter: 1), 5)
        XCTAssertEqual(CoachText.praefixLaenge("Hallo schöne Welt", woerter: 2), 12)
        XCTAssertEqual(CoachText.praefixLaenge("Hallo schöne Welt", woerter: 3), 17)
        XCTAssertEqual(CoachText.praefixLaenge("Hallo schöne Welt", woerter: 9), 17)
    }

    func testGekuerztSchliesstOffenesFett() {
        XCTAssertEqual(CoachText.gekuerzt("Das ist **sehr gut** heute", woerter: 3), "Das ist **sehr**")
        XCTAssertEqual(CoachText.gekuerzt("Das ist **sehr gut** heute", woerter: 4), "Das ist **sehr gut**")
        XCTAssertEqual(CoachText.gekuerzt("Das ist **sehr gut** heute", woerter: 5), "Das ist **sehr gut** heute")
        XCTAssertEqual(CoachText.gekuerzt("Das ist **sehr gut** heute", woerter: 2), "Das ist")
    }

    func testEinblendTempo() {
        XCTAssertEqual(CoachText.wortSchritt(gesamt: 0), 0)
        XCTAssertEqual(CoachText.wortSchritt(gesamt: 10), 0.05, accuracy: 0.0001)
        XCTAssertEqual(CoachText.wortSchritt(gesamt: 100), 0.025, accuracy: 0.0001)
        XCTAssertEqual(CoachText.wortSchritt(gesamt: 1000), 0.015, accuracy: 0.0001)
        XCTAssertEqual(CoachText.einblendDauer(gesamt: 10), 0.5, accuracy: 0.0001)
        XCTAssertEqual(CoachText.einblendDauer(gesamt: 100), 2.5, accuracy: 0.0001)
    }

    func testSichtbareWoerterWachsenUndStoppen() {
        XCTAssertEqual(CoachText.sichtbareWoerter(vergangen: -1, gesamt: 10), 0)
        XCTAssertEqual(CoachText.sichtbareWoerter(vergangen: 0, gesamt: 10), 0)
        XCTAssertEqual(CoachText.sichtbareWoerter(vergangen: 0.26, gesamt: 10), 5)
        XCTAssertEqual(CoachText.sichtbareWoerter(vergangen: 99, gesamt: 10), 10)
        XCTAssertEqual(CoachText.sichtbareWoerter(vergangen: 5, gesamt: 0), 0)
    }

    // MARK: - Tageszeit

    func testTageszeitNachStunde() {
        XCTAssertEqual(CoachText.tageszeit(stunde: 4), .nacht)
        XCTAssertEqual(CoachText.tageszeit(stunde: 5), .morgen)
        XCTAssertEqual(CoachText.tageszeit(stunde: 10), .morgen)
        XCTAssertEqual(CoachText.tageszeit(stunde: 11), .tag)
        XCTAssertEqual(CoachText.tageszeit(stunde: 17), .tag)
        XCTAssertEqual(CoachText.tageszeit(stunde: 18), .abend)
        XCTAssertEqual(CoachText.tageszeit(stunde: 22), .abend)
        XCTAssertEqual(CoachText.tageszeit(stunde: 23), .nacht)
        XCTAssertEqual(CoachText.tageszeit(stunde: 0), .nacht)
    }

    // MARK: - Einblenden über mehrere Zeilen

    private func zeile(_ art: CoachText.Art, _ text: String) -> CoachText.Zeile { CoachText.Zeile(art: art, text: text) }

    func testWortAnzahlUndGesamt() {
        let z = CoachText.zeilen("Eins zwei drei\n- vier fünf\nSechs")
        XCTAssertEqual(CoachText.wortAnzahl(z[0]), 3)
        XCTAssertEqual(CoachText.gesamtWoerter(z), 6)
        XCTAssertEqual(CoachText.gesamtWoerter([]), 0)
    }

    func testEingeblendetKuerztDieZeileMitDemLimit() {
        let z = CoachText.zeilen("Eins zwei drei\n- vier fünf\nSechs")
        XCTAssertEqual(CoachText.eingeblendet(z, woerter: 4), [zeile(.absatz, "Eins zwei drei"), zeile(.punkt, "vier")])
        XCTAssertEqual(CoachText.eingeblendet(z, woerter: 2), [zeile(.absatz, "Eins zwei")])
    }

    func testEingeblendetAmZeilenEndeNimmtKeineLeereZeileMit() {
        let z = CoachText.zeilen("Eins zwei drei\n- vier fünf\nSechs")
        XCTAssertEqual(CoachText.eingeblendet(z, woerter: 3), [zeile(.absatz, "Eins zwei drei")])
    }

    func testEingeblendetNullUndZuViele() {
        let z = CoachText.zeilen("Eins zwei drei\n- vier fünf\nSechs")
        XCTAssertEqual(CoachText.eingeblendet(z, woerter: 0), [])
        XCTAssertEqual(CoachText.eingeblendet(z, woerter: -3), [])
        XCTAssertEqual(CoachText.eingeblendet(z, woerter: 99), z)
    }

    func testEingeblendetTabelleErscheintAufEinmal() {
        let z = CoachText.zeilen("Eins\n| a | b |\n|---|---|\n| 1 | 2 |\nEnde")
        XCTAssertEqual(z.count, 3)
        XCTAssertEqual(CoachText.gesamtWoerter(z), 3)
        XCTAssertEqual(CoachText.eingeblendet(z, woerter: 1), [z[0]])
        XCTAssertEqual(CoachText.eingeblendet(z, woerter: 2), [z[0], z[1]])
        XCTAssertEqual(CoachText.eingeblendet(z, woerter: 3), z)
    }

    func testEingeblendetSchliesstOffenesFett() {
        let z = CoachText.zeilen("**fett gedruckt** und")
        XCTAssertEqual(CoachText.eingeblendet(z, woerter: 1), [zeile(.absatz, "**fett**")])
    }

    func testEinblendenLohntNurBisZweihundertfuenfzigWoerter() {
        XCTAssertFalse(CoachText.einblendenLohnt(gesamt: 0))
        XCTAssertTrue(CoachText.einblendenLohnt(gesamt: 1))
        XCTAssertTrue(CoachText.einblendenLohnt(gesamt: 250))
        XCTAssertFalse(CoachText.einblendenLohnt(gesamt: 251))
    }

    func testEinblendTermine() {
        let start = Date(timeIntervalSince1970: 1000)
        let termine = CoachText.einblendTermine(start: start, gesamt: 5)
        XCTAssertEqual(termine.count, 6)
        XCTAssertEqual(termine.first, start)
        XCTAssertEqual(termine.last!.timeIntervalSince(start), CoachText.einblendDauer(gesamt: 5), accuracy: 0.0001)
        XCTAssertEqual(CoachText.einblendTermine(start: start, gesamt: 0), [start])
    }
}
