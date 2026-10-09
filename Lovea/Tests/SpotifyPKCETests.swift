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

    // MARK: Fehlertexte (kein stilles Scheitern mehr)

    func testCallbackMitCodeLiefertCode() {
        let url = URL(string: "lovea://spotify?code=abc123")!
        XCTAssertEqual(try? SpotifyFehler.code(aus: url).get(), "abc123")
    }

    func testCallbackMitErrorLiefertAnmeldungFehler() {
        let url = URL(string: "lovea://spotify?error=access_denied")!
        XCTAssertEqual(SpotifyFehler.code(aus: url), .failure(.anmeldung("access_denied")))
        XCTAssertEqual(SpotifyFehler.anmeldung("access_denied").text, "Du hast den Zugriff in Spotify abgelehnt.")
    }

    func testCallbackOhneCodeIstKeinCode() {
        XCTAssertEqual(SpotifyFehler.code(aus: URL(string: "lovea://spotify")!), .failure(.keinCode))
    }

    func testServerAntwortGrundWirdGelesen() {
        let body = Data(#"{"fehler":"tausch fehlgeschlagen","grund":"invalid_client"}"#.utf8)
        XCTAssertEqual(SpotifyFehler.ausServer(status: 502, body: body), .server(status: 502, grund: "invalid_client"))
        XCTAssertEqual(SpotifyFehler.ausServer(status: 502, body: Data()), .server(status: 502, grund: nil))
    }

    func testFehlerTexteSindUnterscheidbarUndAbbruchIstStill() {
        XCTAssertNil(SpotifyFehler.abgebrochen.text)
        let texte = [
            SpotifyFehler.server(status: 503, grund: nil),
            .server(status: 502, grund: "invalid_client"),
            .server(status: 502, grund: "invalid_grant"),
            .netz, .keinCode, .nichtEingerichtet,
        ].compactMap(\.text)
        XCTAssertEqual(texte.count, 6)
        XCTAssertEqual(Set(texte).count, 6)
        XCTAssertTrue(SpotifyFehler.server(status: 502, grund: "invalid_grant").text?.contains("lovea://spotify") == true)
    }

    func testStatusTexte() {
        XCTAssertTrue(SpotifyFehler.text(fuerStatus: "nicht-freigeschaltet").contains("User Management"))
        XCTAssertTrue(SpotifyFehler.text(fuerStatus: "abgelaufen").contains("neu verbinden"))
    }
}
