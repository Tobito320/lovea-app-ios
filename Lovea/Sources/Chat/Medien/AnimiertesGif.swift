import ImageIO
import SwiftUI
import UIKit

private enum AnimiertesGifCache {
    // ponytail: `NSCache` is documented thread-safe (Apple: "you can add, remove, and query items
    // in the cache from different threads without having to lock the cache yourself"), it's just
    // not marked `Sendable`. `nonisolated(unsafe)` instead of `@MainActor` — `lade(_:)` below reads
    // it from a background `Task`, not the main actor.
    nonisolated(unsafe) static let bilder = NSCache<NSURL, UIImage>()
}

/// GIF playback via `UIImage.animatedImage` built from ImageIO frames — no third-party GIF library
/// (Z-5.3). `UIImageView` then free-runs the animation itself.
struct AnimiertesGif: View {
    let url: URL
    /// GIFs fill their cell (cropped); transparent sticker GIFs pass `false` and fit instead.
    var fuellen = true
    @State private var bild: UIImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let bild {
                // Reduce Motion (Z-16.3): the first frame stands still instead of looping forever.
                AnimiertesGifDarstellung(bild: reduceMotion ? (bild.images?.first ?? bild) : bild, fuellen: fuellen)
            } else if fuellen {
                LadeSchimmer()
            } else {
                Color.clear
            }
        }
        .accessibilityElement()
        .accessibilityLabel("GIF")
        .task(id: url) { bild = await lade(url) }
    }

    private func lade(_ url: URL) async -> UIImage? {
        if let cached = AnimiertesGifCache.bilder.object(forKey: url as NSURL) { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        // Every frame is decoded here — detached, or it would run on the main actor with this View (Z-16.2).
        guard let bild = await Task.detached(priority: .userInitiated, operation: { AnimiertesGif.animiertesBild(from: data) }).value
        else { return nil }
        AnimiertesGifCache.bilder.setObject(bild, forKey: url as NSURL)
        return bild
    }

    nonisolated static func animiertesBild(from data: Data) -> UIImage? {
        guard let quelle = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let anzahl = CGImageSourceGetCount(quelle)
        guard anzahl > 1 else { return UIImage(data: data) }
        var bilder: [UIImage] = []
        var gesamtDauer: Double = 0
        for index in 0..<anzahl {
            guard let cgImage = CGImageSourceCreateImageAtIndex(quelle, index, nil) else { continue }
            bilder.append(UIImage(cgImage: cgImage))
            gesamtDauer += frameDauer(quelle, index)
        }
        guard !bilder.isEmpty else { return nil }
        return UIImage.animatedImage(with: bilder, duration: gesamtDauer > 0 ? gesamtDauer : Double(bilder.count) * 0.1)
    }

    private nonisolated static func frameDauer(_ quelle: CGImageSource, _ index: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(quelle, index, nil) as? [CFString: Any],
              let gifProps = props[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return 0.1 }
        let verzoegerung = (gifProps[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gifProps[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
        return max(verzoegerung, 0.02)
    }
}

/// Fix round 2: a bare `UIImageView` reports the GIF's pixel size as its intrinsic size, so SwiftUI
/// laid GIFs out at full pixel size and they spilled over their cells. It now takes exactly the
/// size SwiftUI proposes, fills it and clips.
private struct AnimiertesGifDarstellung: UIViewRepresentable {
    let bild: UIImage
    let fuellen: Bool

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView(image: bild)
        view.contentMode = fuellen ? .scaleAspectFill : .scaleAspectFit
        view.clipsToBounds = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) { uiView.image = bild }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        let seite = bild.size
        let verhaeltnis = seite.height > 0 && seite.width > 0 ? seite.width / seite.height : 1
        let breite = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        let hoehe = proposal.height.flatMap { $0.isFinite ? $0 : nil }
        switch (breite, hoehe) {
        case let (b?, h?): return CGSize(width: b, height: h)
        case let (b?, nil): return CGSize(width: b, height: b / verhaeltnis)
        case let (nil, h?): return CGSize(width: h * verhaeltnis, height: h)
        default: return CGSize(width: 120, height: 120 / verhaeltnis)
        }
    }
}

/// Neutral loading placeholder with a soft moving sheen (still under Reduce Motion).
struct LadeSchimmer: View {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(Color(uiColor: .tertiarySystemFill))
            .overlay {
                LinearGradient(colors: [.clear, .white.opacity(0.18), .clear], startPoint: .leading, endPoint: .trailing)
                    .scaleEffect(x: 0.6, anchor: .center)
                    .offset(x: phase * 160)
                    .opacity(reduceMotion ? 0 : 1)
            }
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}
