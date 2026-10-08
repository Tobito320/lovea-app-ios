import AVFoundation
import XCTest
@testable import Lovea

/// Ahmeds Video mit Ton kam bei Annika stumm an. Diese Tests sichern, dass jeder Schritt der
/// Sende-Kette (Schnitt, Filter/Overlay, Kodierung fuers Senden) die Tonspur behaelt.
final class VideoTonTests: XCTestCase {

    // MARK: - Testvideo

    /// 1 s langes Testvideo; mit `mitTon` zusaetzlich eine AAC-Tonspur. Bild und Ton einzeln
    /// geschrieben und per Composition zusammengesetzt, das braucht keine Sample-Buffer von Hand.
    static func testVideo(mitTon: Bool, groesse: CGSize = CGSize(width: 320, height: 240)) async throws -> URL {
        let bildURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        try await bildSchreiben(nach: bildURL, groesse: groesse)
        guard mitTon else { return bildURL }

        let tonURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try tonSchreiben(nach: tonURL)

        let bildAsset = AVURLAsset(url: bildURL)
        let tonAsset = AVURLAsset(url: tonURL)
        let komposition = AVMutableComposition()
        let dauer = CMTime(seconds: 1, preferredTimescale: 600)
        guard let bildQuelle = try await bildAsset.loadTracks(withMediaType: .video).first,
              let tonQuelle = try await tonAsset.loadTracks(withMediaType: .audio).first,
              let bildZiel = komposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let tonZiel = komposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw XCTSkip("Testvideo liess sich nicht zusammensetzen") }
        try bildZiel.insertTimeRange(CMTimeRange(start: .zero, duration: dauer), of: bildQuelle, at: .zero)
        try tonZiel.insertTimeRange(CMTimeRange(start: .zero, duration: dauer), of: tonQuelle, at: .zero)

        guard let session = AVAssetExportSession(asset: komposition, presetName: AVAssetExportPresetPassthrough) else {
            throw XCTSkip("Kein Passthrough-Export")
        }
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        session.outputURL = ziel
        session.outputFileType = .mov
        await withCheckedContinuation { (fortsetzung: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { fortsetzung.resume() }
        }
        guard session.status == .completed else { throw XCTSkip("Testvideo mit Ton nicht erzeugt") }
        return ziel
    }

