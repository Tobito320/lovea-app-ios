import PhotosUI
import PencilKit
import SwiftUI
import UIKit

struct DrawingStudioView: View {
    @StateObject private var session: DrawingSession
    @StateObject private var canvasController = PencilCanvasController()
    @ObservedObject private var sharing: LoveaSharingService
    @State private var showsLayers = false
    @State private var showsInsertTools = false
    @State private var exportImage: UIImage?
    @State private var imageItem: PhotosPickerItem?
    @State private var templateItem: PhotosPickerItem?
    @State private var livePublishTask: Task<Void, Never>?
    @State private var shareMessage: String?

    init(artworkID: UUID, library: ArtworkLibrary, sharing: LoveaSharingService) {
        _session = StateObject(wrappedValue: DrawingSession(artworkID: artworkID, library: library))
        self.sharing = sharing
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .secondarySystemBackground)
                .ignoresSafeArea()

            if let active = session.activeLayer, active.kind == .paint {
                PencilCanvasRepresentable(
                    drawing: session.drawing(for: active.id),
                    canvasSize: session.canvasSize,
                    tool: session.tool,
                    brush: session.brush,
                    color: session.color,
                    brushWidth: session.brushWidth,
                    brushOpacity: session.brushOpacity,
                    drawsWithFinger: session.drawsWithFinger,
                    rulerActive: session.rulerActive,
                    isLocked: active.isLocked,
                    backgroundImage: imageBelowActiveLayer,
                    foregroundImage: imageAboveActiveLayer,
                    controller: canvasController,
                    onDrawingChanged: { session.updateDrawing($0, for: active.id) },
                    onCanvasTap: { session.handleCanvasTap($0) }
                )
            } else if let active = session.activeLayer, active.kind == .image {
                ImageLayerEditor(session: session, layerID: active.id)
            } else {
                ContentUnavailableView("Keine Ebene", systemImage: "square.3.layers.3d")
            }

