import AVFoundation
import CoreImage
import UIKit

/// ~15 ästhetische Snap-Filter (R9), reine Core-Image-Rezepte ohne Assets und ohne Netz. Jeder Fall
/// ist eine reine Funktion `CIImage -> CIImage`, `.original` ist die Identität. Deutsche Anzeigenamen
/// wie im Vorbild-Screenshot (Snapchat-Filterkarussell).
enum SnapFilter: String, CaseIterable, Identifiable, Sendable {
    case original, warm, kuehl, vivid, weichzeichner, film, vintage, mono, noir, chrome, matt, moody, pastell, sonnenuntergang, zeitstempel

    var id: String { rawValue }

    var anzeigename: String {
        switch self {
        case .original: return "Original"
        case .warm: return "Warm"
        case .kuehl: return "Kühl"
        case .vivid: return "Vivid"
        case .weichzeichner: return "Soft"
        case .film: return "Film"
        case .vintage: return "Vintage"
        case .mono: return "Mono"
        case .noir: return "Noir"
        case .chrome: return "Chrome"
        case .matt: return "Matt"
        case .moody: return "Moody"
        case .pastell: return "Pastell"
        case .sonnenuntergang: return "Sonnenuntergang"
        case .zeitstempel: return "Zeitstempel"
        }
    }

    /// Ein Context für alle Renderings (Vorschau, Thumbnails, Export, Video-Filterung). Aufbau ist
    /// teuer, laut Core-Image-Doku ist eine Instanz threadsicher für paralleles Rendern — Akku-Regel:
    /// einmal bauen, überall wiederverwenden statt pro Aufruf neu.
    static let context = CIContext()

    /// Reine Funktion: `bild` bleibt unverändert, nur das Ergebnis kommt zurück. Jeder Zweig croppt
    /// am Ende auf `bild.extent` — manche Bausteine (Rauschen, Vignette) liefern sonst eine andere
    /// Ausdehnung als der Input.
    func anwenden(auf bild: CIImage) -> CIImage {
        switch self {
        case .original:
            return bild
        case .warm:
            return Self.temperatur(bild, verschiebung: 1800).settingSaettigung(1.08).cropped(to: bild.extent)
        case .kuehl:
            return Self.temperatur(bild, verschiebung: -1800).cropped(to: bild.extent)
        case .vivid:
            return Self.farbregler(bild, saettigung: 1.35, kontrast: 1.08).cropped(to: bild.extent)
        case .weichzeichner:
            return Self.bloom(bild, radius: 8, intensitaet: 0.4).cropped(to: bild.extent)
        case .film:
            let basis = Self.farbregler(bild, saettigung: 0.92, kontrast: 0.95)
            let verblasst = Self.photoEffect(basis, name: "CIPhotoEffectFade")
            return Self.koernung(verblasst, intensitaet: 0.04).cropped(to: bild.extent)
        case .vintage:
            let sepia = Self.sepia(bild, intensitaet: 0.35)
            return Self.photoEffect(sepia, name: "CIPhotoEffectFade").cropped(to: bild.extent)
        case .mono:
            return Self.photoEffect(bild, name: "CIPhotoEffectMono").cropped(to: bild.extent)
        case .noir:
            let basis = Self.photoEffect(bild, name: "CIPhotoEffectNoir")
            return Self.farbregler(basis, saettigung: 1, kontrast: 1.15).cropped(to: bild.extent)
        case .chrome:
            return Self.photoEffect(bild, name: "CIPhotoEffectChrome").cropped(to: bild.extent)
        case .matt:
            return Self.photoEffect(bild, name: "CIPhotoEffectFade").cropped(to: bild.extent)
        case .moody:
            let dunkler = Self.belichtung(bild, ev: -0.5)
            let kontrast = Self.farbregler(dunkler, saettigung: 0.95, kontrast: 1.1)
            return Self.temperatur(kontrast, verschiebung: -400).cropped(to: bild.extent)
        case .pastell:
            let heller = Self.belichtung(bild, ev: 0.25)
            return Self.farbregler(heller, saettigung: 0.75, kontrast: 0.92).cropped(to: bild.extent)
        case .sonnenuntergang:
            let warm = Self.temperatur(bild, verschiebung: 2200)
            return Self.vignette(warm, radius: 1.2, intensitaet: 0.6).cropped(to: bild.extent)
        case .zeitstempel:
            return Self.mitZeitstempel(bild)
        }
    }

    // MARK: - CIFilter-Bausteine (private, reine Funktionen)

    private static func photoEffect(_ bild: CIImage, name: String) -> CIImage {
        guard let filter = CIFilter(name: name) else { return bild }
        filter.setValue(bild, forKey: kCIInputImageKey)
        return filter.outputImage ?? bild
    }

