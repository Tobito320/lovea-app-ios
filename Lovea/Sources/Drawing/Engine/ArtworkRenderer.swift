import PencilKit
import UIKit

enum ArtworkRenderer {
    @MainActor
    static func render(
        document: ArtworkDocument,
        library: ArtworkLibrary,
        excluding excludedID: UUID? = nil
    ) -> UIImage {
        let size = CGSize(width: CGFloat(document.canvasWidth), height: CGFloat(document.canvasHeight))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { output in
            let cg = output.cgContext
            drawBackground(document.background, size: size, in: cg)

            var previousLayerImage: UIImage?
            for layer in document.layers where layer.isVisible && layer.id != excludedID {
                guard var image = layerImage(layer, document: document, library: library) else { continue }
                if layer.clipping, let previousLayerImage {
                    image = clipped(image, toAlphaOf: previousLayerImage, size: size)
                }
                cg.saveGState()
                cg.setAlpha(CGFloat(min(max(layer.opacity, 0), 1)))
                cg.setBlendMode(cgBlendMode(layer.blendMode))
                draw(image, transform: layer.transform, size: size, in: cg)
                cg.restoreGState()
                previousLayerImage = image
            }
        }
    }

    @MainActor
    static func thumbnail(
        document: ArtworkDocument,
        library: ArtworkLibrary,
        maxDimension: CGFloat = 720
    ) -> UIImage {
        let full = render(document: document, library: library)
        let maxSide = max(full.size.width, full.size.height)
        guard maxSide > maxDimension else { return full }
        let scale = maxDimension / maxSide
        let size = CGSize(width: full.size.width * scale, height: full.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            full.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    @MainActor
    static func layerImage(
        _ layer: ArtworkLayer,
        document: ArtworkDocument,
        library: ArtworkLibrary
    ) -> UIImage? {
        let size = CGSize(width: CGFloat(document.canvasWidth), height: CGFloat(document.canvasHeight))
        let base: UIImage?
        switch layer.kind {
        case .paint:
            let legacy = legacyPaintImage(layer, document: document, library: library)
            let metalFile = library.metalStrokesFile(for: layer)
            if library.layerAsset(fileName: metalFile, artworkID: document.id) != nil {
                base = renderMetalStrokes(
                    library.metalStrokes(for: layer, artworkID: document.id),
                    size: size,
                    over: legacy
                )
            } else {
                base = legacy
            }
        case .image:
            guard let data = library.layerData(layer, artworkID: document.id) else { return nil }
            base = UIImage(data: data)
        }

        guard var image = base else { return nil }
        if layer.alphaLock,
           let maskFile = layer.alphaMaskFile,
           let maskData = library.layerAsset(fileName: maskFile, artworkID: document.id),
           let mask = UIImage(data: maskData) {
            image = clipped(image, toAlphaOf: mask, size: size)
        }
        return image
    }

    @MainActor
    static func legacyPaintImage(
        _ layer: ArtworkLayer,
        document: ArtworkDocument,
        library: ArtworkLibrary
    ) -> UIImage? {
        guard layer.kind == .paint,
              let data = library.layerData(layer, artworkID: document.id),
              let drawing = try? PKDrawing(data: data) else { return nil }
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(document.canvasWidth),
            height: CGFloat(document.canvasHeight)
        )
        return drawing.image(from: bounds, scale: 1)
    }

    private static func renderMetalStrokes(
        _ strokes: [MetalPaintStroke],
        size: CGSize,
        over legacy: UIImage?
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { output in
            let context = output.cgContext
            legacy?.draw(in: CGRect(origin: .zero, size: size))
            for stroke in strokes {
                let points = MetalStrokeRenderingProfile.smoothedPoints(stroke)
                guard let first = points.first else { continue }
                context.saveGState()
                context.setBlendMode(stroke.tool == .eraser ? .destinationOut : .normal)
                let hardness = brushHardness(for: stroke)
                guard let gradient = stampGradient(color: stroke.color, alpha: 1, hardness: hardness) else {
                    context.restoreGState()
                    continue
                }

                func stamp(_ center: CGPoint, radius: CGFloat, pressure: Double) {
                    context.setAlpha(CGFloat(MetalStrokeRenderingProfile.alpha(stroke, pressure: pressure)))
                    context.drawRadialGradient(
                        gradient,
                        startCenter: center,
                        startRadius: 0,
                        endCenter: center,
                        endRadius: max(radius, 0.5),
                        options: []
                    )
                }

                let firstPoint = CGPoint(x: first.x, y: first.y)
                let firstRadius = CGFloat(MetalStrokeRenderingProfile.radius(stroke, pressure: first.pressure))
                stamp(firstPoint, radius: firstRadius, pressure: first.pressure)

                for index in 1..<points.count {
                    let previous = points[index - 1]
                    let current = points[index]
                    let from = CGPoint(x: previous.x, y: previous.y)
                    let to = CGPoint(x: current.x, y: current.y)
                    let previousRadius = CGFloat(MetalStrokeRenderingProfile.radius(stroke, pressure: previous.pressure))
                    let nextRadius = CGFloat(MetalStrokeRenderingProfile.radius(stroke, pressure: current.pressure))
                    let distance = hypot(to.x - from.x, to.y - from.y)
                    let spacing = max(min(nextRadius * 0.4, 3), 0.5)
                    let count = max(1, Int(ceil(distance / spacing)))
                    for step in 1...count {
                        let fraction = CGFloat(step) / CGFloat(count)
                        let center = CGPoint(
                            x: from.x + (to.x - from.x) * fraction,
                            y: from.y + (to.y - from.y) * fraction
                        )
                        let pressure = previous.pressure + (current.pressure - previous.pressure) * Double(fraction)
                        stamp(
                            center,
                            radius: previousRadius + (nextRadius - previousRadius) * fraction,
                            pressure: pressure
                        )
                    }
                }
                context.restoreGState()
            }
        }
    }

    private static func brushHardness(for stroke: MetalPaintStroke) -> CGFloat {
        if stroke.tool == .eraser { return 0.94 }
        switch stroke.brushPreset {
        case "airbrush", "watercolor": return 0.08
        case "pencil", "chalk": return 0.55
        case "highlighter": return 0.82
        default: return 0.94
        }
    }

    private static func stampGradient(
        color: RGBAColor,
        alpha: Double,
        hardness: CGFloat
    ) -> CGGradient? {
        let steps = (0...16).map { CGFloat($0) / 16 }
        let locations = [CGFloat(0)] + steps.map { hardness + (1 - hardness) * $0 }
        let colors: [CGColor] = locations.enumerated().map { index, _ in
            let t = index == 0 ? CGFloat(0) : steps[index - 1]
            let coverage = index == 0 ? CGFloat(1) : 1 - t * t * (3 - 2 * t)
            return UIColor(
                red: CGFloat(color.red),
                green: CGFloat(color.green),
                blue: CGFloat(color.blue),
                alpha: CGFloat(alpha) * coverage
            ).cgColor
        }
        return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)
    }

