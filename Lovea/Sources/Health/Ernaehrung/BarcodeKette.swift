import Foundation

enum BarcodeLogik {
    /// Nur Ziffern; UPC-A (12) bekommt eine führende 0. Gleiche Regel wie `normalisiere` in `server/essen.js`.
    static func normal(_ roh: String) -> String {
        let z = roh.filter(\.isNumber)
        return z.count == 12 ? "0" + z : z
    }

    /// Text im Suchfeld sieht wie ein getippter/eingefügter Barcode aus: nur Ziffern, plausible Länge
    /// (EAN-8, UPC-A oder EAN-13). Alles andere bleibt normale Textsuche.
    static func istBarcodeEingabe(_ text: String) -> Bool {
        guard text.allSatisfy(\.isNumber) else { return false }
        return [8, 12, 13].contains(text.count)
    }
}

enum BarcodeErgebnis: Equatable {
    case gefunden(Lebensmittel)
    case vorschlaege(name: String, [Lebensmittel])
    case unbekannt(String)
    case offline(String)
}

struct BarcodeQuellen: Sendable {
    var lokal: @Sendable (String) async -> Lebensmittel?
    var server: @Sendable (String) async throws -> Lebensmittel?
    var offLive: @Sendable (String) async throws -> Lebensmittel?
    var name: @Sendable (String) async throws -> (name: String, marke: String?)?
    var namensSuche: @Sendable (String) async -> [Lebensmittel]

    static var echt: BarcodeQuellen {
        BarcodeQuellen(
            lokal: { code in await MainActor.run { ErnaehrungModell.shared.offline(barcode: code) } },
            server: { try await EssenServer.barcode($0) },
            offLive: { try await OFFClient.produkt($0) },
            name: { try await EssenServer.name($0) },
            namensSuche: { text in
                let lokal = LebensmittelIndex.shared.suchen(text, vorne: [], anzahl: 3)
                let server = (try? await EssenServer.suchen(text)) ?? []
                return Array((server + lokal).prefix(5))
            })
    }
}

/// Lokal -> eigener Server -> Open Food Facts live -> Name (Open EAN Database) mit Vorschlägen.
enum BarcodeKette {
    static func suchen(_ roh: String, _ q: BarcodeQuellen) async -> BarcodeErgebnis {
        let code = BarcodeLogik.normal(roh)
        if let l = await q.lokal(code) { return .gefunden(l) }
        var netzFehler = 0
        do { if let l = try await q.server(code) { return .gefunden(l) } } catch { netzFehler += 1 }
        do { if let l = try await q.offLive(code) { return .gefunden(l) } } catch { netzFehler += 1 }
        if netzFehler == 2 { return .offline(code) }
        if let n = try? await q.name(code) {
            let text = [n.marke, n.name].compactMap { $0 }.joined(separator: " ")
            let vorschlaege = await q.namensSuche(text)
            if !vorschlaege.isEmpty { return .vorschlaege(name: n.name, vorschlaege) }
        }
        return .unbekannt(code)
    }
}
