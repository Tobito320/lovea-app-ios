import SwiftUI

struct InsertToolsView: View {
    @ObservedObject var session: DrawingSession
    @Environment(\.dismiss) private var dismiss
    @State private var shape: ShapeKind = .line
    @State private var filled = false
    @State private var text = ""
    @State private var fontSize = 96.0
    @State private var fontIndex = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Form") {
                    Picker("Form", selection: $shape) {
                        ForEach(ShapeKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    Toggle("Gefüllt", isOn: $filled)
                        .disabled(shape == .line)
                    Button("Form einfügen") {
                        session.addShape(shape, filled: shape == .line ? false : filled)
                        dismiss()
                    }
                }

                Section("Text") {
                    TextField("Text", text: $text, axis: .vertical)
                        .lineLimit(2...5)
                    Slider(value: $fontSize, in: 24...240, step: 4) {
                        Text("Größe")
                    }
                    Text("Schriftgröße: \(Int(fontSize))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Schrift", selection: $fontIndex) {
                        Text("Helvetica").tag(0)
                        Text("Avenir").tag(1)
                        Text("Georgia").tag(2)
                        Text("Courier").tag(3)
                    }
                    Button("Text einfügen") {
                        session.addText(text, fontSize: fontSize, fontIndex: fontIndex)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section {
                    Slider(value: $session.fillTolerance, in: 0...0.5)
                    Text("Toleranz: \(Int(session.fillTolerance * 100)) %")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Farbeimer")
                } footer: {
                    Text("Füllen arbeitet auf dem sichtbaren zusammengesetzten Bild und legt die Füllung zerstörungsfrei als eigene Ebene ab.")
                }
            }
            .navigationTitle("Formen & Text")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
