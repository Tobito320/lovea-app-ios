import XCTest

/// Z-14.10: every tool bar button is reachable by its VoiceOver label.
final class StudioToolbarUITests: XCTestCase {
    @MainActor
    func testToolbarButtonsHaveLabels() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestStudio"]
        app.launch()

        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let labels = isPad
            ? ["Pinsel", "Radierer", "Auswahl", "Füllen", "Pipette", "Formen", "Transformieren", "Text", "Foto", "Farbe"]
            : ["Pinsel", "Radierer", "Auswahl", "Füllen", "Farbe", "Ebenen", "Mehr Werkzeuge"]
        XCTAssertTrue(app.buttons["Pinsel"].waitForExistence(timeout: 20))
        for label in labels + ["Rückgängig", "Wiederholen", "Mehr"] {
            XCTAssertTrue(app.buttons[label].firstMatch.exists, "Knopf \(label) fehlt")
        }
    }
}
