import SwiftUI
import UIKit

struct DrawingView: View {
    @StateObject private var store = DrawingStore(persistence: DrawingPersistence())
    @State private var showsLayers = false
    @State private var showsClearConfirmation = false
    @State private var exportImage: UIImage?

    private let colors: [RGBAColor] = [.ink, .blue, .red, .orange]

    var body: some View {
        NavigationStack {
            ZStack {
                MetalCanvasRepresentable(store: store)
                    .ignoresSafeArea(edges: .bottom)

                VStack {
                    Spacer()
                    toolPanel
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
            .navigationTitle("Zeichnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { drawingToolbar }
            .sheet(isPresented: $showsLayers) {
                LayersView(store: store)
            }
            .sheet(isPresented: Binding(
                get: { exportImage != nil },
                set: { if !$0 { exportImage = nil } }
            )) {
                if let exportImage {
                    ShareSheet(items: [exportImage])
                }
            }
            .confirmationDialog("Zeichnung leeren?", isPresented: $showsClearConfirmation) {
                Button("Alles löschen", role: .destructive) { store.clear() }
                Button("Abbrechen", role: .cancel) {}
            }
            .task {
                await store.loadSavedDocument()
            }
        }
    }

    @ToolbarContentBuilder
    private var drawingToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                store.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!store.canUndo)
            .accessibilityLabel("Rückgängig")

            Button {
                store.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!store.canRedo)
            .accessibilityLabel("Wiederholen")
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showsLayers = true
            } label: {
                Image(systemName: "square.3.layers.3d")
            }
            .accessibilityLabel("Ebenen")

            Menu {
                Toggle("Mit Finger zeichnen", isOn: $store.drawsWithFinger)
                Button("Als Bild teilen") {
                    exportImage = DrawingExporter.image(from: store.document)
                }
                Button("Zeichnung leeren", role: .destructive) {
                    showsClearConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Mehr")
        }
    }

    private var toolPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                toolButton(.brush, icon: "paintbrush.pointed.fill", label: "Pinsel")
                toolButton(.eraser, icon: "eraser.fill", label: "Radierer")

                Divider()
                    .frame(height: 28)

                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    Button {
                        store.color = color
                        store.tool = .brush
                    } label: {
                        Circle()
                            .fill(swiftUIColor(color))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if store.color == color && store.tool == .brush {
                                    Circle().stroke(.primary, lineWidth: 2).padding(-4)
                                }
                            }
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Farbe wählen")
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                Slider(value: $store.brushWidth, in: 2...48)
                    .accessibilityLabel("Pinselstärke")
                Image(systemName: "circle.fill")
                    .font(.system(size: 18))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func toolButton(_ tool: DrawingTool, icon: String, label: String) -> some View {
        Button {
            store.tool = tool
        } label: {
            Image(systemName: icon)
                .frame(width: 44, height: 44)
                .background(store.tool == tool ? Color.blue : Color.clear, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func swiftUIColor(_ color: RGBAColor) -> Color {
        Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}
