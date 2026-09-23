import Foundation

/// Pure downsampling for the voice-message waveform (Z-5.2): raw `AVAudioRecorder.averagePower`
/// dB samples (silence ≈ -160, loud ≈ 0) become at most `ziel` bars, normalized 0...1.
enum Wellenform {
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
