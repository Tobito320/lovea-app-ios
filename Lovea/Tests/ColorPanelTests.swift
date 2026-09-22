import XCTest
@testable import Lovea

@MainActor
final class ColorPanelTests: XCTestCase {
    private let tolerance = 1.0 / 255

    func testHSBRoundTripThroughRGB() {
        for hueStep in 0..<36 {
            for saturationStep in 0...8 {
                for brightnessStep in 0...8 {
                    let hsb = HSBColor(
                        hue: Double(hueStep) / 36,
                        saturation: Double(saturationStep) / 8,
                        brightness: Double(brightnessStep) / 8,
                        alpha: 0.5
                    )
                    let back = RGBAColor(hsb: hsb).hsb

                    XCTAssertEqual(back.brightness, hsb.brightness, accuracy: tolerance)
                    XCTAssertEqual(back.alpha, hsb.alpha, accuracy: tolerance)
                    guard hsb.brightness > 0.001 else { continue }
                    XCTAssertEqual(back.saturation, hsb.saturation, accuracy: tolerance)
                    guard hsb.saturation > 0.001 else { continue }
                    let hueDistance = abs(back.hue - hsb.hue)
                    XCTAssertLessThanOrEqual(min(hueDistance, 1 - hueDistance), tolerance, "\(hsb)")
                }
            }
        }
    }

    func testHexRoundTrip() {
        XCTAssertEqual(RGBAColor(hex: "#1A2B3C")?.hex, "#1A2B3C")
        XCTAssertEqual(RGBAColor(hex: "ff8000")?.hex, "#FF8000")
        XCTAssertEqual(RGBAColor(hex: "#FFFFFF"), RGBAColor(red: 1, green: 1, blue: 1))
        XCTAssertNil(RGBAColor(hex: "12345"))
        XCTAssertNil(RGBAColor(hex: "#GGGGGG"))
        XCTAssertNil(RGBAColor(hex: "+12345"))
        XCTAssertNil(RGBAColor(hex: ""))

        for value in stride(from: 0, through: 255, by: 17) {
            let color = RGBAColor(red: Double(value) / 255, green: Double(255 - value) / 255, blue: 0.5)
            XCTAssertEqual(RGBAColor(hex: color.hex)?.hex, color.hex)
        }
    }

    func testPaletteIsStoredPerPerson() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let color = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)

        ColorPaletteStore(person: "ahmed", defaults: defaults).store(color, at: 3)

        let reloaded = ColorPaletteStore(person: "ahmed", defaults: defaults)
        XCTAssertEqual(reloaded.palette.count, 16)
        XCTAssertEqual(reloaded.palette[3], color)
        XCTAssertEqual(ColorPaletteStore(person: "annika", defaults: defaults).palette, ColorPaletteStore.defaultPalette)
    }

    func testDefaultsHaveSixteenSlotsAndNoRecent() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = ColorPaletteStore(person: "ahmed", defaults: defaults)

        XCTAssertEqual(store.palette.count, 16)
        XCTAssertTrue(store.recent.isEmpty)
    }

    func testRecentMovesDuplicatesToFront() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = ColorPaletteStore(person: "ahmed", defaults: defaults)
        let a = RGBAColor(red: 1, green: 0, blue: 0)
        let b = RGBAColor(red: 0, green: 1, blue: 0)

        store.use(a)
        store.use(b)
        store.use(a)

        XCTAssertEqual(store.recent, [a, b])
        XCTAssertEqual(ColorPaletteStore(person: "ahmed", defaults: defaults).recent, [a, b])
    }

    func testRecentKeepsEightNewestFirst() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = ColorPaletteStore(person: "ahmed", defaults: defaults)
        let colors = (0..<10).map { RGBAColor(red: Double($0) / 10, green: 0, blue: 0) }

        for color in colors {
            store.use(color)
        }

        XCTAssertEqual(store.recent, Array(colors.reversed().prefix(8)))
    }
}
