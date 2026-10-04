import XCTest
@testable import Lovea

@MainActor
final class DatesOrtLinkTests: XCTestCase {
    private final class Gesendet { var ops: [Op] = [] }

    private func speicher(_ ziel: Gesendet = Gesendet()) -> DateSpeicher {
        let merker = UserDefaults(suiteName: "dates-ortlink-" + UUID().uuidString)!
        var zaehler = 0
        return DateSpeicher(
            ich: { .ahmed }, senden: { ziel.ops.append($0) },
            jetzt: { zaehler += 1; return Date(timeIntervalSince1970: 1_791_100_000 + Double(zaehler)) }, merker: merker
        )
    }

    private let wildpark = PunktOrt(name: "Wildpark", lat: 51.2, lon: 6.8, adresse: "Düsseldorf")
    private let cafe = PunktOrt(name: "Café Remise", lat: 51.3, lon: 6.9, adresse: nil)

    private func entwurf(titel: String = "Picknick", ort: PunktOrt? = nil, links: [DateLink] = []) -> DateIdeeBearbeitung.Entwurf {
        .init(titel: titel, kategorie: .draussen, erledigt: false, notiz: "", ort: ort, links: links)
    }

    // MARK: - Link-Aufnahme

    func testGueltigerLinkWirdAufgenommen() {
        guard case .neu(let link) = DateIdeeBearbeitung.linkAufnehmen("tiktok.com/@a/video/1", in: [], id: "l1") else {
            return XCTFail("kein neuer Link")
        }
        XCTAssertEqual(link.id, "l1")
        XCTAssertEqual(link.url, "https://tiktok.com/@a/video/1")
        XCTAssertEqual(DateLogik.linkArt(link.url), .tiktok)
    }

    func testGoogleMapsLinkIstKarte() {
        guard case .neu(let link) = DateIdeeBearbeitung.linkAufnehmen("https://www.google.com/maps/place/Wildpark", in: []) else {
            return XCTFail("kein neuer Link")
        }
        XCTAssertEqual(DateLogik.linkArt(link.url), .karte)
        XCTAssertEqual(DateIdeeBearbeitung.symbol(.karte), "map")
    }

    func testUngueltigeLinksWerdenAbgelehnt() {
        for text in ["", "   ", "kein link", "javascript:alert(1)", "ftp://example.com", "mailto:a@b.de", "example"] {
            XCTAssertEqual(DateIdeeBearbeitung.linkAufnehmen(text, in: []), .ungueltig, text)
        }
    }

    func testDoppelterLinkWirdAbgelehnt() {
        let vorhanden = [DateLink(id: "a", url: "https://example.com/seite", titel: nil)]
        for text in ["https://example.com/seite", "example.com/seite", "HTTPS://Example.com/seite/", " https://example.com/seite#x "] {
            XCTAssertEqual(DateIdeeBearbeitung.linkAufnehmen(text, in: vorhanden), .doppelt, text)
        }
        guard case .neu = DateIdeeBearbeitung.linkAufnehmen("https://example.com/andere", in: vorhanden) else {
            return XCTFail("anderer Pfad ist ein neuer Link")
        }
    }

    // MARK: - Ort setzen und entfernen

    func testNeueIdeeMitOrtUndLinksWirdGespeichert() throws {
        let s = speicher()
        let link = DateLink(id: "l", url: "https://example.com", titel: nil)
        DateIdeeBearbeitung.speichern(entwurf(ort: wildpark, links: [link]), idee: nil, in: s)
        let idee = try XCTUnwrap(s.ideen.first)
        XCTAssertEqual(idee.ort, wildpark)
        XCTAssertEqual(idee.links, [link])
    }

    func testOrtSetzenUndEntfernenPersistiert() throws {
        let ziel = Gesendet()
        let s = speicher(ziel)
        let angelegt = try XCTUnwrap(s.anlegen(titel: "Picknick", kategorie: .draussen))
        XCTAssertNil(angelegt.ort)

        DateIdeeBearbeitung.speichern(entwurf(ort: wildpark), idee: s.zustand.ideen[angelegt.id], in: s)
        XCTAssertEqual(s.zustand.ideen[angelegt.id]?.ort, wildpark)
        let nachSetzen = ziel.ops.count

        let gesendet = try XCTUnwrap(ziel.ops.last?.daten(DateIdee.self))
        XCTAssertEqual(gesendet.ort, wildpark)
        XCTAssertEqual(DateSpeicher.anwenden(ziel.ops).ideen[angelegt.id]?.ort, wildpark)

        DateIdeeBearbeitung.speichern(entwurf(ort: nil), idee: s.zustand.ideen[angelegt.id], in: s)
        XCTAssertNil(s.zustand.ideen[angelegt.id]?.ort)
        XCTAssertEqual(ziel.ops.count, nachSetzen + 1)
        XCTAssertNil(DateSpeicher.anwenden(ziel.ops).ideen[angelegt.id]?.ort)
    }

    func testUnveraendertesBlattSendetNichts() throws {
        let ziel = Gesendet()
        let s = speicher(ziel)
        let angelegt = try XCTUnwrap(s.anlegen(titel: "Picknick", kategorie: .draussen, ort: wildpark))
        let vorher = ziel.ops.count
        DateIdeeBearbeitung.speichern(entwurf(ort: wildpark), idee: s.zustand.ideen[angelegt.id], in: s)
        XCTAssertEqual(ziel.ops.count, vorher)
    }

    func testLinkLoeschenPersistiert() throws {
        let s = speicher()
        let a = DateLink(id: "a", url: "https://a.example.com", titel: nil)
        let b = DateLink(id: "b", url: "https://b.example.com", titel: nil)
        let angelegt = try XCTUnwrap(s.anlegen(titel: "Picknick", kategorie: .draussen, links: [a, b]))
        DateIdeeBearbeitung.speichern(entwurf(links: [b]), idee: s.zustand.ideen[angelegt.id], in: s)
        XCTAssertEqual(s.zustand.ideen[angelegt.id]?.links, [b])
    }

    // MARK: - Ort-Filter

    func testOrtFilterListetNamenUndWirkt() throws {
        let s = speicher()
        s.anlegen(titel: "Picknick", kategorie: .draussen, ort: wildpark)
        s.anlegen(titel: "Frühstück", kategorie: .essen, ort: cafe)
        s.anlegen(titel: "Kino", kategorie: .aktivitaet)

        XCTAssertEqual(DateLogik.ortNamen(s.ideen), ["Café Remise", "Wildpark"])

        var filter = DateFilter()
        filter.ort = "wildpark"
        XCTAssertEqual(DateLogik.filtern(s.ideen, filter).map(\.titel), ["Picknick"])
        filter.ort = "cafe remise"
        XCTAssertEqual(DateLogik.filtern(s.ideen, filter).map(\.titel), ["Frühstück"])
        filter.ort = nil
        XCTAssertEqual(DateLogik.filtern(s.ideen, filter).count, 3)
    }
}
