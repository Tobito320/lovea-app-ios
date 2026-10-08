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
}
