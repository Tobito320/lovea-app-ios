import XCTest
@testable import Lovea

/// Z-33.2, Review-Fokus 4: trigger words without false alarms.
final class ChatEffektTests: XCTestCase {
    func testReviewFokusFaelle() {
        XCTAssertEqual(ChatEffekt.erkennen("gute Nacht!"), .sterne)
        XCTAssertNil(ChatEffekt.erkennen("gute Nachtschicht"))
        XCTAssertEqual(ChatEffekt.erkennen("Kuss"), .kuesse)
        XCTAssertEqual(ChatEffekt.erkennen("Küsschen"), .kuesse)
        XCTAssertNil(ChatEffekt.erkennen("Kussmund-Emoji"))
        XCTAssertEqual(ChatEffekt.erkennen("hdl"), .herzen)
    }

    func testGrossKleinUndUmlauteSindEgal() {
        XCTAssertEqual(ChatEffekt.erkennen("ICH LIEBE DICH"), .herzen)
        XCTAssertEqual(ChatEffekt.erkennen("KÜSSCHEN"), .kuesse)
        XCTAssertEqual(ChatEffekt.erkennen("Kuesschen"), .kuesse)
        XCTAssertEqual(ChatEffekt.erkennen("Herzlichen Glückwunsch zur Prüfung"), .konfetti)
        XCTAssertEqual(ChatEffekt.erkennen("herzlichen glueckwunsch"), .konfetti)
    }

    func testInLaengerenSaetzen() {
        XCTAssertEqual(ChatEffekt.erkennen("Guten Morgen, Schatz"), .sonne)
        XCTAssertEqual(ChatEffekt.erkennen("Alles Gute zum Geburtstag"), .ballons)
        XCTAssertEqual(ChatEffekt.erkennen("Happy Birthday!!"), .ballons)
        XCTAssertEqual(ChatEffekt.erkennen("I love you"), .herzen)
        XCTAssertEqual(ChatEffekt.erkennen("ich vermiss dich"), .glitzer)
        XCTAssertEqual(ChatEffekt.erkennen("Ich vermisse dich so sehr"), .glitzer)
        XCTAssertEqual(ChatEffekt.erkennen("hdl, gute   Nacht"), .herzen, "erster Effekt der Liste gewinnt, Leerzeichen egal")
    }

    func testWortgrenzen() {
        XCTAssertNil(ChatEffekt.erkennen("hdlg"))
        XCTAssertNil(ChatEffekt.erkennen("Gutenachtkuss"))
        XCTAssertNil(ChatEffekt.erkennen("Bis morgen"))
        XCTAssertNil(ChatEffekt.erkennen(""))
    }
}