    private static func bildSchreiben(nach url: URL, groesse: CGSize) async throws {
        let schreiber = try AVAssetWriter(outputURL: url, fileType: .mov)
        let eingang = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(groesse.width),
            AVVideoHeightKey: Int(groesse.height),
        ])
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: eingang, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(groesse.width),
            kCVPixelBufferHeightKey as String: Int(groesse.height),
        ])
        schreiber.add(eingang)
        guard schreiber.startWriting() else { throw schreiber.error ?? CocoaError(.fileWriteUnknown) }
        schreiber.startSession(atSourceTime: .zero)
        for nummer in 0..<10 {
            var puffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, Int(groesse.width), Int(groesse.height), kCVPixelFormatType_32BGRA, nil, &puffer)
            guard let puffer else { throw CocoaError(.fileWriteUnknown) }
            while !eingang.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            guard adapter.append(puffer, withPresentationTime: CMTime(value: CMTimeValue(nummer), timescale: 10)) else {
                throw schreiber.error ?? CocoaError(.fileWriteUnknown)
            }
        }
        eingang.markAsFinished()
        await schreiber.finishWriting()
        guard schreiber.status == .completed else { throw schreiber.error ?? CocoaError(.fileWriteUnknown) }
    }

    private static func tonSchreiben(nach url: URL) throws {
        let datei = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
        ])
        let rahmen: AVAudioFrameCount = 44100
        guard let puffer = AVAudioPCMBuffer(pcmFormat: datei.processingFormat, frameCapacity: rahmen),
              let kanal = puffer.floatChannelData?[0]
        else { throw CocoaError(.fileWriteUnknown) }
        puffer.frameLength = rahmen
        for i in 0..<Int(rahmen) { kanal[i] = 0.3 * sinf(Float(i) * 0.06) }
        try datei.write(from: puffer)
    }

    static func tonSpuren(_ url: URL) async -> Int {
        ((try? await AVURLAsset(url: url).loadTracks(withMediaType: .audio)) ?? []).count
    }

    // MARK: - Tests

    func testTestvideoHatTonspur() async throws {
        let mitTon = try await Self.testVideo(mitTon: true)
        let ohneTon = try await Self.testVideo(mitTon: false)
        let spurenMit = await Self.tonSpuren(mitTon)
        let spurenOhne = await Self.tonSpuren(ohneTon)
        XCTAssertEqual(spurenMit, 1, "Testvideo muss Ton haben, sonst beweisen die anderen Tests nichts")
        XCTAssertEqual(spurenOhne, 0)
    }

    /// Senden mit Schalter "schneller" AN und einem Video ueber 1280 Kante: kodiert neu (720p).
    func testSendeKodierungSchnellBehaeltTon() async throws {
        let schluessel = MedienKodierung.videoSchnellSchluessel
        UserDefaults.standard.set(true, forKey: schluessel)
        defer { UserDefaults.standard.removeObject(forKey: schluessel) }
        let quelle = try await Self.testVideo(mitTon: true, groesse: CGSize(width: 1920, height: 1080))
        guard let ergebnis = await MedienKodierung.video(quelle, id: UUID().uuidString) else {
            throw XCTSkip("Encoder nicht verfuegbar")
        }
        let spuren = await Self.tonSpuren(ergebnis.original)
        XCTAssertEqual(spuren, 1, "Gesendetes Video hat die Tonspur verloren")
    }

    /// Schalter AUS: HEVC-Original plus 480p-`klein`, beide mit Ton.
    func testSendeKodierungLangsamBehaeltTonInOriginalUndKlein() async throws {
        let schluessel = MedienKodierung.videoSchnellSchluessel
        UserDefaults.standard.set(false, forKey: schluessel)
        defer { UserDefaults.standard.removeObject(forKey: schluessel) }
        let quelle = try await Self.testVideo(mitTon: true)
        guard let ergebnis = await MedienKodierung.video(quelle, id: UUID().uuidString) else {
            throw XCTSkip("Encoder nicht verfuegbar")
        }
        let original = await Self.tonSpuren(ergebnis.original)
        XCTAssertEqual(original, 1)
        if let klein = ergebnis.klein {
            let spurenKlein = await Self.tonSpuren(klein)
            XCTAssertEqual(spurenKlein, 1)
        }
    }

    func testSchnittBehaeltTonAusserBeiStumm() async throws {
        let quelle = try await Self.testVideo(mitTon: true)
        var plan = SnapSchnitt(dauer: 1)
        let gekuerzt = plan.kuerzen(anfang: 0.2, ende: 1)
        XCTAssertTrue(gekuerzt)
        guard let mitTon = await SnapSchnittExport.exportieren(quelle: quelle, plan: plan) else {
            throw XCTSkip("Encoder nicht verfuegbar")
        }
        let spurenMit = await Self.tonSpuren(mitTon)
        XCTAssertEqual(spurenMit, 1, "Schnitt darf den Ton nicht verwerfen")

        plan.stumm = true
        guard let stumm = await SnapSchnittExport.exportieren(quelle: quelle, plan: plan) else {
            throw XCTSkip("Encoder nicht verfuegbar")
        }
        let spurenStumm = await Self.tonSpuren(stumm)
        XCTAssertEqual(spurenStumm, 0, "Ton aus muss den Ton entfernen")
    }

    @MainActor
    func testSnapExportMitTextUndFilterBehaeltTon() async throws {
        let quelle = try await Self.testVideo(mitTon: true)
        var text = SnapEditor.SnapText()
        text.text = "Hallo"
        guard let ergebnis = await SnapExport.video(quelle: quelle, linien: [], sticker: [], text: text, filter: .mono) else {
            throw XCTSkip("Encoder nicht verfuegbar")
        }
        let spuren = await Self.tonSpuren(ergebnis)
        XCTAssertEqual(spuren, 1, "Snap-Export mit Filter und Text hat die Tonspur verloren")
    }
}
