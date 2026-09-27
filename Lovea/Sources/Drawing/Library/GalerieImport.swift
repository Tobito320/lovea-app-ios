import Foundation
import ImageIO

/// Toolbar import ("Aus Fotos" / "Aus Dateien"): reads an image's pixel size so the new drawing's
/// canvas can match it exactly, same EXIF-orientation handling as `MedienKodierung.foto`.
enum GalerieImport {
    struct PixelSize {
        let width: Int
        let height: Int
        let orientation: Int
    }

    /// Raw pixel size + EXIF orientation via ImageIO, without decoding the full image.
    nonisolated static func pixelSize(of data: Data) -> PixelSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let orientation = (props[kCGImagePropertyOrientation] as? Int) ?? 1
        return PixelSize(width: width, height: height, orientation: orientation)
    }

    /// Canvas size for a new artwork from an imported image: pixel size with EXIF orientation
    /// applied (5–8 swap width/height, same as `MedienKodierung.foto`), clamped like any other
    /// custom-size artwork (`ArtworkLibrary.clampDimension`).
    nonisolated static func canvasSize(pixelWidth: Int, pixelHeight: Int, orientation: Int) -> (width: Double, height: Double) {
        let gedreht = (5...8).contains(orientation)
        let width = Double(gedreht ? pixelHeight : pixelWidth)
        let height = Double(gedreht ? pixelWidth : pixelHeight)
        // Scale down as a whole first: clamping each side alone turned a 48 MP photo (8064x6048)
        // into a 4096x4096 square and squashed the image.
        let faktor = min(1, 4096 / max(width, height, 1))
        return (ArtworkLibrary.clampDimension(width * faktor), ArtworkLibrary.clampDimension(height * faktor))
    }
}
