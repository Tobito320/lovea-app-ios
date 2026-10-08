import SwiftUI

/// Tap-to-place math of the snap editor (the CapCut chrome lives in `SnapEditorPanels`).

/// Pure math for "tap the photo to put text there". Positions are fractions (0...1) of the content
/// box, like every other editor element, so live preview and export agree.
enum SnapTextPlatz {
    /// A touch that moved less than this (points, both axes) is a tap, not a swipe or a stroke.
    static let tippGrenze: CGFloat = 10

    /// Keeps the text fully on the photo: x within 0.12...0.88, y within 0.08...0.92.
    static let xBereich: ClosedRange<CGFloat> = 0.12...0.88
    static let yBereich: ClosedRange<CGFloat> = 0.08...0.92

    static func istTippen(_ verschiebung: CGSize) -> Bool {
        abs(verschiebung.width) < tippGrenze && abs(verschiebung.height) < tippGrenze
    }

    static func bruchteil(punkt: CGPoint, groesse: CGSize) -> CGPoint {
        guard groesse.width > 0, groesse.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return begrenzt(x: punkt.x / groesse.width, y: punkt.y / groesse.height)
    }

    static func begrenzt(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: min(max(xBereich.lowerBound, x), xBereich.upperBound),
                y: min(max(yBereich.lowerBound, y), yBereich.upperBound))
    }
}
