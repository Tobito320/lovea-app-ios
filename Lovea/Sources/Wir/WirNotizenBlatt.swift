import SwiftUI

/// Geteilte Notizen von Ahmed und Annika. Tap auf eine Zeile öffnet den Editor, Swipe nach links löscht.
struct NotizenBlatt: View {
    let speicher = WirNotizSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editor: NotizEditorZiel?

    var body: some View {
        NavigationStack {
            List {
                if speicher.notizen.isEmpty {
                    Text("Noch keine Notizen. Mit + legst du die erste an.")
                        .foregroundStyle(.secondary)
                }
                ForEach(speicher.notizen) { notiz in
                    Button { editor = NotizEditorZiel(notiz: notiz) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notiz.text).lineLimit(4)
                            Text(notiz.von.name).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { speicher.loeschen(notiz.id) } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Notizen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { editor = NotizEditorZiel(notiz: nil) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Neue Notiz")
                }
            }
            .sheet(item: $editor) { ziel in NotizEditor(notiz: ziel.notiz) }
        }
    }
}

struct NotizEditorZiel: Identifiable {
    let id = UUID()
    let notiz: WirNotiz?
}

private struct NotizEditor: View {
    let notiz: WirNotiz?
    let speicher = WirNotizSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(notiz: WirNotiz?) {
        self.notiz = notiz
        _text = State(initialValue: notiz?.text ?? "")
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding(12)
                .navigationTitle(notiz == nil ? "Neue Notiz" : "Notiz")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Sichern") {
                            if let notiz { speicher.aendern(notiz.id, text: text) } else { speicher.anlegen(text) }
                            dismiss()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}
