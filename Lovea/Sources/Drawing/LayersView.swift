import SwiftUI

struct LayersView: View {
    @ObservedObject var store: DrawingStore
    @Environment(\.dismiss) private var dismiss
    @State private var renameLayerID: UUID?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.document.layers.reversed()) { layer in
                    VStack(spacing: 8) {
                        HStack(spacing: 14) {
                            Button {
                                store.toggleLayerVisibility(layer.id)
                            } label: {
                                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(layer.isVisible ? "Ebene ausblenden" : "Ebene einblenden")

                            Button {
                                store.selectLayer(layer.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(layer.name)
                                        Text("\(layer.strokes.count) Striche")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if layer.id == store.activeLayerID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        if layer.id == store.activeLayerID {
                            HStack(spacing: 12) {
                                Text("Deckkraft")
                                    .font(.subheadline)
                                Slider(
                                    value: opacityBinding(for: layer.id),
                                    in: 0...1,
                                    step: 0.01,
                                    onEditingChanged: { editing in
                                        if editing {
                                            store.beginLayerOpacityEditing(layer.id)
                                        } else {
                                            store.endLayerOpacityEditing(layer.id)
                                        }
                                    }
                                )
                                .accessibilityLabel("Deckkraft")
                                .accessibilityValue(Text(layer.opacity, format: .percent))
                                Text(layer.opacity, format: .percent.precision(.fractionLength(0)))
                                    .monospacedDigit()
                                    .frame(minWidth: 44, alignment: .trailing)
                            }
                        }
                    }
                    .listRowBackground(
                        layer.id == store.activeLayerID ? Color.accentColor.opacity(0.12) : Color.clear
                    )
                    .swipeActions {
                        if store.document.layers.count > 1 {
                            Button(role: .destructive) {
                                store.deleteLayer(layer.id)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Umbenennen") {
                            renameText = layer.name
                            renameLayerID = layer.id
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Ebenen")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.addLayer()
                    } label: {
                        Label("Ebene hinzufügen", systemImage: "plus")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert("Ebene umbenennen", isPresented: renameAlertBinding) {
            TextField("Name", text: $renameText)
            Button("Abbrechen", role: .cancel) {}
            Button("Umbenennen") {
                if let renameLayerID {
                    store.renameLayer(renameText, id: renameLayerID)
                }
                renameLayerID = nil
            }
        }
    }

    private func opacityBinding(for id: UUID) -> Binding<Double> {
        Binding(
            get: { store.document.layers.first(where: { $0.id == id })?.opacity ?? 1 },
            set: { store.updateLayerOpacity($0, id: id) }
        )
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renameLayerID != nil },
            set: { if !$0 { renameLayerID = nil } }
        )
    }
}
