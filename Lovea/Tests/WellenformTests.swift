import AVFoundation
import XCTest
@testable import Lovea

/// audit-chat #3: `Wellenform.downsample` (existing pure bucketing) and the new `ausDatei` (reads a
/// voice draft's m4a directly, restoring real levels instead of a flat placeholder).
final class WellenformTests: XCTestCase {
    func testDownsampleLeer() {
        XCTAssertEqual(Wellenform.downsample([]), [])
    }

    func testDownsampleNormalisiertAufNullBisEins() {
        // 0 dB (loudest) -> 1, -50 dB (floor) -> 0, -160 dB (silence) -> clamped to 0.
        let werte = Wellenform.downsample([0, -50, -160], ziel: 3)
        XCTAssertEqual(werte.count, 3)
        XCTAssertEqual(werte[0], 1, accuracy: 0.001)
        XCTAssertEqual(werte[1], 0, accuracy: 0.001)
        XCTAssertEqual(werte[2], 0, accuracy: 0.001)
    }

    func testAusDateiOhneDateiIstLeer() {
        XCTAssertEqual(Wellenform.ausDatei(URL(fileURLWithPath: "/nicht/vorhanden.m4a")), [])
    }

    func testAusDateiBerechnetPegelAusEinemLautenTon() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WellenformTest-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1))
        do {
            // Scoped so the writer is deallocated (finalizing the file header) before `ausDatei`
            // opens the same URL for reading below — `AVAudioFile` only flushes complete frame
            // counts to the header on close/dealloc, not on every `write(from:)`.
            let datei = try AVAudioFile(forWriting: url, settings: format.settings)
            let rahmen: AVAudioFrameCount = 8000 // 1 s
            let puffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: rahmen))
            puffer.frameLength = rahmen
            let kanal = try XCTUnwrap(puffer.floatChannelData?[0])
            for i in 0..<Int(rahmen) { kanal[i] = sin(Float(i) * 0.2) * 0.8 } // loud, not silent
            try datei.write(from: puffer)
        }

        let pegel = Wellenform.ausDatei(url, ziel: 16)
        XCTAssertEqual(pegel.count, 16)
        // A loud tone must not read back as the flat/near-silent placeholder.
        XCTAssertGreaterThan(pegel.max() ?? 0, 0.5)
    }
}
