import AVFoundation
import Foundation

/// Pure downsampling for the voice-message waveform (Z-5.2): raw `AVAudioRecorder.averagePower`
/// dB samples (silence ≈ -160, loud ≈ 0) become at most `ziel` bars, normalized 0...1.
enum Wellenform {
    /// audit-chat #3: a restored voice draft (after relaunch/reinstall) has no live `averagePower`
    /// samples — only the m4a file. Reads its PCM frames directly and buckets their RMS the same
    /// way a live recording's dB samples are bucketed, so the restored bar looks like any other.
    nonisolated static func ausDatei(_ url: URL, ziel: Int = 64) -> [Float] {
        guard let datei = try? AVAudioFile(forReading: lesbareDatei(url)) else { return [] }
        let rahmen = AVAudioFrameCount(datei.length)
        guard rahmen > 0, let puffer = AVAudioPCMBuffer(pcmFormat: datei.processingFormat, frameCapacity: rahmen),
              (try? datei.read(into: puffer)) != nil, let kanal = puffer.floatChannelData?[0]
        else { return [] }
        let anzahl = Int(puffer.frameLength)
        guard anzahl > 0 else { return [] }
        let bucket = max(1, anzahl / max(1, ziel))
        var dB: [Float] = []
        var i = 0
        while i < anzahl {
            let ende = min(i + bucket, anzahl)
            var summe: Float = 0
            for j in i..<ende { summe += kanal[j] * kanal[j] }
            let rms = sqrt(summe / Float(ende - i))
            dB.append(rms > 0 ? 20 * log10(rms) : -160)
            i = ende
        }
        return downsample(dB, ziel: ziel)
    }

    /// `Medien.holen`'s cache has no file extension (`Lovea/medien/<id>`), so `AVAudioFile` (which,
    /// unlike `AVAudioPlayer`, picks its container parser from the extension) can't open it directly
    /// — same issue `Videobild.abspielbar` works around for video (168838f). Voice messages are
    /// always m4a (`MedienKodierung`); a hard link next to the file is instant and needs no copy.
    private nonisolated static func lesbareDatei(_ url: URL) -> URL {
        guard url.pathExtension.isEmpty else { return url }
        let link = url.appendingPathExtension("m4a")
        if !FileManager.default.fileExists(atPath: link.path) { try? FileManager.default.linkItem(at: url, to: link) }
        return FileManager.default.fileExists(atPath: link.path) ? link : url
    }

    nonisolated static func downsample(_ dB: [Float], ziel: Int = 64) -> [Float] {
        guard !dB.isEmpty, ziel > 0 else { return [] }
        let normalisiert = dB.map(normalisieren)
        guard normalisiert.count > ziel else { return normalisiert }
        let bucket = Double(normalisiert.count) / Double(ziel)
        return (0..<ziel).map { i -> Float in
            let start = Int(Double(i) * bucket)
            let ende = max(start + 1, min(normalisiert.count, Int(Double(i + 1) * bucket)))
            let slice = normalisiert[start..<ende]
            return slice.isEmpty ? 0 : slice.reduce(0, +) / Float(slice.count)
        }
    }

    /// -50 dB and quieter reads as silence (0); 0 dB (loudest) is 1.
    private nonisolated static func normalisieren(_ dB: Float) -> Float {
        guard dB.isFinite else { return 0 }
        let boden: Float = -50
        return min(1, max(0, (dB - boden) / -boden))
    }
}
