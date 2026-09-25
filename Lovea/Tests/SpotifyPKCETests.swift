import XCTest
@testable import Lovea

/// Z-27.6: PKCE (RFC 7636) und die "läuft gerade etwas"-Wire-Shape, pure logic.
/// `@MainActor`: `SpotifyModell.Song` is nested in the `@MainActor` `SpotifyModell`.
@MainActor
final class SpotifyPKCETests: XCTestCase {
    /// RFC 7636 Appendix B test vector.
    func testChallengeMatchesRfc7636Vector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        XCTAssertEqual(SpotifyPKCE.challenge(verifier), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testVerifierHatDieRichtigeLaengeUndZeichen() {
        let verifier = SpotifyPKCE.verifier()
        XCTAssertEqual(verifier.count, 64)
        XCTAssertTrue(verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." || $0 == "_" || $0 == "~" })
    }

    func testSongGueltigNurMitTitel() {
        XCTAssertFalse(SpotifyModell.Song().gueltig)
        XCTAssertFalse(SpotifyModell.Song(titel: "").gueltig)
        XCTAssertTrue(SpotifyModell.Song(titel: "Ein Song").gueltig)
        XCTAssertTrue(SpotifyModell.Song(musik: true).gueltig) // Freigabe "Nur hört Musik"
    }

    func testOeffnenURLTitelSonstKuenstlersuche() {
        XCTAssertEqual(SpotifyModell.Song(titel: "S", url: "https://open.spotify.com/track/abc").oeffnenURL?.absoluteString, "https://open.spotify.com/track/abc")
        XCTAssertEqual(SpotifyModell.Song(kuenstler: "Die Band", musik: true).oeffnenURL?.absoluteString, "https://open.spotify.com/search/Die%20Band")
        XCTAssertNil(SpotifyModell.Song(musik: true).oeffnenURL)
    }

    func testFreigabeRohwerteWieServer() {
        XCTAssertEqual(SpotifyModell.Freigabe.allCases.map(\.rawValue).sorted(), ["aus", "kuenstler", "musik", "song"])
    }
}
