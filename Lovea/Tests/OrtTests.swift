import XCTest
@testable import Lovea

/// Treffen Teil 3: reine Ort-Funktionen (Name, kurze Adresse, Karten-Links, Suche ab zwei Zeichen).
final class OrtTests: XCTestCase {
    private let cafe = PunktOrt(name: "Café & Bar", lat: 51.2217, lon: 6.7762, adresse: nil)

    // MARK: - OrtName.sauber

    func testNameIsTrimmed() {
        XCTAssertEqual(OrtName.sauber("  Rheinturm \n"), "Rheinturm")
    }

    func testNameIsCutAtSixtyCharacters() {
        let lang = String(repeating: "a", count: 100)
        XCTAssertEqual(OrtName.sauber(lang).count, 60)
    }

    func testUrlNameFallsBackToStreet() {
        XCTAssertEqual(OrtName.sauber("https://example.com/x", strasse: "Königsallee"), "Königsallee")
        XCTAssertEqual(OrtName.sauber("maps.apple.com/?q=1", strasse: "Königsallee"), "Königsallee")
    }

    func testNameIsEmptyWhenNothingUsable() {
        XCTAssertEqual(OrtName.sauber(nil), "")
        XCTAssertEqual(OrtName.sauber("   ", strasse: nil), "")
        XCTAssertEqual(OrtName.sauber("http://x.de", strasse: "https://y.de"), "")
    }

    // MARK: - OrtKurz.adresse

    func testShortAddressStreetNumberCity() {
        XCTAssertEqual(OrtKurz.adresse(strasse: "Königsallee", nr: "1", plz: "40212", ort: "Düsseldorf"), "Königsallee 1, Düsseldorf")
    }

    func testShortAddressWithoutNumber() {
        XCTAssertEqual(OrtKurz.adresse(strasse: "Königsallee", nr: nil, plz: nil, ort: "Düsseldorf"), "Königsallee, Düsseldorf")
    }

    func testShortAddressOnlyCityOrPostcode() {
        XCTAssertEqual(OrtKurz.adresse(strasse: nil, nr: "5", plz: "40212", ort: "Düsseldorf"), "Düsseldorf")
        XCTAssertEqual(OrtKurz.adresse(strasse: nil, nr: nil, plz: "40212", ort: nil), "40212")
    }

    func testShortAddressNilWhenEmptyAndNeverAUrl() {
        XCTAssertNil(OrtKurz.adresse(strasse: " ", nr: nil, plz: nil, ort: ""))
        XCTAssertNil(OrtKurz.adresse(strasse: "https://x.de", nr: nil, plz: nil, ort: nil))
    }

    // MARK: - OrtLinks

    func testAppleMapsURL() {
        XCTAssertEqual(OrtLinks.appleMapsURL(cafe).absoluteString,
                       "https://maps.apple.com/?ll=51.22170,6.77620&q=Caf%C3%A9%20%26%20Bar")
    }

    func testGoogleMapsURL() {
        XCTAssertEqual(OrtLinks.googleMapsURL(cafe).absoluteString,
                       "comgooglemaps://?q=Caf%C3%A9%20%26%20Bar&center=51.22170,6.77620")
    }

    func testNegativeCoordinatesKeepDotAndSign() {
        let sydney = PunktOrt(name: "Oper", lat: -33.8568, lon: 151.2153, adresse: nil)
        XCTAssertTrue(OrtLinks.googleMapsURL(sydney).absoluteString.hasSuffix("center=-33.85680,151.21530"))
    }

    func testCacheKeyIsPerPlace() {
        let nah = PunktOrt(name: "x", lat: 51.2217, lon: 6.7762, adresse: "egal")
        let fern = PunktOrt(name: "x", lat: 51.2218, lon: 6.7762, adresse: nil)
        XCTAssertEqual(OrtLinks.cacheSchluessel(cafe), OrtLinks.cacheSchluessel(nah))
        XCTAssertNotEqual(OrtLinks.cacheSchluessel(cafe), OrtLinks.cacheSchluessel(fern))
    }

    // MARK: - OrtSuche

    func testSearchStartsFromTwoCharacters() {
        XCTAssertFalse(OrtSuche.lohnt(""))
        XCTAssertFalse(OrtSuche.lohnt(" a "))
        XCTAssertTrue(OrtSuche.lohnt("Rh"))
        XCTAssertEqual(OrtSuche.anfrage("  Rhein "), "Rhein")
    }
}