            if let shareMessage {
                Text(shareMessage)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle(session.document.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { studioToolbar }
        .safeAreaInset(edge: .bottom) {
            studioControls
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showsLayers) {
            ArtworkLayersView(session: session)
        }
        .sheet(isPresented: $showsInsertTools) {
            InsertToolsView(session: session)
        }
        .sheet(isPresented: Binding(
            get: { exportImage != nil },
            set: { if !$0 { exportImage = nil } }
        )) {
            if let exportImage {
                ShareSheet(items: [exportImage])
            }
        }
        .onChange(of: imageItem) { _, item in
            importPhoto(item, asTemplate: false)
        }
        .onChange(of: templateItem) { _, item in
            importPhoto(item, asTemplate: true)
        }
        .onChange(of: session.document.updatedAt) { _, _ in
            scheduleLivePublish()
        }
        .onDisappear {
            livePublishTask?.cancel()
            session.saveNow()
            publishLiveImmediatelyIfNeeded()
        }
    }

    @ToolbarContentBuilder
    private var studioToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                canvasController.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .accessibilityLabel("Rückgängig")

            Button {
                canvasController.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
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
                PhotosPicker(selection: $templateItem, matching: .images) {
                    Label("Foto als Schablone", systemImage: "photo.badge.plus")
                }
                PhotosPicker(selection: $imageItem, matching: .images) {
                    Label("Bild als Ebene importieren", systemImage: "photo.on.rectangle")
                }
                Button {
                    showsInsertTools = true
                } label: {
                    Label("Formen, Text & Fülloptionen", systemImage: "square.on.circle")
                }

                Divider()

                Toggle("Mit Finger zeichnen", isOn: $session.drawsWithFinger)
                Toggle("Lineal", isOn: $session.rulerActive)

                Button("Ansicht zurücksetzen") {
                    canvasController.resetView()
                }

                Divider()

                Button("Als PNG/Bild teilen") {
                    exportImage = session.exportImage()
                }

                if sharing.state == .connected {
                    Button("Als Bild an Partner senden") {
                        sendSnapshot()
                    }
                    if session.document.liveReadOnlyShare {
                        Button("Live-Freigabe beenden", role: .destructive) {
                            setLiveShare(false)
                        }
                    } else {
                        Button("Live ansehen lassen") {
                            setLiveShare(true)
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Mehr")
        }
    }

    private var studioControls: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StudioTool.allCases) { tool in
                        Button {
                            session.tool = tool
                        } label: {
                            Image(systemName: tool.symbol)
                                .frame(width: 42, height: 42)
                                .background(session.tool == tool ? Color.accentColor.opacity(0.22) : Color.clear, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tool.title)
                        .disabled(session.activeLayer?.kind != .paint)
                    }

                    Divider().frame(height: 30)

                    Menu {
                        ForEach(BrushPreset.allCases) { brush in
                            Button {
                                session.brush = brush
                                session.tool = .brush
                            } label: {
                                if session.brush == brush {
                                    Label(brush.title, systemImage: "checkmark")
                                } else {
                                    Text(brush.title)
                                }
                            }
                        }
                    } label: {
                        Label(session.brush.title, systemImage: "paintbrush")
                            .lineLimit(1)
                    }
                    .disabled(session.activeLayer?.kind != .paint)

                    ColorPicker("Farbe", selection: colorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .disabled(session.activeLayer?.kind != .paint)
                }
            }

            if session.activeLayer?.kind == .paint {
                if session.tool == .fill {
                    HStack(spacing: 8) {
                        Text("Fülltoleranz")
                            .font(.caption)
                        Slider(value: $session.fillTolerance, in: 0...0.5)
                        Text("\(Int(session.fillTolerance * 100))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 38)
                    }
                } else if session.tool == .brush || session.tool == .eraser {
                    HStack(spacing: 8) {
                        Text("Größe")
                            .font(.caption)
                        Slider(value: $session.brushWidth, in: 1...120)
                        Text("\(Int(session.brushWidth))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 32)
                    }

                    HStack(spacing: 8) {
                        Text("Deckkraft")
                            .font(.caption)
                        Slider(value: $session.brushOpacity, in: 0.05...1)
                        Text(session.brushOpacity, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.monospacedDigit())
                            .frame(width: 42)
                    }
                } else {
                    HStack {
                        Text(session.tool == .eyedropper ? "Tippe auf eine Farbe in der Zeichnung." : "Auswahl mit dem Apple Pencil oder Finger umfahren.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }

                HStack(spacing: 6) {
                    ForEach(Array(session.recentColors.prefix(8).enumerated()), id: \.offset) { _, color in
                        Button {
                            session.setColor(color)
                        } label: {
                            Circle()
                                .fill(Color(uiColor: color.uiColor))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().stroke(.primary.opacity(0.15), lineWidth: 1))
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    if isLiveShared {
                        Label("Live · nur ansehen", systemImage: "eye.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("✓ automatisch gespeichert")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "move.3d")
                    Text("Bildebene: ziehen zum Verschieben, Regler zum Skalieren und Drehen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(uiColor: session.color.uiColor) },
            set: { newColor in
                session.setColor(RGBAColor(uiColor: UIColor(newColor)))
            }
        )
    }

    private var currentProject: ArtworkProject? {
        session.document.projectID.flatMap { id in
            session.library.projects.first(where: { $0.id == id })
        }
    }

    private var isLiveShared: Bool {
        session.document.liveReadOnlyShare || currentProject?.sharedReadOnly == true
    }

    private var imageBelowActiveLayer: UIImage? {
        guard let index = session.document.layers.firstIndex(where: { $0.id == session.activeLayerID }) else { return nil }
        var doc = session.document
        doc.layers = Array(doc.layers.prefix(index))
        return ArtworkRenderer.render(document: doc, library: session.library)
    }

    private var imageAboveActiveLayer: UIImage? {
        guard let index = session.document.layers.firstIndex(where: { $0.id == session.activeLayerID }),
              index + 1 < session.document.layers.count else { return nil }
        var doc = session.document
        doc.background = .transparent
        doc.layers = Array(doc.layers.suffix(from: index + 1))
        return ArtworkRenderer.render(document: doc, library: session.library)
    }

    private func importPhoto(_ item: PhotosPickerItem?, asTemplate: Bool) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run {
                session.addImageLayer(data: data, asTemplate: asTemplate)
                if asTemplate {
                    templateItem = nil
                } else {
                    imageItem = nil
                }
            }
        }
    }

    private func sendSnapshot() {
        Task {
            do {
                try await sharing.sendSnapshot(document: session.document, image: session.exportImage())
                showShareMessage("Bild gesendet")
            } catch {
                showShareMessage("Fehler beim Senden")
            }
        }
    }

    private func setLiveShare(_ enabled: Bool) {
        Task {
            do {
                if enabled {
                    try await sharing.publishLive(
                        document: session.document,
                        project: currentProject,
                        image: session.exportImage()
                    )
                } else {
                    try await sharing.stopLive(artworkID: session.document.id)
                }
                session.document.liveReadOnlyShare = enabled
                session.saveNow()
                showShareMessage(enabled ? "Live-Ansehen aktiv" : "Live-Ansehen beendet")
            } catch {
                showShareMessage("Freigabe fehlgeschlagen")
            }
        }
    }

    private func scheduleLivePublish() {
        guard isLiveShared, sharing.state == .connected else { return }
        livePublishTask?.cancel()
        livePublishTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            try? await sharing.publishLive(
                document: session.document,
                project: currentProject,
                image: session.exportImage()
            )
        }
    }

    private func publishLiveImmediatelyIfNeeded() {
        guard isLiveShared, sharing.state == .connected else { return }
        Task {
            try? await sharing.publishLive(
                document: session.document,
                project: currentProject,
                image: session.exportImage()
            )
        }
    }

    private func showShareMessage(_ text: String) {
        withAnimation { shareMessage = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { shareMessage = nil }
        }
    }
}

private struct ImageLayerEditor: View {
    @ObservedObject var session: DrawingSession
    let layerID: UUID
    @State private var dragOrigin: LayerTransform?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let canvas = session.canvasSize
            let fit = min(size.width / max(canvas.width, 1), size.height / max(canvas.height, 1))
            let layer = session.document.layers.first(where: { $0.id == layerID })
            let transform = layer?.transform ?? LayerTransform()
            let activeImage = layer.flatMap {
                ArtworkRenderer.layerImage($0, document: session.document, library: session.library)
            }

            ZStack {
                if let base = renderWithoutActive {
                    Image(uiImage: base)
                        .resizable()
                        .scaledToFit()
                }

                if let activeImage {
                    Image(uiImage: activeImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: canvas.width * fit, height: canvas.height * fit)
                        .scaleEffect(
                            x: CGFloat(transform.scale) * (transform.flipX ? -1 : 1),
                            y: CGFloat(transform.scale) * (transform.flipY ? -1 : 1)
                        )
                        .rotationEffect(.radians(transform.rotation))
                        .offset(
                            x: CGFloat(transform.offsetX) * fit,
                            y: CGFloat(transform.offsetY) * fit
                        )
                        .opacity(layer?.opacity ?? 1)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    guard !(layer?.isLocked ?? true) else { return }
                                    if dragOrigin == nil { dragOrigin = transform }
                                    guard var next = dragOrigin else { return }
                                    next.offsetX += Double(value.translation.width / max(fit, 0.001))
                                    next.offsetY += Double(value.translation.height / max(fit, 0.001))
                                    session.updateTransform(next, for: layerID)
                                }
                                .onEnded { _ in dragOrigin = nil }
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if let layer {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Skalierung")
                            Slider(
                                value: Binding(
                                    get: { session.document.layers.first(where: { $0.id == layerID })?.transform.scale ?? 1 },
                                    set: { value in
                                        var next = session.document.layers.first(where: { $0.id == layerID })?.transform ?? LayerTransform()
                                        next.scale = value
                                        session.updateTransform(next, for: layerID)
                                    }
                                ),
                                in: 0.1...5
                            )
                        }
                        HStack {
                            Text("Drehung")
                            Slider(
                                value: Binding(
                                    get: { session.document.layers.first(where: { $0.id == layerID })?.transform.rotation ?? 0 },
                                    set: { value in
                                        var next = session.document.layers.first(where: { $0.id == layerID })?.transform ?? LayerTransform()
                                        next.rotation = value
                                        session.updateTransform(next, for: layerID)
                                    }
                                ),
                                in: -Double.pi...Double.pi
                            )
                            Button("↔") { session.flipActive(horizontal: true) }
                            Button("↕") { session.flipActive(horizontal: false) }
                        }
                        .disabled(layer.isLocked)
                    }
                    .font(.caption)
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding()
                }
            }
        }
    }

    private var renderWithoutActive: UIImage? {
        var doc = session.document
        doc.layers.removeAll { $0.id == layerID }
        return ArtworkRenderer.render(document: doc, library: session.library)
    }
}
