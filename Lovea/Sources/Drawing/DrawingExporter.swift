import SwiftUI
import UIKit

enum DrawingExporter {
    @MainActor
    static func image(from document: DrawingDocument) -> UIImage {
        let size = CGSize(width: CGFloat(document.canvasWidth), height: CGFloat(document.canvasHeight))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemBackground.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            for layer in document.layers where layer.isVisible {
                context.cgContext.saveGState()
                context.cgContext.setAlpha(layer.opacity)
                for stroke in layer.strokes where stroke.points.count > 1 {
                    let path = UIBezierPath()
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    path.lineWidth = CGFloat(stroke.width)
                    path.move(to: CGPoint(x: CGFloat(stroke.points[0].x), y: CGFloat(stroke.points[0].y)))
                    for point in stroke.points.dropFirst() {
                        path.addLine(to: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
                    }
                    if stroke.tool == .eraser {
                        path.stroke(with: .clear, alpha: stroke.opacity)
                    } else {
                        UIColor(
                            red: CGFloat(stroke.color.red),
                            green: CGFloat(stroke.color.green),
                            blue: CGFloat(stroke.color.blue),
                            alpha: CGFloat(stroke.opacity)
                        ).setStroke()
                        path.stroke()
                    }
                }
                context.cgContext.restoreGState()
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ viewController: UIActivityViewController, context: Context) {}
}
