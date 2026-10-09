import Foundation

/// Eigene Produkt-Datenbank auf dem Lovea-Server (`server/essen.js`).
enum EssenServer {
    enum Fehler: Error { case nichtEingerichtet, netz }

    private struct Produkt: Decodable {
        let code: String
        let name: String
        let marke: String?
        let portion_g: Double?
        let portion_name: String?
        let pro100: Naehrwerte
    }
    private struct BarcodeAntwort: Decodable { let produkt: Produkt? }
    private struct SucheAntwort: Decodable { let treffer: [Produkt] }
    private struct NameAntwort: Decodable { let name: String?; let marke: String? }

    private static func lebensmittel(_ p: Produkt) -> Lebensmittel {
        Lebensmittel(id: "off-\(p.code)", name: p.name, marke: p.marke, barcode: p.code, pro100: p.pro100,
                     portionMenge: p.portion_g, portionName: p.portion_g == nil ? nil : p.portion_name.flatMap(ErnaehrungLogik.portionsName))
    }

    private static func laden(_ pfad: String, _ query: [URLQueryItem] = []) async throws -> (Data, Int) {
        guard let konfig = await Raum.shared.httpKonfiguration() else { throw Fehler.nichtEingerichtet }
        var comps = URLComponents(url: konfig.basis.appendingPathComponent(pfad), resolvingAgainstBaseURL: false)
        if !query.isEmpty { comps?.queryItems = query }
        guard let url = comps?.url else { throw Fehler.netz }
        var anfrage = URLRequest(url: url)
        anfrage.timeoutInterval = 6
        for (feld, wert) in konfig.headers { anfrage.setValue(wert, forHTTPHeaderField: feld) }
        let (data, antwort) = try await URLSession.shared.data(for: anfrage)
        return (data, (antwort as? HTTPURLResponse)?.statusCode ?? 0)
    }

    static func barcode(_ code: String) async throws -> Lebensmittel? {
        let (data, status) = try await laden("essen/barcode/\(code)")
        if status == 404 { return nil }
        guard (200..<300).contains(status) else { throw Fehler.netz }
        return try JSONDecoder().decode(BarcodeAntwort.self, from: data).produkt.map(lebensmittel)
    }

    static func suchen(_ text: String) async throws -> [Lebensmittel] {
        let (data, status) = try await laden("essen/suche", [URLQueryItem(name: "q", value: text), URLQueryItem(name: "n", value: "30")])
        guard (200..<300).contains(status) else { throw Fehler.netz }
        return try JSONDecoder().decode(SucheAntwort.self, from: data).treffer.map(lebensmittel)
    }

    static func name(_ code: String) async throws -> (name: String, marke: String?)? {
        let (data, status) = try await laden("essen/name/\(code)")
        guard (200..<300).contains(status), let a = try? JSONDecoder().decode(NameAntwort.self, from: data), let n = a.name else { return nil }
        return (n, a.marke)
    }
}
