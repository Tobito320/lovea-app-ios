import SwiftUI
import XCTest
@testable import Lovea

/// Z-34.1: every bubble/text color pair of every backdrop reaches WCAG 4.5 : 1 in light and dark
/// (own gradients at every point, not only the stops), and `chat.backdrop` decodes in all three forms.
final class BackdropTests: XCTestCase {

    private typealias RGB = (r: Double, g: Double, b: Double)

    // MARK: - WCAG 2.x

    /// Relative luminance from gamma-encoded sRGB components (0…1).
    private func luminanz(_ c: RGB) -> Double {
        func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    private func kontrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminanz(a), lb = luminanz(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Resolves adaptive colors the way SwiftUI draws them in that appearance.
    @MainActor
    private func rgb(_ farbe: Color, _ schema: ColorScheme) -> RGB {
        var umgebung = EnvironmentValues()
        umgebung.colorScheme = schema
        let aufgeloest = farbe.resolve(in: umgebung)
        return (Double(aufgeloest.red), Double(aufgeloest.green), Double(aufgeloest.blue))
    }

    @MainActor
    func testJedeBlasenfarbeHatMindestensViereinhalbZuEins() {
        for backdrop in Backdrops.alle + [Backdrops.neutral] {
            for schema in [ColorScheme.light, .dark] {
                let partner = kontrast(rgb(backdrop.partnerBlase, schema), rgb(backdrop.partnerText, schema))
                XCTAssertGreaterThanOrEqual(partner, 4.5, "\(backdrop.id) Partner-Blase, \(schema)")

                // The own gradient spans the screen (Spec 2.3), so a bubble can show any point of it:
                // check the stops and the steps between them (SwiftUI interpolates in gamma space).
                let text = rgb(backdrop.eigeneText, schema)
                let stopps = backdrop.verlauf.map { rgb($0, schema) }
                for (von, bis) in zip(stopps, stopps.dropFirst()) {
                    for schritt in 0...8 {
                        let t = Double(schritt) / 8
                        let punkt: RGB = (von.r + (bis.r - von.r) * t, von.g + (bis.g - von.g) * t, von.b + (bis.b - von.b) * t)
                        XCTAssertGreaterThanOrEqual(kontrast(punkt, text), 4.5, "\(backdrop.id) eigene Blase bei \(t), \(schema)")
                    }
                }
            }
        }
    }

    /// Guards the test above: the dark-mode pass must really see dark colors.
    @MainActor
    func testAdaptiveFarbenUnterscheidenHellUndDunkel() {
        let hell = luminanz(rgb(Backdrops.neutral.partnerBlase, .light))
        let dunkel = luminanz(rgb(Backdrops.neutral.partnerBlase, .dark))
        XCTAssertGreaterThan(hell - dunkel, 0.5)
    }

    // MARK: - Catalog

    @MainActor
    func testSechzehnBackdropsInDerReihenfolgeDerSpec() {
        XCTAssertEqual(Backdrops.alle.map(\.id), [
            "romantic", "flirty", "monochrome", "coquette", "dark-academia", "y2k", "soft-pastel", "old-money",
            "night-sky", "kirschbluete", "sunset", "ocean", "film-grain", "paris", "herbst", "schnee",
        ])
        let animationen: [String: BackdropAnimation] = [
            "romantic": .herzen, "flirty": .herzen, "night-sky": .funkeln, "kirschbluete": .blueten,
            "schnee": .schnee, "herbst": .blaetter, "y2k": .glitzer, "coquette": .glitzer,
        ]
        for backdrop in Backdrops.alle + [Backdrops.neutral] {
            XCTAssertEqual(backdrop.ersatz.count, 9, "\(backdrop.id): MeshGradient 3×3")
            XCTAssertTrue((2...3).contains(backdrop.verlauf.count), backdrop.id)
            XCTAssertEqual(backdrop.animation, animationen[backdrop.id] ?? .keine, backdrop.id)
            XCTAssertEqual(backdrop.bildName, "backdrop-\(backdrop.id)")
        }
        XCTAssertEqual(Set(Backdrops.alle.map(\.name)).count, 16)
    }

    // MARK: - chat.backdrop

    private func json(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    @MainActor
    func testChatBackdropInAllenDreiFormen() throws {
        XCTAssertEqual(Backdrops.lesen(try json(#"{"id":"night-sky"}"#)), .vorlage("night-sky"))
        XCTAssertEqual(Backdrops.lesen(try json(#"{"art":"foto","medienId":"m-1"}"#)), .foto("m-1"))
        XCTAssertEqual(Backdrops.lesen(try json(#"{"art":"zeichnung","id":"9B2C6B1E-0000-4000-8000-000000000001"}"#)),
                       .zeichnung("9B2C6B1E-0000-4000-8000-000000000001"))
        // Unknown extra fields are ignored; broken shapes are no choice.
        XCTAssertEqual(Backdrops.lesen(try json(#"{"id":"paris","neu":true}"#)), .vorlage("paris"))
        XCTAssertNil(Backdrops.lesen(try json(#"{"art":"foto"}"#)))
        XCTAssertNil(Backdrops.lesen(try json(#"{"art":"video","id":"x"}"#)))
        XCTAssertNil(Backdrops.lesen(.string("romantic")))
        XCTAssertNil(Backdrops.lesen(nil))
    }

    @MainActor
    func testUnbekannteIdIstNeutral() throws {
        XCTAssertEqual(Backdrops.backdrop(fuer: Backdrops.lesen(try json(#"{"id":"gibt-es-nicht"}"#))).id, Backdrops.neutral.id)
        XCTAssertNil(Backdrops.von("gibt-es-nicht"))
        XCTAssertEqual(Backdrops.backdrop(fuer: nil).id, "neutral")
        XCTAssertEqual(Backdrops.backdrop(fuer: .foto("m-1")).id, "neutral")
        XCTAssertEqual(Backdrops.backdrop(fuer: .zeichnung("z-1")).id, "neutral")
        XCTAssertEqual(Backdrops.backdrop(fuer: .vorlage("ocean")).id, "ocean")
    }

    /// What `waehlen` sends is exactly the Zielplan wire shape and reads back as the same choice.
    @MainActor
    func testWaehlenSchreibtGenauDieDreiFormen() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let erwartet: [(BackdropWahl, String)] = [
            (.vorlage("paris"), #"{"id":"paris"}"#),
            (.foto("m-2"), #"{"art":"foto","medienId":"m-2"}"#),
            (.zeichnung("z-3"), #"{"art":"zeichnung","id":"z-3"}"#),
        ]
        for (wahl, text) in erwartet {
            let wert = Backdrops.json(wahl)
            XCTAssertEqual(String(decoding: try encoder.encode(wert), as: UTF8.self), text)
            XCTAssertEqual(Backdrops.lesen(wert), wahl)
        }
    }
}
