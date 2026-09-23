import PhotosUI
import SwiftUI

extension View {
    /// Floating control surface: Liquid Glass on the control layer.
    @ViewBuilder
    func floatingBar(glass: Bool) -> some View {
        if glass {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            background(.regularMaterial, in: Capsule())
        }
    }
}

/// Groups floating bars so their glass blends instead of stacking.
struct FloatingBarGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GlassEffectContainer(spacing: 12) { content }
    }
}

struct ToolButton: View {
    let title: String
    let symbol: String
    var activeSymbol: String?
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? (activeSymbol ?? symbol) : symbol)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(isActive ? Color.accentColor.opacity(0.18) : .clear, in: Circle())
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Bottom floating tool bar. iPad shows every tool, iPhone a compact set plus "Mehr".
struct ToolRail: View {
    @ObservedObject var session: DrawingSession
    let compact: Bool
    let glass: Bool
    @Binding var templateItem: PhotosPickerItem?
    @Binding var imageItem: PhotosPickerItem?
    let onText: () -> Void
    let onColor: () -> Void
    let onLayers: () -> Void
    @State private var showsBrushes = false

    static let fullTools: [StudioTool] = [.brush, .eraser, .lasso, .fill, .eyedropper, .shape, .transform, .text]
    static let compactTools: [StudioTool] = [.brush, .eraser, .lasso, .fill]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(compact ? Self.compactTools : Self.fullTools) { tool in
                ToolButton(title: tool.title, symbol: tool.symbol, activeSymbol: tool.activeSymbol, isActive: session.tool == tool) {
                    select(tool)
                }
                .popover(isPresented: tool == .brush ? $showsBrushes : .constant(false)) {
                    BrushPicker(session: session)
                }
            }
            if compact {
                ColorSwatchButton(color: session.color, action: onColor)
                    .frame(width: 44, height: 44)
                ToolButton(title: "Ebenen", symbol: "square.3.layers.3d", action: onLayers)
                moreMenu
            } else {
                Divider().frame(height: 28).padding(.horizontal, 4)
                ForEach(session.recentBrushes) { preset in
                    Button {
                        session.brush = preset
                        session.tool = .brush
                    } label: {
                        Text(preset.title)
                            .font(.caption.weight(session.brush == preset && session.tool == .brush ? .semibold : .regular))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Zuletzt benutzt: \(preset.title)")
                }
                photoMenu
                ColorSwatchButton(color: session.color, action: onColor)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .floatingBar(glass: glass)
    }

    private func select(_ tool: StudioTool) {
        switch tool {
        case .text:
            onText()
        case .transform:
            session.tool = .transform
            session.beginTransform()
        case .brush where session.tool == .brush:
            showsBrushes = true
        default:
            if session.isTransforming { session.commitTransform() }
            session.tool = tool
        }
    }

    private var photoMenu: some View {
        Menu {
            PhotosPicker(selection: $templateItem, matching: .images) {
                Label("Als Schablone", systemImage: "photo.badge.plus")
            }
            PhotosPicker(selection: $imageItem, matching: .images) {
                Label("Als Ebene", systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "photo")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Foto")
    }

    private var moreMenu: some View {
        Menu {
            ForEach([StudioTool.eyedropper, .shape, .transform, .text]) { tool in
                Button {
                    select(tool)
                } label: {
                    Label(tool.title, systemImage: tool.symbol)
                }
            }
            Divider()
            PhotosPicker(selection: $templateItem, matching: .images) {
                Label("Als Schablone", systemImage: "photo.badge.plus")
            }
            PhotosPicker(selection: $imageItem, matching: .images) {
                Label("Als Ebene", systemImage: "photo.on.rectangle")
            }
            Button {
                showsBrushes = true
            } label: {
                Label("Pinsel wählen", systemImage: "paintbrush")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Mehr Werkzeuge")
    }
}

/// Brush list with a stroke preview per preset.
struct BrushPicker: View {
    @ObservedObject var session: DrawingSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(BrushPreset.allCases) { preset in
                    Button {
                        session.brush = preset
                        session.tool = .brush
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(preset.title)
                                .frame(width: 96, alignment: .leading)
                            ArtworkBrushPreview(preset: preset, color: session.color)
                                .frame(height: 36)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 48)
                        .background(session.brush == preset ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.title)
                    .accessibilityAddTraits(session.brush == preset ? .isSelected : [])
                }
                Divider().padding(.vertical, 6)
                Toggle("Druck ändert Größe", isOn: $session.pressureControlsSize)
                Toggle("Druck ändert Deckkraft", isOn: $session.pressureControlsOpacity)
                LabeledContent("Glättung") {
                    Stepper("\(Int(session.stabilizer))", value: $session.stabilizer, in: 0...9, step: 1)
                }
            }
            .padding(12)
        }
        .frame(minWidth: 320, idealHeight: 560)
    }
}

/// Size and opacity. iPad: two vertical sliders on the leading edge. iPhone: one compact row.
struct SizeOpacityRail: View {
    @ObservedObject var session: DrawingSession
    let compact: Bool
    let glass: Bool

    var body: some View {
        if compact {
            HStack(spacing: 12) {
                Image(systemName: "circle.fill").font(.caption2).accessibilityHidden(true)
                Slider(value: sizeFraction, in: 0...1)
                    .accessibilityLabel("Größe")
                    .accessibilityValue("\(Int(session.brushSize)) Pixel")
                Text("\(Int(session.brushSize))").font(.caption.monospacedDigit()).frame(minWidth: 28)
                Image(systemName: "circle.lefthalf.filled").font(.caption2).accessibilityHidden(true)
                Slider(value: $session.brushOpacity, in: 0.01...1)
                    .accessibilityLabel("Deckkraft")
                    .accessibilityValue("\(Int(session.brushOpacity * 100)) Prozent")
                Text("\(Int(session.brushOpacity * 100)) %").font(.caption.monospacedDigit()).frame(minWidth: 40)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .floatingBar(glass: glass)
        } else {
            VStack(spacing: 16) {
                VerticalSlider(value: sizeFraction, label: "Größe", text: "\(Int(session.brushSize))")
                VerticalSlider(value: $session.brushOpacity, label: "Deckkraft", text: "\(Int(session.brushOpacity * 100)) %")
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .floatingBar(glass: glass)
        }
    }

    /// Size 1...300 on a square curve, so small sizes get most of the travel.
    private var sizeFraction: Binding<Double> {
        Binding(
            get: { sqrt((session.brushSize - 1) / 299) },
            set: { session.brushSize = (1 + 299 * $0 * $0).rounded() }
        )
    }
}

struct VerticalSlider: View {
    @Binding var value: Double
    let label: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let height = proxy.size.height
                ZStack(alignment: .bottom) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(.tint).frame(height: max(8, height * value))
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    value = min(max(1 - drag.location.y / height, 0), 1)
                })
            }
            .frame(width: 32, height: 150)
            Text(text)
                .font(.caption2.monospacedDigit())
                .frame(minWidth: 44)
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(text)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 0.05, 1)
            case .decrement: value = max(value - 0.05, 0)
            @unknown default: break
            }
        }
    }
}
