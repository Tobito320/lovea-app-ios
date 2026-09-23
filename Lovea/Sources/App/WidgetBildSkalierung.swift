import Foundation
import ImageIO
import UniformTypeIdentifiers

/// JPEG-Miniatur über ImageIO — nicht der UIKit-Bild-Renderer, den `ios-ci.yml`s Muster-Check nur
/// in `*Export.swift`-Dateien erlaubt, und ImageIO braucht sowieso kein volles Bild-Decode.
/// Für das "Foto und Frage"-Widget (Z-28.3): das letzte Partnerfoto, downskaliert.
enum WidgetBildSkalierung {
    static func miniatur(von quelle: URL, langeKante: CGFloat) -> Data? {
        guard let quelleRef = CGImageSourceCreateWithURL(quelle as CFURL, nil) else { return nil }
        let optionen: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: langeKante,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let bild = CGImageSourceCreateThumbnailAtIndex(quelleRef, 0, optionen as CFDictionary) else { return nil }
        let ziel = NSMutableData()
        guard let schreiber = CGImageDestinationCreateWithData(ziel, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(schreiber, bild, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(schreiber) else { return nil }
        return ziel as Data
    }
}
