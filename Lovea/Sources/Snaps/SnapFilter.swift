import AVFoundation
import CoreImage
import UIKit

/// ~15 ästhetische Snap-Filter (R9), reine Core-Image-Rezepte ohne Assets und ohne Netz. Jeder Fall
/// ist eine reine Funktion `CIImage -> CIImage`, `.original` ist die Identität. Deutsche Anzeigenamen
/// wie im Vorbild-Screenshot (Snapchat-Filterkarussell).
enum SnapFilter: String, CaseIterable, Identifiable, Sendable {
    case original, warm, kuehl, vivid, weichzeichner, film, vintage, mono, noir, chrome, matt, moody, pastell, sonnenuntergang, zeitstempel

    var id: String { rawValue }

    /// Nächster/vorheriger Filter in `allCases`, an den Rändern geklemmt (kein Umlauf) — geteilt
    /// zwischen dem Wisch im Editor (`SnapEditor`) und dem Wisch/Karussell in der Live-Kamera
    /// (`SnapKamera.swift`). Reine Funktion, per XCTest ohne Core Image testbar.
    static func benachbart(zu aktuell: SnapFilter, vorwaerts: Bool) -> SnapFilter {
        let alle = allCases
        guard let index = alle.firstIndex(of: aktuell) else { return aktuell }
        let neuerIndex = vorwaerts ? min(index + 1, alle.count - 1) : max(index - 1, 0)
        return alle[neuerIndex]
    }

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

    /// Reine Funktion: `bild` bleibt unverändert, nur das Ergebnis kommt zurück. Jeder Zweig croppt
    /// am Ende auf `bild.extent` — manche Bausteine (Rauschen, Vignette) liefern sonst eine andere
    /// Ausdehnung als der Input.
    /// `video`: `true` lässt bei `.film` das Korn weg (R9-Review) — `CIRandomGenerator` liefert pro
    /// Aufruf neues Rauschen; auf ein Einzelbild angewendet ist das "Filmkorn", pro Frame über
    /// `videoKomposition` angewendet wäre es Flackern. Fürs Foto bleibt das Korn (Standardwert `false`).
    func anwenden(auf bild: CIImage, video: Bool = false) -> CIImage {
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
            guard !video else { return verblasst.cropped(to: bild.extent) }
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

        let schrift = UIFont.italicSystemFont(ofSize: groesse.width * 0.08)
        let absatz = NSMutableParagraphStyle()
        absatz.alignment = .center
        let schatten = NSShadow()
        schatten.shadowColor = UIColor.black.withAlphaComponent(0.6)
        schatten.shadowBlurRadius = 4
        let attribute: [NSAttributedString.Key: Any] = [.font: schrift, .foregroundColor: UIColor.white, .paragraphStyle: absatz, .shadow: schatten]
        let groesseText = text.size(withAttributes: attribute)
        let punkt = CGPoint(x: (groesse.width - groesseText.width) / 2, y: (groesse.height - groesseText.height) / 2)

        guard let cgBild = Self.cgBild(groesse: groesse, zeichnen: { _ in text.draw(at: punkt, withAttributes: attribute) }) else { return nil }
        return CIImage(cgImage: cgBild)
    }

    /// Ersetzt den UIKit-Bild-Renderer (CI-Regel: im `Snaps`-Ordner nur in Dateien mit "Export" im
    /// Namen erlaubt) durch einen rohen, transparenten `CGContext` + `UIGraphicsPushContext` — UIKit-
    /// Zeichenaufrufe (`NSString.draw`) funktionieren darüber unverändert.
    private static func cgBild(groesse: CGSize, zeichnen: (CGContext) -> Void) -> CGImage? {
        let breite = Int(groesse.width.rounded(.up))
        let hoehe = Int(groesse.height.rounded(.up))
        guard breite > 0, hoehe > 0,
              let context = CGContext(data: nil, width: breite, height: hoehe, bitsPerComponent: 8, bytesPerRow: 0,
                                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Core Graphics: Ursprung unten links, Y hoch. UIKit-Zeichenaufrufe erwarten Y runter wie
        // jedes andere UIKit-Layout — ohne den Flip stünde der Text kopfüber.
        context.translateBy(x: 0, y: CGFloat(hoehe))
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        zeichnen(context)
        UIGraphicsPopContext()
        return context.makeImage()
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

// MARK: - Sendable-Hüllen (R9-Review: CIContext/CGImage sind laut Apple-Doku threadsicher zu lesen bzw.
// unveränderlich, aber nicht als `Sendable` deklariert — diese Session hat genau diese stillschweigende
// Annahme schon dreimal den Build kosten lassen, deshalb hier explizit statt implizit.)

/// Einmal gebaut, über die ganze App-Laufzeit wiederverwendet (teurer Aufbau, Akku-Regel) — für alle
/// Renderings (Vorschau, Thumbnails, Export, Video-Filterung).
final class SnapFilterKontext: @unchecked Sendable {
    static let shared = SnapFilterKontext()
    let context = CIContext()
    private init() {}
}

/// `CGImage` ist unveränderlich (Core-Graphics-Doku), aber nicht offiziell `Sendable` — diese Hülle
/// macht es dem Compiler explizit erlaubt, ein gerendertes Bild über eine `Task.detached`-Grenze zu
/// reichen, statt es stillschweigend vorauszusetzen.
struct SendableCGImage: @unchecked Sendable {
    let bild: CGImage
}

extension SnapFilter {
    /// Ganze Pipeline in einer Funktion — `CGImage` rein, `CGImage` raus, `CIImage`/`CIFilter` werden
    /// bewusst INNERHALB gebaut statt von außen hineingereicht (R9-Review). Sicher aus einem
    /// `Task.detached` heraus aufzurufen, weil nur `CGImage` (per `SendableCGImage`) und `SnapFilter`
    /// (beide `Sendable`) die Grenze queren müssen.
    static func gefiltertesCGBild(aus quelle: CGImage, filter: SnapFilter, zuschnitt: CGRect? = nil) -> CGImage? {
        let ciBasis = CIImage(cgImage: quelle)
        let gefiltert = filter.anwenden(auf: ciBasis)
        return SnapFilterKontext.shared.context.createCGImage(gefiltert, from: zuschnitt ?? gefiltert.extent)
    }
}

// MARK: - Video (Vorschau im Player & Export teilen sich diesen Aufbau)

extension SnapFilter {
    /// `AVVideoComposition(asset:applyingCIFiltersWithHandler:)` wendet `anwenden(auf:video: true)` pro
    /// Frame an — dieselbe Rezept-Funktion wie beim Foto, nur ohne Filmkorn (Flacker-Gefahr, siehe
    /// `anwenden(auf:video:)`). `nil` bei `.original`, ein Composition-Objekt weniger zu bauen und
    /// zuzuweisen ist der einfachste "kein Filter"-Fall.
    @MainActor
    func videoKomposition(fuer asset: AVAsset) async -> AVVideoComposition? {
        guard self != .original else { return nil }
        return try? await AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: { anfrage in
            anfrage.finish(with: self.anwenden(auf: anfrage.sourceImage, video: true), context: SnapFilterKontext.shared.context)
        })
    }
}
