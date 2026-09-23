import Foundation

/// Sendet eine `habit.setzen`-Op direkt aus dem Widget-Prozess (Z-28.3) — eigene, kleine
/// Op-Verdrahtung statt des App-Targets `Op`/`Raum` (App Group teilt nur Daten, keinen Code über
/// die Zielgrenze hinweg, siehe common.md "du besitzt `LoveaWidgets/`, nicht die App-Modelle").
/// Server und Schlüssel kommen aus dem EIGENEN Info.plist der Erweiterung (`LoveaServer`/
/// `LoveaAppKey`, project.yml — dieselben Build-Settings wie im App-Target, siehe Bericht).
enum WidgetOpPoster {
    /// Schreibt die Pending-Datei sofort (übersteht Absturz/Timeout der Erweiterung), versucht
    /// danach den direkten `POST /ops` und löscht die Datei nur bei einer 2xx-Antwort — alles
    /// andere holt die App beim nächsten `.active` ab (`WidgetPendingOpsMerge`, App-Target).
    static func gymHeuteSenden(von person: String, datum: String, wert: Int) async {
        let pending = WidgetPendingOp(id: UUID().uuidString, von: person, zeit: isoJetzt(), datum: datum, wert: wert)
        guard let ordner = WidgetGruppe.pendingOrdner() else { return }
        let datei = ordner.appendingPathComponent("\(pending.id).json")
        guard let daten = try? JSONEncoder().encode(pending) else { return }
        try? daten.write(to: datei, options: .atomic)

        guard await posten(pending) else { return }
        try? FileManager.default.removeItem(at: datei)
    }

    private static func posten(_ pending: WidgetPendingOp) async -> Bool {
        guard let server = Bundle.main.object(forInfoDictionaryKey: "LoveaServer") as? String, !server.isEmpty,
              let basis = URL(string: server)
        else { return false }
        let schluessel = (Bundle.main.object(forInfoDictionaryKey: "LoveaAppKey") as? String) ?? ""
        guard !schluessel.isEmpty else { return false }
        guard let bodyDaten = try? JSONEncoder().encode(WireBody(ops: [WireOp(pending)])) else { return false }

        var request = URLRequest(url: basis.appendingPathComponent("ops"))
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(schluessel, forHTTPHeaderField: "X-Lovea-Key")
        request.setValue(pending.von, forHTTPHeaderField: "X-Lovea-Person")
        request.httpBody = bodyDaten

        guard let (_, antwort) = try? await URLSession.shared.data(for: request) else { return false }
        guard let http = antwort as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }

    private static func isoJetzt() -> String {
        let formatierer = ISO8601DateFormatter()
        formatierer.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatierer.string(from: Date())
    }
}

/// Server-Wire-Format (`server/raum-logic.js` `opGueltig`): `{id, art, von, zeit, d}`, `d` ein
/// flaches JSON-Objekt — genau wie `Op`s eigener Encoder im App-Target, hier nur ohne dessen Typ.
private struct WireHabitD: Encodable { var art = "gym"; var datum: String; var wert: Int }
private struct WireOp: Encodable {
    var id: String; var art = "habit.setzen"; var von: String; var zeit: String; var d: WireHabitD
    init(_ pending: WidgetPendingOp) {
        id = pending.id; von = pending.von; zeit = pending.zeit
        d = WireHabitD(datum: pending.datum, wert: pending.wert)
    }
}
private struct WireBody: Encodable { var ops: [WireOp] }
