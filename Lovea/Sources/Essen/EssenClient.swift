import Foundation

// MARK: - Nutzlasten

struct KiProfil: Encodable, Sendable {
    let ziel: String
    let kcal: Int
    let protein: Int
}

struct KiMahlzeit: Encodable, Sendable {
    let name: String
    let kcal: Int
}

/// Ein Tag in der Sprache des Servers (`tag` bei Coach und Bericht, `vortage` beim Bericht).
struct KiTag: Encodable, Sendable {
    var datum: String?
    var kcalGegessen: Int?
    var protein: Int?
    var schritte: Int?
    var schlafH: Double?
    var mahlzeiten: [KiMahlzeit] = []

    enum CodingKeys: String, CodingKey {
        case datum, protein, schritte, mahlzeiten
        case kcalGegessen = "kcal_gegessen"
        case schlafH = "schlaf_h"
    }
}

struct EssenCoachNachricht: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    /// "nutzer" oder "coach"
    let rolle: String
    var text: String

    enum CodingKeys: String, CodingKey { case rolle, text }
}

struct KiKorrektur: Encodable, Sendable {
    let name: String
    let gramm: Double
}

private struct EssenAnfrage: Encodable {
    let bild: String
    let mime: String
    let hinweis: String
    let mahlzeit: String
}

private struct CoachAnfrage: Encodable {
    let nachrichten: [EssenCoachNachricht]
    let profil: KiProfil
    let tag: KiTag
    let stream: Bool
}

private struct BerichtAnfrage: Encodable {
    let profil: KiProfil
    let tag: KiTag
    let vortage: [KiTag]
}

private struct KorrekturAnfrage: Encodable {
    let items: [KiKorrektur]
}

private struct StreamEreignis: Decodable {
    let t: String
    let text: String?
}

// MARK: - Fehler

enum KiFehler: LocalizedError, Equatable {
    case nichtEingerichtet
    case tageslimit(String)
    case guthaben
    case zuVieleAnfragen
    case bildZuGross
    case netz
    case ungueltig
    case unbekannt

    var errorDescription: String? {
        switch self {
        case .nichtEingerichtet: "Die KI ist noch nicht eingerichtet (Server oder Schlüssel fehlt)."
        case .tageslimit(let art): Self.limitText(art)
        case .guthaben: "Das KI-Guthaben ist aufgebraucht. Bitte bei OpenAI aufladen."
        case .zuVieleAnfragen: "Gerade zu viele Anfragen. Probier es gleich nochmal."
        case .bildZuGross: "Das Foto ist zu groß."
        case .netz: "Keine Verbindung zum Server."
        case .ungueltig: "Die Antwort war unbrauchbar. Probier es nochmal."
        case .unbekannt: "Das hat nicht geklappt. Probier es nochmal."
        }
    }

    private static func limitText(_ art: String) -> String {
        switch art {
        case "essen": "Das Foto-Limit für heute ist erreicht. Morgen geht es weiter."
        case "coach": "Das Coach-Limit für heute ist erreicht. Morgen geht es weiter."
        case "bericht": "Für heute gibt es schon genug Berichte. Morgen geht es weiter."
        default: "Das Tageslimit ist erreicht. Morgen geht es weiter."
        }
    }
}

// MARK: - Client

/// Spricht mit den KI-Endpunkten des Lovea-Workers (`/ki/...`). Der OpenAI-Schlüssel liegt nur im
/// Worker, die App kennt ihn nie.
enum KiClient {
    private static func anfrage(_ pfad: String, body: Data) async throws -> URLRequest {
        guard let konfig = await Raum.shared.httpKonfiguration() else { throw KiFehler.nichtEingerichtet }
        var request = URLRequest(url: konfig.basis.appendingPathComponent(pfad))
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (feld, wert) in konfig.headers { request.setValue(wert, forHTTPHeaderField: feld) }
        return request
    }

    nonisolated static func fehler(status: Int, daten: Data) -> KiFehler {
        struct Antwort: Decodable {
            let fehler: String?
            let art: String?
        }
        let antwort = try? JSONDecoder().decode(Antwort.self, from: daten)
        switch (status, antwort?.fehler) {
        case (429, "tageslimit"?): return .tageslimit(antwort?.art ?? "")
        case (429, _): return .zuVieleAnfragen
        case (413, _): return .bildZuGross
        case (503, "guthaben"?): return .guthaben
        case (503, _): return .nichtEingerichtet
        case (400, _): return .ungueltig
        default: return .unbekannt
        }
    }

    private static func senden(_ pfad: String, body: Data) async throws -> Data {
        let request = try await anfrage(pfad, body: body)
        let ergebnis: (Data, URLResponse)
        do {
            ergebnis = try await URLSession.shared.data(for: request)
        } catch {
            throw KiFehler.netz
        }
        guard let http = ergebnis.1 as? HTTPURLResponse else { throw KiFehler.unbekannt }
        guard http.statusCode == 200 else { throw fehler(status: http.statusCode, daten: ergebnis.0) }
        return ergebnis.0
    }

