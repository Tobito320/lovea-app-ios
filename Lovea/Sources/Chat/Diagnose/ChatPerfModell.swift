import Foundation

/// Chat-Performance-Diagnose: reine Datentypen und Rechenlogik (kein UI, kein Netz).
/// Enthält nie Nachrichteninhalt, Tokens oder Anhänge — nur Zeiten und Zähler.

/// Eine abgeschlossene Messung für genau eine gesendete Textnachricht.
struct ChatPerfTrace: Codable, Sendable, Identifiable, Equatable {
    let traceId: String
    let conversationId: String
    /// Wanduhr nur zur Anzeige/Sortierung — alle Dauern kommen aus der monotonen Uhr.
    let zeitpunkt: Date
    /// A → B: Tippen auf Senden bis die Anfrage an den Transport geht.
    let tapToRequestStartMs: Double
    /// B → C: Anfrage raus bis die Server-Bestätigung (Echo mit `seq`) da ist.
    let requestToResponseMs: Double
    /// C → D: Bestätigung da bis die Liste sie gerendert hat (onChange nach Body-Update).
    let responseToRenderMs: Double
    /// A → D gesamt.
    let totalSendToVisibleMs: Double
    /// A → eigene Nachricht lokal (optimistisch) in der Liste sichtbar; nil wenn nie gesehen.
    let tapToLocalVisibleMs: Double?
    let success: Bool
    /// Nur Kategorie, nie Text: "timeout", "abbruch".
    let errorCategory: String?
    let loadedMessageCount: Int
    let attachmentCount: Int

    var id: String { traceId }
}

/// Kleine ringförmige Ablage der letzten Messungen (begrenzter Speicher).
struct ChatPerfSpeicher: Sendable {
    let limit: Int
    private(set) var traces: [ChatPerfTrace] = []

    init(limit: Int = 100) { self.limit = max(1, limit) }

    mutating func hinzufuegen(_ trace: ChatPerfTrace) {
        traces.append(trace)
        if traces.count > limit { traces.removeFirst(traces.count - limit) }
    }

    mutating func leeren() { traces = [] }
}

struct ChatPerfStatistik: Equatable, Sendable {
    var anzahl = 0
    var letzteGesamtMs: Double?
    var durchschnittGesamtMs = 0.0
    var p50GesamtMs = 0.0
    var p95GesamtMs = 0.0
    var durchschnittTapZuRequestMs = 0.0
    var durchschnittRequestZuAntwortMs = 0.0
    var durchschnittAntwortZuRenderMs = 0.0

    /// Nearest-rank-Perzentil (p in 0…100) auf unsortierter Eingabe. Leer → 0.
    static func perzentil(_ werte: [Double], _ p: Double) -> Double {
        guard !werte.isEmpty else { return 0 }
        let sortiert = werte.sorted()
        let rang = Int((min(max(p, 0), 100) / 100 * Double(sortiert.count)).rounded(.up))
        return sortiert[min(max(rang, 1), sortiert.count) - 1]
    }

    /// Nur erfolgreiche Traces zählen — Timeouts würden die Mittelwerte verfälschen.
    static func berechnen(_ traces: [ChatPerfTrace]) -> ChatPerfStatistik {
        let ok = traces.filter(\.success)
        guard !ok.isEmpty else { return ChatPerfStatistik() }
        func mittel(_ f: (ChatPerfTrace) -> Double) -> Double { ok.map(f).reduce(0, +) / Double(ok.count) }
        let gesamt = ok.map(\.totalSendToVisibleMs)
        return ChatPerfStatistik(
            anzahl: ok.count,
            letzteGesamtMs: ok.last?.totalSendToVisibleMs,
            durchschnittGesamtMs: mittel(\.totalSendToVisibleMs),
            p50GesamtMs: perzentil(gesamt, 50),
            p95GesamtMs: perzentil(gesamt, 95),
            durchschnittTapZuRequestMs: mittel(\.tapToRequestStartMs),
            durchschnittRequestZuAntwortMs: mittel(\.requestToResponseMs),
            durchschnittAntwortZuRenderMs: mittel(\.responseToRenderMs)
        )
    }
}

