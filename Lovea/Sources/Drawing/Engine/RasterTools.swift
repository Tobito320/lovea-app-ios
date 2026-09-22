import CoreGraphics
import UIKit

enum RasterTools {
    static func sampleColor(in image: UIImage, at point: CGPoint) -> RGBAColor? {
        guard point.x >= 0, point.y >= 0,
              point.x < image.size.width, point.y < image.size.height else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.translateBy(x: -point.x, y: point.y - image.size.height + 1)
        context.draw(image.cgImage!, in: CGRect(origin: .zero, size: image.size))
        return RGBAColor(
            red: Double(pixel[0]) / 255,
            green: Double(pixel[1]) / 255,
            blue: Double(pixel[2]) / 255,
            alpha: Double(pixel[3]) / 255
        )
    }

    static func floodFillLayer(
        source: UIImage,
        start: CGPoint,
        color: RGBAColor,
        tolerance: Double
    ) -> UIImage? {
        guard let cgImage = source.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let sx = min(max(Int(start.x / max(source.size.width, 1) * CGFloat(width)), 0), width - 1)
        let sy = min(max(Int(start.y / max(source.size.height, 1) * CGFloat(height)), 0), height - 1)

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var sourceBytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let sourceContext = CGContext(
            data: &sourceBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        sourceContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let startIndex = (sy * width + sx) * 4
        let target = (
            sourceBytes[startIndex],
            sourceBytes[startIndex + 1],
            sourceBytes[startIndex + 2],
            sourceBytes[startIndex + 3]
        )
        let threshold = max(0, min(tolerance, 1)) * 255 * 4

        var output = [UInt8](repeating: 0, count: sourceBytes.count)
        var visited = [UInt8](repeating: 0, count: width * height)
        var stack: [Int] = [sy * width + sx]
        stack.reserveCapacity(min(width * height, 262_144))

        let r = UInt8(clamping: Int(color.red * 255))
        let g = UInt8(clamping: Int(color.green * 255))
        let b = UInt8(clamping: Int(color.blue * 255))
        let a = UInt8(clamping: Int(max(color.alpha, 0.01) * 255))

        func matches(_ pixelIndex: Int) -> Bool {
            let i = pixelIndex * 4
            let distance = abs(Int(sourceBytes[i]) - Int(target.0))
                + abs(Int(sourceBytes[i + 1]) - Int(target.1))
                + abs(Int(sourceBytes[i + 2]) - Int(target.2))
                + abs(Int(sourceBytes[i + 3]) - Int(target.3))
            return Double(distance) <= threshold
        }

        while let pixelIndex = stack.popLast() {
            if visited[pixelIndex] != 0 { continue }
            visited[pixelIndex] = 1
            guard matches(pixelIndex) else { continue }

            let i = pixelIndex * 4
            output[i] = r
            output[i + 1] = g
            output[i + 2] = b
            output[i + 3] = a

            let x = pixelIndex % width
            let y = pixelIndex / width
            if x > 0 { stack.append(pixelIndex - 1) }
            if x + 1 < width { stack.append(pixelIndex + 1) }
            if y > 0 { stack.append(pixelIndex - width) }
            if y + 1 < height { stack.append(pixelIndex + width) }
        }

        guard let outputContext = CGContext(
            data: &output,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let result = outputContext.makeImage() else { return nil }
        return UIImage(cgImage: result, scale: source.scale, orientation: .up)
    }

    static func shapeLayer(
        canvasSize: CGSize,
        kind: ShapeKind,
        color: RGBAColor,
        lineWidth: CGFloat,
        filled: Bool
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { output in
            let context = output.cgContext
            let rect = CGRect(
                x: canvasSize.width * 0.2,
                y: canvasSize.height * 0.2,
                width: canvasSize.width * 0.6,
                height: canvasSize.height * 0.6
            )
            context.setStrokeColor(color.uiColor.cgColor)
            context.setFillColor(color.uiColor.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            switch kind {
            case .line:
                context.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                context.strokePath()
            case .rectangle:
                filled ? context.fill(rect) : context.stroke(rect)
            case .ellipse:
                filled ? context.fillEllipse(in: rect) : context.strokeEllipse(in: rect)
            }
        }
    }

    static func textLayer(
        canvasSize: CGSize,
        text: String,
        color: RGBAColor,
        fontSize: CGFloat,
        font: UIFont
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font.withSize(fontSize),
                .foregroundColor: color.uiColor,
                .paragraphStyle: paragraph,
            ]
            let box = CGRect(
                x: canvasSize.width * 0.1,
                y: canvasSize.height * 0.4,
                width: canvasSize.width * 0.8,
                height: canvasSize.height * 0.2
            )
            NSString(string: text).draw(in: box, withAttributes: attributes)
        }
    }
}

enum ShapeKind: String, CaseIterable, Identifiable {
    case line
    case rectangle
    case ellipse

    var id: String { rawValue }
    var title: String {
        switch self {
        case .line: "Linie"
        case .rectangle: "Rechteck"
        case .ellipse: "Ellipse"
        }
    }
}
