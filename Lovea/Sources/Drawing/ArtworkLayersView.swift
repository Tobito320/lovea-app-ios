import SwiftUI

struct ArtworkLayersView: View {
    @ObservedObject var session: DrawingSession
    @Environment(\.dismiss) private var dismiss
    @State private var renameLayerID: UUID?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(session.document.layers.reversed())) { layer in
                    layerRow(layer)
                }
            }
            .navigationTitle("Ebenen")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        session.addPaintLayer()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Zeichenebene hinzufügen")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert("Ebene umbenennen", isPresented: renameBinding) {
            TextField("Name", text: $renameText)
            Button("Abbrechen", role: .cancel) {}
            Button("Umbenennen") {
                if let renameLayerID {
                    session.renameLayer(renameLayerID, to: renameText)
                }
                renameLayerID = nil
            }
        }
    }

    @ViewBuilder
    private func layerRow(_ layer: ArtworkLayer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    session.toggleVisibility(layer.id)
                } label: {
                    Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button {
                    session.toggleLock(layer.id)
                } label: {
                    Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button {
                    session.selectLayer(layer.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(layer.name)
                            .fontWeight(layer.id == session.activeLayerID ? .semibold : .regular)
                        Text(layer.kind == .paint ? "Zeichenebene" : "Bildebene")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if layer.id == session.activeLayerID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }

            if layer.id == session.activeLayerID {
                HStack {
                    Text("Deckkraft")
                        .font(.caption)
                    Slider(
                        value: Binding(
                            get: { session.document.layers.first(where: { $0.id == layer.id })?.opacity ?? 1 },
                            set: { session.setOpacity($0, for: layer.id) }
                        ),
                        in: 0...1
                    )
                    Text(layer.opacity, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .frame(width: 42, alignment: .trailing)
                }

                Picker("Mischmodus", selection: Binding(
                    get: { session.document.layers.first(where: { $0.id == layer.id })?.blendMode ?? .normal },
                    set: { session.setBlendMode($0, for: layer.id) }
                )) {
                    ForEach(LayerBlendMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Toggle("Clipping", isOn: Binding(
                    get: { session.document.layers.first(where: { $0.id == layer.id })?.clipping ?? false },
                    set: { newValue in
                        let current = session.document.layers.first(where: { $0.id == layer.id })?.clipping ?? false
                        if newValue != current { session.toggleClipping(layer.id) }
                    }
                ))

                Toggle("Transparenz schützen", isOn: Binding(
                    get: { session.document.layers.first(where: { $0.id == layer.id })?.alphaLock ?? false },
                    set: { newValue in
                        let current = session.document.layers.first(where: { $0.id == layer.id })?.alphaLock ?? false
                        if newValue != current { session.toggleAlphaLock(layer.id) }
                    }
                ))

                HStack(spacing: 12) {
                    Button("Umbenennen") {
                        renameText = layer.name
                        renameLayerID = layer.id
                    }
                    Button {
                        session.duplicateLayer(layer.id)
                    } label: {
                        Label("Duplizieren", systemImage: "square.on.square")
                    }
                    Spacer()
                    Button {
                        session.moveLayer(layer.id, by: 1)
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    Button {
                        session.moveLayer(layer.id, by: -1)
                    } label: {
                        Image(systemName: "arrow.down")
                    }
                }
                .font(.caption)

                HStack {
                    Button("Nach unten zusammenführen") {
                        session.mergeActiveDown()
                    }
                    .disabled(session.document.layers.firstIndex(where: { $0.id == layer.id }) == 0)
                    Spacer()
                    Button("Löschen", role: .destructive) {
                        session.deleteLayer(layer.id)
                    }
                    .disabled(session.document.layers.count <= 1)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(
            layer.id == session.activeLayerID ? Color.accentColor.opacity(0.1) : Color.clear
        )
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renameLayerID != nil },
            set: { if !$0 { renameLayerID = nil } }
        )
    }
}
