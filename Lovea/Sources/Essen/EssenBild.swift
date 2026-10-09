import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Verkleinert Fotos vor dem Hochladen: längste Kante höchstens 1024 px, JPEG. Das spart Kosten und
/// Zeit, und es werden bewusst keine Metadaten (Ort, Zeit, Gerät) mitgeschickt.
enum EssenBild {
    static func verkleinern(_ daten: Data, maxKante: Int = 1024, qualitaet: Double = 0.7) -> Data? {
        guard let quelle = CGImageSourceCreateWithData(daten as CFData, nil) else { return nil }
        let optionen: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxKante,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let bild = CGImageSourceCreateThumbnailAtIndex(quelle, 0, optionen as CFDictionary) else { return nil }
        let ausgabe = NSMutableData()
        guard let ziel = CGImageDestinationCreateWithData(ausgabe, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(ziel, bild, [kCGImageDestinationLossyCompressionQuality: qualitaet] as CFDictionary)
        guard CGImageDestinationFinalize(ziel) else { return nil }
        return ausgabe as Data
    }
}
