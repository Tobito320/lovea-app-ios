import SwiftUI

struct MetalCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var store: DrawingStore

    func makeUIView(context: Context) -> MetalCanvasView {
        MetalCanvasView(store: store)
    }

    func updateUIView(_ view: MetalCanvasView, context: Context) {
        view.refresh()
    }
}