    /// Foto -> Zutaten mit Gramm, Nährwerten, Bereich und versteckten Kalorien.
    static func essen(bild: Data, hinweis: String, mahlzeit: String) async throws -> EssenAnalyse {
        let body = try JSONEncoder().encode(EssenAnfrage(bild: bild.base64EncodedString(), mime: "image/jpeg", hinweis: hinweis, mahlzeit: mahlzeit))
        let daten = try await senden("ki/essen", body: body)
        do {
            return try JSONDecoder().decode(EssenAnalyse.self, from: daten)
        } catch {
            throw KiFehler.ungueltig
        }
    }

    /// Meldet korrigierte Mengen, damit der Server typische Portionen dieser Person lernt.
    /// Best effort: ein Fehler ist egal.
    static func korrigieren(_ items: [KiKorrektur]) async {
        guard !items.isEmpty, let body = try? JSONEncoder().encode(KorrekturAnfrage(items: items)) else { return }
        _ = try? await senden("ki/korrektur", body: body)
    }

    static func bericht(profil: KiProfil, tag: KiTag, vortage: [KiTag]) async throws -> KiBericht {
        let body = try JSONEncoder().encode(BerichtAnfrage(profil: profil, tag: tag, vortage: vortage))
        let daten = try await senden("ki/bericht", body: body)
        do {
            return try JSONDecoder().decode(KiBericht.self, from: daten)
        } catch {
            throw KiFehler.ungueltig
        }
    }

    /// Coach-Antwort als Strom von Textstücken (der Server schickt `data: {"t":"delta","text":...}`).
    static func coach(nachrichten: [EssenCoachNachricht], profil: KiProfil, tag: KiTag) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { fortsetzung in
            let aufgabe = Task {
                do {
                    let body = try JSONEncoder().encode(CoachAnfrage(nachrichten: nachrichten, profil: profil, tag: tag, stream: true))
                    let request = try await anfrage("ki/coach", body: body)
                    let (bytes, antwort) = try await URLSession.shared.bytes(for: request)
                    guard let http = antwort as? HTTPURLResponse else { throw KiFehler.unbekannt }
                    guard http.statusCode == 200 else {
                        var daten = Data()
                        for try await byte in bytes { daten.append(byte) }
                        throw fehler(status: http.statusCode, daten: daten)
                    }
                    for try await zeile in bytes.lines {
                        guard zeile.hasPrefix("data:") else { continue }
                        let json = Data(zeile.dropFirst(5).trimmingCharacters(in: .whitespaces).utf8)
                        guard let ereignis = try? JSONDecoder().decode(StreamEreignis.self, from: json) else { continue }
                        switch ereignis.t {
                        case "delta": fortsetzung.yield(ereignis.text ?? "")
                        case "fehler": throw KiFehler.unbekannt
                        default: break
                        }
                    }
                    fortsetzung.finish()
                } catch let kiFehler as KiFehler {
                    fortsetzung.finish(throwing: kiFehler)
                } catch is CancellationError {
                    fortsetzung.finish()
                } catch {
                    fortsetzung.finish(throwing: KiFehler.netz)
                }
            }
            fortsetzung.onTermination = { _ in aufgabe.cancel() }
        }
    }
}

// MARK: - Kontext aus App-Daten

/// Baut aus Essens-Store und Health-Daten (Schritte, Schlaf) das, was Coach und Bericht brauchen.
@MainActor
enum EssenKontext {
    static func profil(_ person: Person) -> KiProfil {
        let ziele = EssenStore.shared.ziele(person)
        return KiProfil(ziel: ziele.ziel, kcal: ziele.kcal, protein: ziele.protein)
    }

    static func tag(_ person: Person, tag: String) -> KiTag {
        let store = EssenStore.shared
        let mahlzeiten = store.liste(person, tag: tag)
        let summe = store.summe(person, tag: tag)
        let health = HealthModell.shared
        return KiTag(
            datum: tag,
            kcalGegessen: mahlzeiten.isEmpty ? nil : summe.kcal,
            protein: mahlzeiten.isEmpty ? nil : Int(summe.protein.rounded()),
            schritte: health.schritteAm(person, tag),
            schlafH: health.schlafNacht(person, tag).map { Double($0.minuten) / 60 },
            mahlzeiten: mahlzeiten.map { KiMahlzeit(name: $0.titel, kcal: $0.kcal) }
        )
    }

    /// Die letzten Tage vor `tag` (neuester zuletzt), ohne Tage ohne Eintrag.
    static func vortage(_ person: Person, vor tag: String, anzahl: Int = 6) -> [KiTag] {
        let heute = Datum.datum(tag)
        var ergebnis: [KiTag] = []
        for abstand in stride(from: anzahl, through: 1, by: -1) {
            guard let datum = Datum.kalender.date(byAdding: .day, value: -abstand, to: heute) else { continue }
            let eintrag = Self.tag(person, tag: Datum.text(datum))
            if eintrag.kcalGegessen != nil { ergebnis.append(eintrag) }
        }
        return ergebnis
    }
}
