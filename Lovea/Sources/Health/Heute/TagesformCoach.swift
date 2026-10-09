import Foundation

/// Tagesform vom Coach-Server (`POST coach/tagesform`). Der Server begründet den Wert und hält ihn unter der
/// Schlaf-Grenze. Jeder Fehler (kein Netz, kein Schlüssel, Limit) heißt: `nil`, dann gilt die Regel in `TagesformLogik`.
enum TagesformCoach {
    struct Eingabe: Encodable, Equatable, Sendable {
        let schlafMinuten: Int?
        let schlafZiel: Int
        let wasser: Int
        let wasserZiel: Int
        let schritte: Int?
        let schritteZiel: Int
        let erholung: Double

        /// Gleicher Schlüssel = gleiche Antwort. Erholung auf Prozent gerundet, damit Rauschen nicht neu fragt.
        var schluessel: String {
            "\(schlafMinuten ?? -1)|\(schlafZiel)|\(wasser)|\(wasserZiel)|\(schritte ?? -1)|\(schritteZiel)|\(Int((erholung * 100).rounded()))"
        }
    }

    struct Antwort: Equatable, Sendable {
        let schluessel: String
        let akku: Int?
        let satz: String
    }

    private struct Gelesen: Decodable { let akku: Int?; let satz: String? }

    /// Pro Start der App und Stand der Zahlen einmal fragen.
    @MainActor private static var gemerkt: [String: Antwort] = [:]

    /// Ohne Schlafwert gibt es nichts zu fragen. Wartet kurz, damit schnelle Eingaben (Wasser tippen) nur eine Frage ergeben.
    @MainActor
    static func laden(_ e: Eingabe) async -> Antwort? {
        guard e.schlafMinuten != nil else { return nil }
        if let a = gemerkt[e.schluessel] { return a }
        do { try await Task.sleep(for: .seconds(1.5)) } catch { return nil }
        guard let konfig = Raum.shared.httpKonfiguration(), let body = try? JSONEncoder().encode(e) else { return nil }
        var anfrage = URLRequest(url: konfig.basis.appendingPathComponent("coach/tagesform"))
        anfrage.httpMethod = "POST"
        anfrage.timeoutInterval = 20
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (feld, wert) in konfig.headers { anfrage.setValue(wert, forHTTPHeaderField: feld) }
        anfrage.httpBody = body
        guard let (daten, antwort) = try? await URLSession.shared.data(for: anfrage),
              (antwort as? HTTPURLResponse)?.statusCode == 200,
              let g = try? JSONDecoder().decode(Gelesen.self, from: daten), let akku = g.akku else { return nil }
        let a = Antwort(schluessel: e.schluessel, akku: min(100, max(0, akku)), satz: g.satz ?? "")
        gemerkt[e.schluessel] = a
        return a
    }
}
