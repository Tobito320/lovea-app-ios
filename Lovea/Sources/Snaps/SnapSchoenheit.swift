import CoreImage
import UIKit

/// Z-R9: subtle front-camera beauty — a gentle skin smoothing + brightening, blended at low
/// intensity so it never looks plastic. Runs once per captured photo, off the main thread, never
/// live on the preview (battery). `staerke` is the one tunable knob, kept as a pure, testable
/// function so the blend math can be checked without CoreImage/a device.
enum SnapSchoenheit {
    /// Ahmed's spec: "~25-30 %". Not a magic literal buried in the filter code — named and clamped
    /// so a caller can never accidentally blend past "plastic" (1) or do nothing (0).
    static let staerke: Double = 0.28

    /// Clamps any proposed blend strength to 0...1. Pure, no CoreImage — the part worth a unit test.
    static func geklemmteStaerke(_ wert: Double) -> Double {
        min(max(wert, 0), 1)
    }

    /// ponytail: plain Gaussian blur + brightness blended at `staerke`, no Vision face mask — a
    /// mask would target skin only and leave eyes/hair untouched, but a full-frame blend at this
    /// low an intensity already reads as "subtle glow", not smoothing errors on hair/eyes. Add a
    /// `CIPersonSegmentation`/Vision face mask if a real selfie shows smoothing where it shouldn't.
    static func angewendet(auf bild: UIImage, staerke: Double = Self.staerke) -> UIImage {
        let staerke = geklemmteStaerke(staerke)
        guard staerke > 0, let eingabe = CIImage(image: bild) else { return bild }

        let weichgezeichnet = eingabe.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 3.5])
            .cropped(to: eingabe.extent)

        let aufgehellt = weichgezeichnet.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.2])

        // Blend toward the smoothed+brightened version by `staerke`, not a hard swap — this is the
        // "never plastic-looking" lever: `0` = untouched original, `1` = fully smoothed/brightened.
        // Setting the processed image's own alpha to `staerke` and compositing it over the
        // untouched original does exactly that linear blend, no extra mask image needed.
        let fuerBlend = aufgehellt.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: staerke)])
        let kombiniert = fuerBlend.composited(over: eingabe)

        // ponytail: a fresh `CIContext` per photo (GPU-backed, ~ms setup) instead of a shared one —
        // this only runs once per capture, not per frame; share one if beauty ever runs live.
        let context = CIContext()
        guard let ausgabe = context.createCGImage(kombiniert, from: eingabe.extent) else { return bild }
        return UIImage(cgImage: ausgabe, scale: bild.scale, orientation: bild.imageOrientation)
    }
}
