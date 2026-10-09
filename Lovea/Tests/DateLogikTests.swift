import XCTest
@testable import Lovea

final class DateLogikTests: XCTestCase {
    private let alle = DateStartdaten.ideen

    // MARK: - Startdaten

    func testStartdatenVollstaendig() {
        XCTAssertEqual(alle.count, 61) // 60 Ideen der Notiz plus der erledigte Nordpark
        XCTAssertEqual(Set(alle.map(\.id)).count, alle.count)
        for kategorie in DateKategorie.allCases {
            XCTAssertFalse(alle.filter { $0.kategorie == kategorie }.isEmpty, "\(kategorie) ohne Idee")
        }
        for titel in ["Autodate", "Acai Bowls", "Zeichnen", "Zoo", "Ungewöhnliche Dates", "Sonnenuntergang oder Sonnenaufgang anschauen", "Ikea", "Quiz"] {
            XCTAssertNotNil(alle.first { $0.titel == titel }, titel)
        }
    }

    func testNurNordparkIstErledigt() {
        let erledigt = alle.filter(\.erledigt)
        XCTAssertEqual(erledigt.map(\.id), ["start-nordpark-japanischer-garten"])
        XCTAssertEqual(erledigt.first?.ort?.name, "Nordpark Düsseldorf")
    }

    func testOrteZugeordnet() {
        let orte = Dictionary(uniqueKeysWithValues: alle.compactMap { i in i.ort.map { (i.titel, $0.name) } })
        XCTAssertEqual(orte["Tierpark"], "Wildpark Düsseldorf")
        XCTAssertEqual(orte["Frühstücken zusammen"], "Café Classic Remise")
        XCTAssertEqual(orte["Reisen"], "Eiffelturm bei Nacht")
        XCTAssertEqual(orte["Ungewöhnliche Dates"], "7th Space Köln")
        XCTAssertEqual(orte.count, 5)
        XCTAssertEqual(alle.first { $0.titel == "Ungewöhnliche Dates" }?.kategorie, .besonders)
        let eiffel = alle.first { $0.titel == "Reisen" }?.ort
        XCTAssertTrue(eiffel.map(DateLogik.hatKoordinate) ?? false)
        XCTAssertFalse(alle.first { $0.titel == "Tierpark" }?.ort.map(DateLogik.hatKoordinate) ?? true)
    }

    func testIDsStabilUndAusTitel() {
        XCTAssertEqual(DateStartdaten.id("Frühstücken zusammen"), "start-fruehstuecken-zusammen")
        XCTAssertEqual(alle.map(\.id), DateStartdaten.ideen.map(\.id))
        for idee in alle { XCTAssertEqual(idee.id, "start-" + DateLogik.slug(idee.titel)) }
        XCTAssertEqual(Set(alle.map(\.geaendert)), [DateStartdaten.stempel])
    }

    func testSlug() {
        XCTAssertEqual(DateLogik.slug("Nordpark / Japanischer Garten"), "nordpark-japanischer-garten")
        XCTAssertEqual(DateLogik.slug("Autoreise übers Wochenende"), "autoreise-uebers-wochenende")
        XCTAssertEqual(DateLogik.slug("Leinwände bemalen"), "leinwaende-bemalen")
        XCTAssertEqual(DateLogik.slug("Late-Night Drive"), "late-night-drive")
    }

    // MARK: - Filter, Sortierung, Fortschritt, Suche

