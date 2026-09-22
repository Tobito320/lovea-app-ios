import SwiftUI

/// Layer list like ibisPaint: preview, name, eye, opacity, blend mode, clipping indent, lock.
/// iPad: side panel. iPhone: sheet with medium and large detents.
struct ArtworkLayersView: View {
    @ObservedObject var session: DrawingSession
    @State private var renameLayerID: UUID?
    @State private var renameText = ""
    @State private var deleteLayerID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ebenen").font(.headline)
                Spacer()
                Button {
                    session.addPaintLayer()
                } label: {
                    Image(systemName: "plus").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Neue Ebene")
            }
            .padding(.horizontal, 16)

            List {
                ForEach(Array(session.document.layers.reversed())) { layer in
                    LayerRow(layer: layer, session: session)
                        .listRowBackground(layer.id == session.activeLayerID ? Color.accentColor.opacity(0.14) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { session.selectLayer(layer.id) }
                        .contextMenu { menu(for: layer) }
                        .swipeActions {
                            Button(role: .destructive) { requestDelete(layer.id) } label: { Label("Löschen", systemImage: "trash") }
                        }
                }
                .onMove { source, destination in session.moveLayer(from: source, to: destination) }
            }
            .listStyle(.plain)

            if let layer = session.activeLayer {
                LayerFooter(layer: layer, session: session)
            }
        }
        .alert("Ebene umbenennen", isPresented: Binding(get: { renameLayerID != nil }, set: { if !$0 { renameLayerID = nil } })) {
            TextField("Name", text: $renameText)
            Button("Abbrechen", role: .cancel) {}
            Button("Umbenennen") {
                if let renameLayerID { session.renameLayer(renameLayerID, to: renameText) }
            }
        }
        .confirmationDialog(
            "Ebene löschen?",
            isPresented: Binding(get: { deleteLayerID != nil }, set: { if !$0 { deleteLayerID = nil } }),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let deleteLayerID { session.deleteLayer(deleteLayerID) }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Ebene hat Inhalt. Du kannst das mit Rückgängig zurückholen.")
        }
    }

    @ViewBuilder
    private func menu(for layer: ArtworkLayer) -> some View {
        Button { renameText = layer.name; renameLayerID = layer.id } label: { Label("Umbenennen", systemImage: "pencil") }
        Button { session.duplicateLayer(layer.id) } label: { Label("Duplizieren", systemImage: "plus.square.on.square") }
        Button { session.mergeDown(layer.id) } label: { Label("Nach unten zusammenführen", systemImage: "arrow.down.to.line") }
            .disabled(session.document.layers.first?.id == layer.id)
        if layer.kind == .image {
            Button { session.rasterize(layer.id) } label: { Label("Rastern", systemImage: "square.grid.3x3") }
        } else {
            Button { session.clearLayer(layer.id) } label: { Label("Leeren", systemImage: "square.dashed") }
        }
        Button { session.flipLayer(layer.id, horizontal: true) } label: { Label("Horizontal spiegeln", systemImage: "arrow.left.and.right") }
        Button { session.flipLayer(layer.id, horizontal: false) } label: { Label("Vertikal spiegeln", systemImage: "arrow.up.and.down") }
        Button { session.toggleLock(layer.id) } label: {
            Label(layer.isLocked ? "Entsperren" : "Sperren", systemImage: layer.isLocked ? "lock.open" : "lock")
        }
        Button(role: .destructive) { requestDelete(layer.id) } label: { Label("Löschen", systemImage: "trash") }
            .disabled(session.document.layers.count <= 1)
    }

    private func requestDelete(_ id: UUID) {
        guard session.document.layers.count > 1 else { return }
        Task {
            if await session.layerHasContent(id) {
                deleteLayerID = id
            } else {
                session.deleteLayer(id)
            }
        }
    }
}

private struct LayerRow: View {
    let layer: ArtworkLayer
    @ObservedObject var session: DrawingSession

    var body: some View {
        HStack(spacing: 10) {
            if layer.clipping {
                Image(systemName: "arrow.turn.left.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clipping")
            }
            ZStack {
                Checkerboard()
                if let image = session.layerThumbnails[layer.id] {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

            VStack(alignment: .leading, spacing: 2) {
                Text(layer.name)
                    .font(.subheadline.weight(layer.id == session.activeLayerID ? .semibold : .regular))
                    .lineLimit(1)
                Text("\(Int((layer.opacity * 100).rounded())) %  \(layer.blendMode.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if layer.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Gesperrt")
            }
            Button {
                session.toggleVisibility(layer.id)
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layer.isVisible ? "Ausblenden" : "Einblenden")
        }
        .padding(.leading, layer.clipping ? 8 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(layer.id == session.activeLayerID ? .isSelected : [])
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 6
            for row in 0..<Int(size.height / cell) + 1 {
                for column in 0..<Int(size.width / cell) + 1 where (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)), with: .color(Color(.systemGray5)))
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

/// Footer like ibisPaint: clipping, alpha lock, blend mode, opacity with − and +.
private struct LayerFooter: View {
    let layer: ArtworkLayer
    @ObservedObject var session: DrawingSession

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Toggle(isOn: Binding(get: { layer.clipping }, set: { _ in session.toggleClipping(layer.id) })) {
                    Label("Clipping", systemImage: "arrow.turn.left.down")
                }
                Toggle(isOn: Binding(get: { layer.alphaLock }, set: { _ in session.toggleAlphaLock(layer.id) })) {
                    Label("Alpha", systemImage: "lock.square.stack")
                }
                .disabled(layer.kind != .paint)
                .accessibilityLabel("Transparenz schützen")
                Menu {
                    Picker("Mischmodus", selection: Binding(get: { layer.blendMode }, set: { session.setBlendMode($0, for: layer.id) })) {
                        ForEach(LayerBlendMode.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Text(layer.blendMode.title).lineLimit(1).frame(minHeight: 44)
                }
            }
            .toggleStyle(.button)
            .frame(minHeight: 44)
            .font(.caption)

            HStack(spacing: 4) {
                Button {
                    session.setOpacity(layer.opacity - 0.01, for: layer.id)
                } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                .accessibilityLabel("Deckkraft verringern")
                Slider(
                    value: Binding(get: { layer.opacity }, set: { session.setOpacityLive($0, for: layer.id) }),
                    in: 0...1,
                    onEditingChanged: { editing in if !editing { session.endOpacityGesture() } }
                )
                .accessibilityLabel("Deckkraft")
                Button {
                    session.setOpacity(layer.opacity + 0.01, for: layer.id)
                } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                .accessibilityLabel("Deckkraft erhöhen")
                Text("\(Int((layer.opacity * 100).rounded())) %")
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// iPhone and narrow iPad windows: the same list in a sheet.
struct LayersSheet: View {
    @ObservedObject var session: DrawingSession

    var body: some View {
        ArtworkLayersView(session: session)
            .padding(.top, 12)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
}

#Preview("Ebenen – Panel (iPad)") {
    ArtworkLayersView(session: DrawingSession(artworkID: UUID(), library: ArtworkLibrary(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview"))))
        .frame(width: 320, height: 700)
}

#Preview("Ebenen – Sheet (iPhone)") {
    Color.clear.sheet(isPresented: .constant(true)) {
        LayersSheet(session: DrawingSession(artworkID: UUID(), library: ArtworkLibrary(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview"))))
    }
}
