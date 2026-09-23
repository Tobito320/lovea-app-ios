import XCTest
@testable import Lovea

private final class SpeicherStub: SchluesselbundSpeicher, @unchecked Sendable {
    var werte: [String: String] = [:]
    func lesen(dienst: String) -> String? { werte[dienst] }
    func schreiben(_ wert: String, dienst: String) { werte[dienst] = wert }
}

final class SchluesselbundTests: XCTestCase {
    func testSpeichertUndLaedtUeberEinenStub() {
        let schluesselbund = Schluesselbund(speicher: SpeicherStub())

        XCTAssertNil(schluesselbund.get())

        schluesselbund.set(Person.ahmed.rawValue)

        XCTAssertEqual(schluesselbund.get(), "ahmed")
    }

    func testJederSchluesselbundHatSeineEigeneStubInstanz() {
        let stub = SpeicherStub()
        let erster = Schluesselbund(speicher: stub)
        let zweiter = Schluesselbund(speicher: stub)

        erster.set(Person.annika.rawValue)

        XCTAssertEqual(zweiter.get(), "annika")
    }
}