    private static func drawBackground(_ background: CanvasBackground, size: CGSize, in context: CGContext) {
        let color: UIColor?
        switch background {
        case .white:
            color = .white
        case .dark:
            color = UIColor(white: 0.07, alpha: 1)
        case .transparent:
            color = nil
        case .color(let value):
            color = UIColor(
                red: CGFloat(value.red),
                green: CGFloat(value.green),
                blue: CGFloat(value.blue),
                alpha: CGFloat(value.alpha)
            )
        }
        if let color {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static func draw(_ image: UIImage, transform: LayerTransform, size: CGSize, in context: CGContext) {
        let center = CGPoint(
            x: size.width / 2 + CGFloat(transform.offsetX),
            y: size.height / 2 + CGFloat(transform.offsetY)
        )
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(transform.rotation))
        context.scaleBy(
            x: CGFloat(transform.scale * (transform.flipX ? -1 : 1)),
            y: CGFloat(transform.scale * (transform.flipY ? -1 : 1))
        )

        let fitted = aspectFit(image.size, inside: size)
        image.draw(in: CGRect(
            x: -fitted.width / 2,
            y: -fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        ))
    }

    private static func aspectFit(_ image: CGSize, inside canvas: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return .zero }
        let ratio = min(canvas.width / image.width, canvas.height / image.height)
        return CGSize(width: image.width * ratio, height: image.height * ratio)
    }

    private static func clipped(_ image: UIImage, toAlphaOf maskImage: UIImage, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { output in
            image.draw(in: CGRect(origin: .zero, size: size))
            output.cgContext.setBlendMode(.destinationIn)
            maskImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func cgBlendMode(_ mode: LayerBlendMode) -> CGBlendMode {
        switch mode {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .darken: .darken
        case .lighten: .lighten
        case .add: .plusLighter
        case .softLight: .softLight
        }
    }
}
