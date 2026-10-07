import SwiftUI

/// Einfache Diagnose-Seite: Einstellungen → Chat-Leistung.
struct ChatPerfView: View {
    private let perf = ChatPerf.shared

    private func ms(_ wert: Double?) -> String { wert.map { String(format: "%.0f ms", $0) } ?? "–" }

    var body: some View {
        let s = perf.statistik
        List {
            Section("Gesamt (Senden → sichtbar)") {
                zeile("Zuletzt", ms(s.letzteGesamtMs))
                zeile("Durchschnitt", ms(s.anzahl > 0 ? s.durchschnittGesamtMs : nil))
                zeile("P50", ms(s.anzahl > 0 ? s.p50GesamtMs : nil))
                zeile("P95", ms(s.anzahl > 0 ? s.p95GesamtMs : nil))
            }
            Section("Aufteilung (Durchschnitt)") {
                zeile("Tippen → Anfrage", ms(s.anzahl > 0 ? s.durchschnittTapZuRequestMs : nil))
                zeile("Anfrage → Antwort", ms(s.anzahl > 0 ? s.durchschnittRequestZuAntwortMs : nil))
                zeile("Antwort → Anzeige", ms(s.anzahl > 0 ? s.durchschnittAntwortZuRenderMs : nil))
            }
            Section("Chat laden") {
                zeile("Proben", "\(s.anzahl)")
                zeile("Geladene Nachrichten", "\(ChatModell.shared.nachrichten.count)")
                zeile("Letzter Fold", ms(perf.letzteFaltungMs))
                zeile("Chat öffnen → Liste", ms(perf.ersteSichtbarMs))
            }
            Section("Wahrscheinlicher Engpass") {
                Text(perf.engpass.rawValue).font(.headline)
                Text(perf.engpass.erklaerung).font(.footnote).foregroundStyle(.secondary)
            }
            Section("Letzte Messungen") {
                if perf.traces.isEmpty {
                    Text("Noch keine. Sende eine Textnachricht.").foregroundStyle(.secondary)
                }
                ForEach(perf.traces.suffix(20).reversed()) { t in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(ms(t.totalSendToVisibleMs))\(t.success ? "" : " · \(t.errorCategory ?? "Fehler")")").font(.subheadline.monospacedDigit())
                        Text("\(ms(t.tapToRequestStartMs)) · \(ms(t.requestToResponseMs)) · \(ms(t.responseToRenderMs)) · \(t.loadedMessageCount) Nachr.")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button("Messungen löschen", role: .destructive) { perf.leeren() }
            }
        }
        .navigationTitle("Chat-Leistung")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack { Text(titel); Spacer(); Text(wert).monospacedDigit().foregroundStyle(.secondary) }
    }
}
