import UIKit
import XCTest
@testable import Lovea

/// Audit chat #1: the upload's `typ` comes from the file content, not the (missing) extension.
@MainActor
final class MedienTypTests: XCTestCase {

    private func iso(_ marke: String) -> Data {
        Data([0x00, 0x00, 0x00, 0x18]) + Data("ftyp\(marke)".utf8) + Data(repeating: 0, count: 8)
    }

    func testKnownFormats() {
        XCTAssertEqual(Medien.inhaltsTyp(Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])), "image/jpeg")
        XCTAssertEqual(Medien.inhaltsTyp(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), "image/png")
        XCTAssertEqual(Medien.inhaltsTyp(Data("GIF89a".utf8)), "image/gif")
        XCTAssertEqual(Medien.inhaltsTyp(iso("qt  ")), "video/quicktime")
        XCTAssertEqual(Medien.inhaltsTyp(iso("isom")), "video/mp4")
        XCTAssertEqual(Medien.inhaltsTyp(iso("mp42")), "video/mp4")
        XCTAssertEqual(Medien.inhaltsTyp(iso("M4A ")), "audio/m4a")
        XCTAssertEqual(Medien.inhaltsTyp(iso("heic")), "image/heic")
        XCTAssertEqual(Medien.inhaltsTyp(iso("mif1")), "image/heic")
    }

    func testUnknownOrShortContentIsOctetStream() {
        XCTAssertEqual(Medien.inhaltsTyp(Data()), "application/octet-stream")
        XCTAssertEqual(Medien.inhaltsTyp(Data("{\"ebenen\":[]}".utf8)), "application/octet-stream")
        XCTAssertEqual(Medien.inhaltsTyp(Data([0x00, 0x00, 0x00, 0x18]) + Data("ftyp".utf8)), "application/octet-stream")
    }

    /// Real encoders: what the app actually uploads for photos.
    func testRealImageEncodings() throws {
        let bild = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { kontext in
            UIColor.red.setFill()
            kontext.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        XCTAssertEqual(Medien.inhaltsTyp(try XCTUnwrap(bild.jpegData(compressionQuality: 0.7))), "image/jpeg")
        XCTAssertEqual(Medien.inhaltsTyp(try XCTUnwrap(bild.pngData())), "image/png")
    }
}
