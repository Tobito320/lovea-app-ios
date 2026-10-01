import XCTest
@testable import Lovea

final class ZurueckWischenSystemklassenTests: XCTestCase {
    func testEigeneNavigationStackNichtGesperrt() {
        // SwiftUI nutzt ab iOS 16 eine eigene Unterklasse, nicht `UINavigationController` selbst.
        XCTAssertFalse(ZurueckWischenSystemklassen.istGesperrt(klassenkette: [
            "UIKitNavigationController", "UINavigationController", "UIViewController", "NSObject",
        ]))
    }

    func testPlainerNavigationControllerNichtGesperrt() {
        XCTAssertFalse(ZurueckWischenSystemklassen.istGesperrt(klassenkette: [
            "UINavigationController", "UIViewController", "NSObject",
        ]))
    }

    func testBildauswahlGesperrt() {
        XCTAssertTrue(ZurueckWischenSystemklassen.istGesperrt(klassenkette: [
            "UIImagePickerController", "UINavigationController", "UIViewController", "NSObject",
        ]))
    }

    func testUnterklasseEinerGesperrtenKlasseBleibtGesperrt() {
        // Deckt eine private Apple-Unterklasse von UIImagePickerController ab, falls es die je gibt.
        XCTAssertTrue(ZurueckWischenSystemklassen.istGesperrt(klassenkette: [
            "_UIImagePickerControllerIntern", "UIImagePickerController", "UINavigationController",
            "UIViewController", "NSObject",
        ]))
    }

    func testMailUndSmsGesperrt() {
        XCTAssertTrue(ZurueckWischenSystemklassen.istGesperrt(klassenkette: ["MFMailComposeViewController"]))
        XCTAssertTrue(ZurueckWischenSystemklassen.istGesperrt(klassenkette: ["MFMessageComposeViewController"]))
        XCTAssertTrue(ZurueckWischenSystemklassen.istGesperrt(klassenkette: ["UIVideoEditorController"]))
    }

    func testLeereKetteNichtGesperrt() {
        XCTAssertFalse(ZurueckWischenSystemklassen.istGesperrt(klassenkette: []))
    }
}
