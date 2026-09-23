import SwiftUI

/// Dezente Statuszeile unter der Navigationsleiste von Chat und Home (Z-2.6).
/// Zeigt nichts, solange verbunden oder die Warteschlange leer ist.
struct SyncStatusZeile: View {
    var body: some View {
        if let text {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(.bar)
        }
    }

    private var text: String? {
        let raum = Raum.shared
        guard raum.eingerichtet else { return "Server nicht eingerichtet" }
        guard !raum.verbunden, raum.wartet > 0 else { return nil }
        return "Wartet auf Netz (\(raum.wartet))"
    }
}