    private static func farbregler(_ bild: CIImage, saettigung: Double, kontrast: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return bild }
        filter.setValue(bild, forKey: kCIInputImageKey)
        filter.setValue(saettigung, forKey: kCIInputSaturationKey)
        filter.setValue(kontrast, forKey: kCIInputContrastKey)
        return filter.outputImage ?? bild
    }

    private static func belichtung(_ bild: CIImage, ev: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIExposureAdjust") else { return bild }
        filter.setValue(bild, forKey: kCIInputImageKey)
        filter.setValue(ev, forKey: kCIInputEVKey)
        return filter.outputImage ?? bild
    }

    private static func sepia(_ bild: CIImage, intensitaet: Double) -> CIImage {
        guard let filter = CIFilter(name: "CISepiaTone") else { return bild }
        filter.setValue(bild, forKey: kCIInputImageKey)
        filter.setValue(intensitaet, forKey: kCIInputIntensityKey)
        return filter.outputImage ?? bild
    }

    private static func temperatur(_ bild: CIImage, verschiebung: Double) -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else { return bild }
        filter.setValue(bild, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
        filter.setValue(CIVector(x: 6500 + verschiebung, y: 0), forKey: "inputTargetNeutral")
        return filter.outputImage ?? bild
    }

    private static func vignette(_ bild: CIImage, radius: Double, intensitaet: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIVignette") else { return bild }
        filter.setValue(bild, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(intensitaet, forKey: kCIInputIntensityKey)
        return filter.outputImage ?? bild
    }

    private static func bloom(_ bild: CIImage, radius: Double, intensitaet: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIBloom") else { return bild }
        filter.setValue(bild, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(intensitaet, forKey: kCIInputIntensityKey)
        return filter.outputImage ?? bild
    }

    /// Feines Filmkorn: `CIRandomGenerator` liefert unendliches Rauschen, auf die Bildgröße
    /// zugeschnitten, entsättigt und mit niedriger Deckkraft übers Bild gelegt.
    private static func koernung(_ bild: CIImage, intensitaet: Double) -> CIImage {
        guard let rauschen = CIFilter(name: "CIRandomGenerator")?.outputImage else { return bild }
        let monochrom = Self.photoEffect(rauschen, name: "CIPhotoEffectMono").cropped(to: bild.extent)
        guard let alpha = CIFilter(name: "CIColorMatrix") else { return bild }
        alpha.setValue(monochrom, forKey: kCIInputImageKey)
        alpha.setValue(CIVector(x: 0, y: 0, z: 0, w: intensitaet), forKey: "inputAVector")
        guard let koernungsEbene = alpha.outputImage, let compositing = CIFilter(name: "CISourceOverCompositing") else { return bild }
        compositing.setValue(koernungsEbene, forKey: kCIInputImageKey)
        compositing.setValue(bild, forKey: kCIInputBackgroundImageKey)
        return compositing.outputImage ?? bild
    }

    /// Originalfarben plus Uhrzeit, kursive Serife, zentriert — wie im Vorbild-Screenshot.
    private static func mitZeitstempel(_ bild: CIImage) -> CIImage {
        guard bild.extent.width > 0, bild.extent.height > 0, let ebene = Self.zeitstempelEbene(groesse: bild.extent.size) else { return bild }
        let verschoben = ebene.transformed(by: CGAffineTransform(translationX: bild.extent.origin.x, y: bild.extent.origin.y))
        guard let compositing = CIFilter(name: "CISourceOverCompositing") else { return bild }
        compositing.setValue(verschoben, forKey: kCIInputImageKey)
        compositing.setValue(bild, forKey: kCIInputBackgroundImageKey)
        return (compositing.outputImage ?? bild).cropped(to: bild.extent)
    }

    private static func zeitstempelEbene(groesse: CGSize) -> CIImage? {
        let formatierer = DateFormatter()
        formatierer.dateFormat = "HH:mm"
        let text = formatierer.string(from: Date()) as NSString

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let bild = UIGraphicsImageRenderer(size: groesse, format: format).image { _ in
            let schrift = UIFont.italicSystemFont(ofSize: groesse.width * 0.08)
            let absatz = NSMutableParagraphStyle()
            absatz.alignment = .center
            let schatten = NSShadow()
            schatten.shadowColor = UIColor.black.withAlphaComponent(0.6)
            schatten.shadowBlurRadius = 4
            let attribute: [NSAttributedString.Key: Any] = [.font: schrift, .foregroundColor: UIColor.white, .paragraphStyle: absatz, .shadow: schatten]
            let groesseText = text.size(withAttributes: attribute)
            let punkt = CGPoint(x: (groesse.width - groesseText.width) / 2, y: (groesse.height - groesseText.height) / 2)
            text.draw(at: punkt, withAttributes: attribute)
        }
        return bild.cgImage.map { CIImage(cgImage: $0) }
    }
}

private extension CIImage {
    func settingSaettigung(_ wert: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return self }
        filter.setValue(self, forKey: kCIInputImageKey)
        filter.setValue(wert, forKey: kCIInputSaturationKey)
        return filter.outputImage ?? self
    }
}

// MARK: - Video (Vorschau im Player & Export teilen sich diesen Aufbau)

extension SnapFilter {
    /// `AVVideoComposition(asset:applyingCIFiltersWithHandler:)` wendet `anwenden(auf:)` pro Frame an —
    /// dieselbe Rezept-Funktion wie beim Foto. `nil` bei `.original`, ein Composition-Objekt weniger
    /// zu bauen und zuzuweisen ist der einfachste "kein Filter"-Fall.
    @MainActor
    func videoKomposition(fuer asset: AVAsset) async -> AVVideoComposition? {
        guard self != .original else { return nil }
        return try? await AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: { anfrage in
            anfrage.finish(with: self.anwenden(auf: anfrage.sourceImage), context: SnapFilter.context)
        })
    }
}