enum ChatPerfEngpass: String, Sendable, Equatable {
    case clientScheduling, networkOrBackend, rendering, scalingWithMessageCount, mixed, insufficientData

    static let mindestProben = 5
    /// Ein Abschnitt "dominiert", wenn er mindestens diesen Anteil der Summe hat und über `schwelleMs` liegt.
    static let dominanz = 0.5
    static let schwelleMs = 100.0

    /// Deterministisch, ohne ML. Skalierung zuerst: steigt die Gesamtzeit klar mit der Nachrichtenzahl
    /// (Korrelation ≥ 0.7 und Anstieg ≥ 50 ms zwischen kleiner und großer Hälfte), ist es Größe, nicht Netz.
    static func klassifizieren(_ traces: [ChatPerfTrace]) -> ChatPerfEngpass {
        let ok = traces.filter(\.success)
        guard ok.count >= mindestProben else { return .insufficientData }
        let s = ChatPerfStatistik.berechnen(ok)
        if skaliertMitAnzahl(ok) { return .scalingWithMessageCount }
        let a = s.durchschnittTapZuRequestMs, b = s.durchschnittRequestZuAntwortMs, c = s.durchschnittAntwortZuRenderMs
        let summe = a + b + c
        guard summe >= schwelleMs else { return .mixed }
        if b >= dominanz * summe && b >= schwelleMs { return .networkOrBackend }
        if c >= dominanz * summe && c >= schwelleMs { return .rendering }
        if a >= dominanz * summe && a >= schwelleMs { return .clientScheduling }
        return .mixed
    }

    private static func skaliertMitAnzahl(_ ok: [ChatPerfTrace]) -> Bool {
        let n = ok.map { Double($0.loadedMessageCount) }
        let t = ok.map(\.totalSendToVisibleMs)
        guard (n.max() ?? 0) - (n.min() ?? 0) >= 50 else { return false }
        let mn = n.reduce(0, +) / Double(n.count), mt = t.reduce(0, +) / Double(t.count)
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for i in n.indices {
            sxy += (n[i] - mn) * (t[i] - mt); sxx += (n[i] - mn) * (n[i] - mn); syy += (t[i] - mt) * (t[i] - mt)
        }
        guard sxx > 0, syy > 0 else { return false }
        let korrelation = sxy / (sxx.squareRoot() * syy.squareRoot())
        let sortiert = ok.sorted { $0.loadedMessageCount < $1.loadedMessageCount }
        let h = sortiert.count / 2
        let klein = sortiert[..<h].map(\.totalSendToVisibleMs), gross = sortiert[h...].map(\.totalSendToVisibleMs)
        let anstieg = gross.reduce(0, +) / Double(gross.count) - klein.reduce(0, +) / Double(klein.count)
        return korrelation >= 0.7 && anstieg >= 50
    }

    var erklaerung: String {
        switch self {
        case .clientScheduling: "Lange Zeit zwischen Tippen und Anfrage. Die App ist beschäftigt (Hauptthread, Warteschlange)."
        case .networkOrBackend: "Lange Zeit zwischen Anfrage und Bestätigung. Netz oder Server sind langsam."
        case .rendering: "Lange Zeit zwischen Bestätigung und Anzeige. SwiftUI braucht lange zum Zeichnen."
        case .scalingWithMessageCount: "Je mehr Nachrichten geladen sind, desto langsamer. Die Chat-Größe bremst."
        case .mixed: "Kein einzelner Abschnitt dominiert."
        case .insufficientData: "Zu wenige Messungen. Sende mindestens 5 Nachrichten."
        }
    }
}

/// Schnittstelle für späteren Upload (Backend-Endpunkt fehlt noch, siehe docs/PERFORMANCE_MCP.md).
protocol ChatPerfUploader: Sendable {
    func hochladen(_ traces: [ChatPerfTrace]) async throws
}