    func testFilterKategorieUndStatus() {
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(kategorie: .draussen, status: .erledigt)).map(\.titel), ["Nordpark / Japanischer Garten"])
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(status: .offen)).count, 60)
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(status: .erledigt)).count, 1)
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(kategorie: .reisen)).count, 3)
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(kategorie: .reisen, status: .erledigt)).count, 0)
    }

    func testFilterOrtOhneGrossKleinUndAkzent() {
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(ort: "wildpark düsseldorf")).map(\.titel), ["Tierpark"])
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(ort: "CAFE CLASSIC REMISE")).map(\.titel), ["Frühstücken zusammen"])
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(ort: "Nirgendwo")).count, 0)
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(kategorie: .draussen, status: .offen, ort: "Nordpark Düsseldorf")).count, 0)
    }

    func testFilterKombinationMitSuche() {
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(kategorie: .essen, status: .offen, suche: "eis")).map(\.titel), ["Eis essen"])
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(suche: "zusammen")).count, 4)
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(status: .erledigt, suche: "zusammen")).count, 0)
    }

    func testSucheTitelNotizOrtLink() {
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(suche: "FRUHSTUCKEN")).map(\.titel), ["Frühstücken zusammen"])
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(suche: "einrichtung")).map(\.titel), ["Ikea"])
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(suche: "classic remise")).map(\.titel), ["Frühstücken zusammen"])
        var mitLink = alle[0]
        mitLink.links = [DateLink(id: "l", url: "https://www.tiktok.com/@x/video/1", titel: nil)]
        XCTAssertEqual(DateLogik.filtern([mitLink], DateFilter(suche: "tiktok")).count, 1)
        XCTAssertEqual(DateLogik.filtern(alle, DateFilter(suche: "   ")).count, 61)
    }

    func testGeloeschteBleibenDraussen() {
        var liste = alle
        liste[0].geloescht = true
        XCTAssertEqual(DateLogik.filtern(liste).count, 60)
        XCTAssertEqual(DateLogik.fortschritt(liste).gesamt, 60)
        XCTAssertFalse(DateLogik.ortNamen(liste).isEmpty)
    }

    func testSortierungOffenZuerstErledigteUnten() {
        let sortiert = DateLogik.filtern(alle)
        XCTAssertEqual(sortiert.first?.titel, "Abendspaziergang")
        XCTAssertEqual(sortiert.last?.id, "start-nordpark-japanischer-garten")
        var a = alle[0], b = alle[1], c = alle[2]
        a.erledigt = true; a.erledigtAm = "2026-10-01"
        b.erledigt = true; b.erledigtAm = "2026-10-03"
        c.erledigt = true; c.erledigtAm = nil
        XCTAssertEqual(DateLogik.sortiert([c, a, b]).map(\.id), [b.id, a.id, c.id])
    }

    func testFortschritt() {
        let f = DateLogik.fortschritt(alle)
        XCTAssertEqual(f.erledigt, 1)
        XCTAssertEqual(f.gesamt, 61)
        XCTAssertEqual(f.anteil, 1.0 / 61.0, accuracy: 0.0001)
        XCTAssertEqual(DateLogik.fortschritt([]).anteil, 0)
    }

    func testOrtNamenEinmalUndSortiert() {
        let namen = DateLogik.ortNamen(alle)
        XCTAssertEqual(namen.count, 5)
        XCTAssertEqual(namen.first, "7th Space Köln")
    }

    // MARK: - Links

    func testLinkNurHttpUndHttps() {
        for ok in ["https://maps.app.goo.gl/abc123", "http://example.com/x", "HTTPS://Example.com", "example.com/seite", "  www.instagram.com/p/1  "] {
            XCTAssertNotNil(DateLogik.normalisiert(ok), ok)
        }
        for schlecht in ["javascript:alert(1)", "JavaScript:alert(1)", "ftp://example.com", "file:///etc/passwd", "mailto:a@b.de", "tel:123",
                         "data:text/html,x", "just text", "", "   ", "https://", "foo", "http://localhost", "myapp://open"] {
            XCTAssertNil(DateLogik.normalisiert(schlecht), schlecht)
            XCTAssertNil(DateLogik.link(aus: schlecht), schlecht)
        }
    }

    func testLinkErgaenztSchemaUndTitel() {
        let link = DateLogik.link(aus: " example.com/x ", titel: "  Kaffee  ", id: "l1")
        XCTAssertEqual(link?.url, "https://example.com/x")
        XCTAssertEqual(link?.titel, "Kaffee")
        XCTAssertNil(DateLogik.link(aus: "example.com", titel: "  ")?.titel)
    }

    func testDomainUndChip() {
        XCTAssertEqual(DateLogik.domain("https://www.instagram.com/p/1"), "instagram.com")
        XCTAssertEqual(DateLogik.domain("https://m.youtube.com/watch?v=1"), "youtube.com")
        XCTAssertEqual(DateLogik.domain("https://maps.app.goo.gl/abc"), "maps.app.goo.gl")
        XCTAssertNil(DateLogik.domain("javascript:alert(1)"))
        XCTAssertEqual(DateLogik.chipText(DateLink(id: "1", url: "https://www.tiktok.com/@x", titel: nil)), "tiktok.com")
        XCTAssertEqual(DateLogik.chipText(DateLink(id: "1", url: "https://www.tiktok.com/@x", titel: "Video")), "Video")
    }

    func testLinkArtErkennung() {
        XCTAssertEqual(DateLogik.linkArt("https://maps.app.goo.gl/abc123"), .karte)
        XCTAssertEqual(DateLogik.linkArt("https://www.google.com/maps/place/Eiffelturm"), .karte)
        XCTAssertEqual(DateLogik.linkArt("https://www.google.de/maps?q=x"), .karte)
        XCTAssertEqual(DateLogik.linkArt("google.com/maps"), .karte)
        XCTAssertEqual(DateLogik.linkArt("https://www.google.com/search?q=x"), .andere)
        XCTAssertEqual(DateLogik.linkArt("https://vm.tiktok.com/ZM123/"), .tiktok)
        XCTAssertEqual(DateLogik.linkArt("https://www.tiktok.com/@x/video/1"), .tiktok)
        XCTAssertEqual(DateLogik.linkArt("https://www.instagram.com/p/abc/"), .instagram)
        XCTAssertEqual(DateLogik.linkArt("https://nottiktok.com/x"), .andere)
        XCTAssertEqual(DateLogik.linkArt("https://example.com/tiktok.com"), .andere)
        XCTAssertEqual(DateLogik.linkArt("javascript:alert(1)"), .andere)
    }

    func testOeffnenPrueftErneut() {
        XCTAssertNil(DateLogik.oeffnenURL(DateLink(id: "1", url: "javascript:alert(1)", titel: nil)))
        XCTAssertEqual(DateLogik.oeffnenURL(DateLink(id: "1", url: "https://example.com", titel: nil))?.host, "example.com")
    }
}
