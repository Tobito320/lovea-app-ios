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
        guard let data = library.layerData(layer, artworkID: document.id) else { return nil }
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(document.canvasWidth),
            height: CGFloat(document.canvasHeight)
        )
        switch layer.kind {
        case .paint:
            guard let drawing = try? PKDrawing(data: data) else { return nil }
            return drawing.image(from: bounds, scale: 1)
        case .image:
            return UIImage(data: data)
        }
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
