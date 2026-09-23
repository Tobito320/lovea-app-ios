import Foundation

/// `GET /gif?q=` (Z-5.3): our server pass-through of Klipy's `search`/`trending` response — see
/// `server/index.js`'s `gifProxy`, which forwards Klipy's JSON verbatim. Parsed defensively (every
/// field optional down to the URL) since Block 5 has no live Klipy fixture to check the exact shape
/// against; a field Klipy renames just drops that one GIF instead of crashing the whole sheet.
enum KlipyClient {
    struct Gif: Identifiable, Equatable, Sendable {
        let id: String
        let url: String
        let breite: Double
        let hoehe: Double
    }

    enum Fehler: Error { case nichtEingerichtet, anfrage }

    /// Debounced by the caller (Klipy's test key allows 100 calls/hour) — see `GifStickerBlatt`.
    static func suchen(_ q: String) async throws -> [Gif] {
        guard let konfig = await Raum.shared.httpKonfiguration() else { throw Fehler.nichtEingerichtet }
        var comps = URLComponents(url: konfig.basis.appendingPathComponent("gif"), resolvingAgainstBaseURL: false)
        if !q.isEmpty { comps?.queryItems = [URLQueryItem(name: "q", value: q)] }
        guard let url = comps?.url else { throw Fehler.anfrage }
        var request = URLRequest(url: url)
        for (feld, wert) in konfig.headers { request.setValue(wert, forHTTPHeaderField: feld) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Fehler.anfrage }
        if http.statusCode == 503 { throw Fehler.nichtEingerichtet }
        guard (200..<300).contains(http.statusCode) else { throw Fehler.anfrage }
        return parse(data)
    }

    /// Masonry (fix round 2): two columns, each GIF goes into the currently shorter one, heights
    /// measured relative to the column width. A GIF without a size counts as square.
    nonisolated static func spalten(_ gifs: [Gif]) -> (links: [Gif], rechts: [Gif]) {
        var links: [Gif] = []
        var rechts: [Gif] = []
        var hoeheLinks = 0.0
        var hoeheRechts = 0.0
        for gif in gifs {
            let hoehe = gif.breite > 0 && gif.hoehe > 0 ? gif.hoehe / gif.breite : 1
            if hoeheLinks <= hoeheRechts {
                links.append(gif)
                hoeheLinks += hoehe
            } else {
                rechts.append(gif)
                hoeheRechts += hoehe
            }
        }
        return (links, rechts)
    }

    /// Pure parse of Klipy's JSON — testable without the network. Prefers `md`, falls back to
    /// `sm`/`hd`; skips any entry without at least a usable URL.
    nonisolated static func parse(_ data: Data) -> [Gif] {
        guard let huelle = try? JSONDecoder().decode(KlipyHuelle.self, from: data) else { return [] }
        return (huelle.data?.data ?? []).compactMap { eintrag -> Gif? in
            guard let id = eintrag.id, let datei = eintrag.file?.md ?? eintrag.file?.sm ?? eintrag.file?.hd,
                  let gif = datei.gif, let url = gif.url
            else { return nil }
            return Gif(id: id, url: url, breite: gif.width ?? 0, hoehe: gif.height ?? 0)
        }
    }
}

private struct KlipyHuelle: Decodable { let data: KlipyDaten? }
private struct KlipyDaten: Decodable { let data: [KlipyEintrag]? }
/// Klipy sends `id` as a JSON number; a `String` field made the whole list fail to decode (empty grid).
private struct KlipyEintrag: Decodable {
    let id: String?
    let file: KlipyDateien?
    enum CodingKeys: String, CodingKey { case id, file }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let zahl = try? c.decode(Int64.self, forKey: .id) { id = String(zahl) } else { id = try? c.decode(String.self, forKey: .id) }
        file = try? c.decode(KlipyDateien.self, forKey: .file)
    }
}
private struct KlipyDateien: Decodable { let hd: KlipyGroesse?; let md: KlipyGroesse?; let sm: KlipyGroesse? }
private struct KlipyGroesse: Decodable { let gif: KlipyGif? }
private struct KlipyGif: Decodable { let url: String?; let width: Double?; let height: Double? }
