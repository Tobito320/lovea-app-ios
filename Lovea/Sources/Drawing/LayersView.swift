import SwiftUI

struct LayersView: View {
    @ObservedObject var store: DrawingStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.document.layers.reversed()) { layer in
                    Button {
                        store.selectLayer(layer.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Button {
                                store.toggleLayerVisibility(layer.id)
                            } label: {
                                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(layer.isVisible ? "Ebene ausblenden" : "Ebene einblenden")

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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        if store.document.layers.count > 1 {
                            Button(role: .destructive) {
                                store.deleteLayer(layer.id)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
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
    }
}
