import CoreGraphics
import ImageIO
import SwiftUI

/// Z-35: a drawing exported as PNG with a transparent background shows straight on the chat
/// wallpaper, barely visible. Detect that once per image and give the bubble a paper card instead.
enum TransparenzKarte {
    /// `brauchtKarte`: the image has real transparent area, not just a stray antialiased edge pixel.
    /// `dunkleKarte`: the opaque pixels are light overall (e.g. white paper exported with alpha), so a
    /// dark card keeps them readable; otherwise the default light paper card.
    struct Ergebnis: Equatable, Sendable { let brauchtKarte: Bool; let dunkleKarte: Bool }

    static let keineKarte = Ergebnis(brauchtKarte: false, dunkleKarte: false)

    /// Pure core (unit-tested): `rgba` is an interleaved RGBA8 buffer, e.g. a 32×32 downscale.
    static func auswerten(rgba: [UInt8]) -> Ergebnis {
        guard rgba.count >= 4, rgba.count.isMultiple(of: 4) else { return keineKarte }
        var transparentePixel = 0
        var helligkeitSumme = 0.0
        var opakeAnzahl = 0
        let pixelAnzahl = rgba.count / 4
        for i in stride(from: 0, to: rgba.count, by: 4) {
            let alpha = rgba[i + 3]
            if alpha < 250 { transparentePixel += 1 }
            if alpha > 10 {
                // ponytail: premultiplied RGB, not unpremultiplied — good enough for a light/dark
                // heuristic, not for colour-accurate rendering.
                helligkeitSumme += 0.299 * Double(rgba[i]) + 0.587 * Double(rgba[i + 1]) + 0.114 * Double(rgba[i + 2])
                opakeAnzahl += 1
            }
        }
        // A handful of antialiased edge pixels don't count as "has a transparent background".
        let brauchtKarte = Double(transparentePixel) / Double(pixelAnzahl) > 0.02
        guard brauchtKarte, opakeAnzahl > 0 else { return Ergebnis(brauchtKarte: brauchtKarte, dunkleKarte: false) }
        let mittlereHelligkeit = helligkeitSumme / Double(opakeAnzahl)
        return Ergebnis(brauchtKarte: true, dunkleKarte: mittlereHelligkeit > 170)
    }
}

/// Cheap per-image check, cached by media id so a row scrolling back into view doesn't redo it.
@MainActor
enum TransparenzCache {
    private static var cache: [String: TransparenzKarte.Ergebnis] = [:]

    static func ermitteln(id: String, url: URL) async -> TransparenzKarte.Ergebnis {
        if let bekannt = cache[id] { return bekannt }
        let ergebnis = await Task.detached(priority: .utility) { Self.pruefen(url) }.value
        cache[id] = ergebnis
        return ergebnis
    }

    /// Off the main actor: `alphaInfo` alone rules out the common case (a photo, no alpha channel)
    /// without decoding anything; only an image that actually has alpha gets downsampled and sampled.
    nonisolated private static func pruefen(_ url: URL) -> TransparenzKarte.Ergebnis {
        guard let quelle = CGImageSourceCreateWithURL(url as CFURL, nil),
              let bild = CGImageSourceCreateThumbnailAtIndex(quelle, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceShouldCacheImmediately: true,
                  kCGImageSourceThumbnailMaxPixelSize: 32,
              ] as CFDictionary)
        else { return TransparenzKarte.keineKarte }
        switch bild.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return TransparenzKarte.keineKarte
        default: break
        }
        guard let rgba = rgbaBytes(bild) else { return TransparenzKarte.keineKarte }
        return TransparenzKarte.auswerten(rgba: rgba)
    }

    nonisolated private static func rgbaBytes(_ bild: CGImage) -> [UInt8]? {
        let breite = bild.width, hoehe = bild.height
        guard breite > 0, hoehe > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: breite * hoehe * 4)
        let gezeichnet = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: breite, height: hoehe, bitsPerComponent: 8, bytesPerRow: breite * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(bild, in: CGRect(x: 0, y: 0, width: breite, height: hoehe))
            return true
        }
        return gezeichnet ? bytes : nil
    }
}

/// Shared paper-card look (Review r10-chatbild #1): padding + a rounded, colour-matched background
/// when `karte.brauchtKarte`, nothing otherwise. One wrapper so the single-image bubble, the
/// photo-stack tile and both full-screen viewers render the exact same card.
private struct TransparenteBildKarte: ViewModifier {
    let karte: TransparenzKarte.Ergebnis
    var eckenradius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(karte.brauchtKarte ? 12 : 0)
            .background {
                if karte.brauchtKarte {
                    RoundedRectangle(cornerRadius: eckenradius, style: .continuous)
                        .fill(karte.dunkleKarte ? Color(white: 0.12) : Color(white: 0.97))
                }
            }
    }
}

extension View {
    func transparenzKarte(_ karte: TransparenzKarte.Ergebnis, eckenradius: CGFloat = 18) -> some View {
        modifier(TransparenteBildKarte(karte: karte, eckenradius: eckenradius))
    }
}
