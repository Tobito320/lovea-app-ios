import SwiftUI

struct ArtworkMetalCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var session: DrawingSession
    let backgroundImage: UIImage?
    let legacyLayerImage: UIImage?
    let foregroundImage: UIImage?
    let alphaMaskImage: UIImage?
    let clippingMaskImage: UIImage?
    let controller: ArtworkMetalCanvasController

    func makeUIView(context: Context) -> ArtworkMetalCanvasView {
        let view = ArtworkMetalCanvasView()
        controller.canvasView = view
        controller.session = session
        view.configure(
            session: session,
            lower: backgroundImage,
            legacy: legacyLayerImage,
            upper: foregroundImage,
            alphaMask: alphaMaskImage,
            clippingMask: clippingMaskImage
        )
        return view
    }

    func updateUIView(_ view: ArtworkMetalCanvasView, context: Context) {
        controller.canvasView = view
        controller.session = session
        view.configure(
            session: session,
            lower: backgroundImage,
            legacy: legacyLayerImage,
            upper: foregroundImage,
            alphaMask: alphaMaskImage,
            clippingMask: clippingMaskImage
        )
    }
}
