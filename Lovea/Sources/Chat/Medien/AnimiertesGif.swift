import ImageIO
import SwiftUI
import UIKit

@MainActor
private enum GifDatenCache {
    /// The file bytes, not decoded frames: a few hundred KB to 1.5 MB per GIF.
    static let daten: NSCache<NSURL, NSData> = {
        let cache = NSCache<NSURL, NSData>()
        cache.totalCostLimit = 30_000_000
        return cache
    }()
}

/// GIF playback through ImageIO's own player (`CGAnimateImageDataWithBlock`), no third-party GIF
/// library (Z-5.3). Brief R: each frame shows for its own delay, and only the current frame is
/// decoded (before, every frame of the 100-frame kiss GIF sat decoded in memory, about 77 MB).
struct AnimiertesGif: View {
    let url: URL
    /// GIFs fill their cell (cropped); transparent sticker GIFs pass `false` and fit instead.
    var fuellen = true
    @State private var quelle: GifQuelle?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let quelle {
                // Reduce Motion (Z-16.3): the first frame stands still instead of looping forever.
                GifSpieler(quelle: quelle, fuellen: fuellen, still: reduceMotion)
            } else if fuellen {
                LadeSchimmer()
            } else {
                Color.clear
            }
        }
        .accessibilityElement()
        .accessibilityLabel("GIF")
        .task(id: url) { quelle = await lade(url) }
    }

    private func lade(_ url: URL) async -> GifQuelle? {
        let daten: Data
        if let gespeichert = GifDatenCache.daten.object(forKey: url as NSURL) {
            daten = gespeichert as Data
        } else {
            guard let (geladen, _) = try? await URLSession.shared.data(from: url) else { return nil }
            GifDatenCache.daten.setObject(geladen as NSData, forKey: url as NSURL, cost: geladen.count)
            daten = geladen
        }
        // Only the first frame is decoded up front, detached so it stays off the main actor (Z-16.2).
        return await Task.detached(priority: .userInitiated) { GifQuelle(url: url, daten: daten) }.value
    }
}

/// A loaded GIF: its bytes for the player and the first frame, shown at once and under Reduce Motion.
private struct GifQuelle: Sendable {
    let url: URL
    let daten: Data
    let erstesBild: UIImage

    init?(url: URL, daten: Data) {
        guard let quelle = CGImageSourceCreateWithData(daten as CFData, nil),
              let bild = CGImageSourceCreateImageAtIndex(quelle, 0, nil) else { return nil }
        self.url = url
        self.daten = daten
        erstesBild = UIImage(cgImage: bild)
    }
}

/// Fix round 2: a bare `UIImageView` reports the GIF's pixel size as its intrinsic size, so SwiftUI
/// laid GIFs out at full pixel size and they spilled over their cells. It now takes exactly the
/// size SwiftUI proposes, fills it and clips.
private struct GifSpieler: UIViewRepresentable {
    let quelle: GifQuelle
    let fuellen: Bool
    let still: Bool

    func makeUIView(context: Context) -> GifAnsicht {
        let view = GifAnsicht()
        view.clipsToBounds = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: GifAnsicht, context: Context) {
        uiView.contentMode = fuellen ? .scaleAspectFill : .scaleAspectFit
        uiView.zeigen(quelle, still: still)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: GifAnsicht, context: Context) -> CGSize? {
        let seite = quelle.erstesBild.size
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

// ponytail: frames decode at the GIF's own pixel size (CGAnimate has no downsampling option); fine
// for chat GIFs and the 480x400 stickers, a custom CGImageSource thumbnail player if huge GIFs show up.
/// Plays while it is in a window: ImageIO calls back on the main queue with each frame at its
/// delay. Leaving the window (scrolled away, sheet closed) stops the player; coming back starts it
/// again from the first frame.
private final class GifAnsicht: UIImageView {
    private var quelle: GifQuelle?
    private var still = false
    /// Bumped on every (re)start and stop; a running player sees the change on its next frame and ends.
    private var lauf = 0

    func zeigen(_ neu: GifQuelle, still: Bool) {
        guard neu.url != quelle?.url || still != self.still else { return }
        quelle = neu
        self.still = still
        image = neu.erstesBild
        starten()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        starten()
    }

    private func starten() {
        lauf += 1
        guard let quelle, !still, window != nil else { return }
        let meiner = lauf
        _ = CGAnimateImageDataWithBlock(quelle.daten as CFData, nil) { [weak self] _, bild, stop in
            let frame = UIImage(cgImage: bild)
            let weiter = MainActor.assumeIsolated { () -> Bool in
                guard let self, self.lauf == meiner else { return false }
                self.image = frame
                return true
            }
            if !weiter { stop.pointee = true }
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
