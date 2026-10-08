import Foundation

/// p64: Titel, Künstler und Cover zu einem Spotify-Link. Ohne Anmeldung und ohne Schlüssel: Titel und Cover
/// kommen von oEmbed, der Künstler (steht dort nicht) aus dem Seitenkopf. Läuft einmal, wenn jemand einen
/// Link teilt; das Ergebnis reist in der Op mit, danach fragt kein Gerät mehr nach.
enum SpotifyAbfrage {
    struct Titel: Equatable, Sendable {
        var id: String
        var titel: String
        var kuenstler: String?
        var cover: String?
    }

    /// Mehr als die ersten Seitenkilobytes brauchen wir nicht, der Künstler steht ganz oben im Kopf.
    private static let kopfGrenze = 160_000

    static func laden(id: String) async -> Titel? {
        let link = AlltagLogik.spotifyLink(id)
        var teile = URLComponents(string: "https://open.spotify.com/oembed")
        teile?.queryItems = [URLQueryItem(name: "url", value: link)]
        guard let url = teile?.url else { return nil }
        var anfrage = URLRequest(url: url)
        anfrage.timeoutInterval = 10
        guard let (daten, antwort) = try? await URLSession.shared.data(for: anfrage),
              (antwort as? HTTPURLResponse)?.statusCode == 200,
              let meta = AlltagLogik.oembed(daten) else { return nil }
        return Titel(id: id, titel: meta.titel, kuenstler: await kuenstler(link), cover: meta.cover)
    }

    /// Liest die Seite nur, bis `og:description` kam. Jeder Fehler heißt einfach: kein Künstler.
    private static func kuenstler(_ link: String) async -> String? {
        guard let url = URL(string: link) else { return nil }
        var anfrage = URLRequest(url: url)
        anfrage.timeoutInterval = 8
        guard let (strom, _) = try? await URLSession.shared.bytes(for: anfrage) else { return nil }
        var puffer = Data()
        do {
            for try await byte in strom {
                puffer.append(byte)
                guard puffer.count % 8192 == 0 || puffer.count >= kopfGrenze else { continue }
                if let name = AlltagLogik.kuenstler(ausKopf: String(decoding: puffer, as: UTF8.self)) { return name }
                if puffer.count >= kopfGrenze { break }
            }
        } catch {
            return nil
        }
        return AlltagLogik.kuenstler(ausKopf: String(decoding: puffer, as: UTF8.self))
    }
}
