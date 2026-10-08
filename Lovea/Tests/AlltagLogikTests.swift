import XCTest
@testable import Lovea

/// p64: Plattenspieler, Wecker, Spiegel, Kühlschrank und Wärmflasche als reine Logik und im Speicher.
@MainActor
final class AlltagLogikTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_791_500_000)
    private let rick = "4cOdK2wGLETKBW3PvgPWqT"
    private let anderer = "7qiZfU4dY1lWllzX7mPBI3"

    private final class Ziel { var ops: [Op] = [] }

    private func op<T: Encodable>(_ art: String, _ d: T, von: Person, id: String, nach s: TimeInterval = 0) -> Op {
        Op(id: id, seq: nil, art: art, von: von, zeit: t0.addingTimeInterval(s), d: Op.neu(art, d, von: von).d)
    }

    private func platte(_ id: String, _ titel: String, von: Person = .ahmed, opId: String, nach s: TimeInterval = 0) -> Op {
        op(AlltagLogik.artPlatte, AlltagLogik.PlatteD(id: id, titel: titel, kuenstler: "K", cover: "https://c/x.jpg"), von: von, id: opId, nach: s)
    }

    private func zettel(_ id: String, _ text: String, erledigt: Bool? = nil, link: String? = nil, von: Person = .ahmed, opId: String, nach s: TimeInterval = 0) -> Op {
        op(AlltagLogik.artZettel, AlltagLogik.ZettelD(id: id, text: text, erledigt: erledigt, link: link, notiz: nil, bild: nil), von: von, id: opId, nach: s)
    }

    // MARK: - Allgemein

    func testOpArtenSindEigeneUndStossenNichtAnDieSignale() {
        XCTAssertEqual(AlltagLogik.arten, ["platte.setzen", "wecker.setzen", "spiegel.setzen", "kuehl.setzen", "kuehl.weg", "waerme.setzen"])
        XCTAssertTrue(AlltagLogik.arten.isDisjoint(with: SignaleLogik.arten))
    }

    // MARK: - Plattenspieler

    func testNeuesterSongGewinntVonBeidenReihenfolgeEgalUndIdempotent() {
        let a = platte(rick, "Erster", opId: "o1")
        let b = platte(anderer, "Zweiter", von: .annika, opId: "o2", nach: 60)
        let stand = AlltagLogik.anwenden([b, a, b, a])
        XCTAssertEqual(stand.platte?.titel, "Zweiter")
        XCTAssertEqual(stand.platte?.von, .annika)
        XCTAssertEqual(stand, AlltagLogik.anwenden([a, b]))
    }

    func testPlatteMitUngueltigerIdUndKaputteDatenWirdIgnoriert() {
        let gut = platte(rick, "Gut", opId: "o1")
        let kurz = platte("abc", "Kurz", opId: "o2", nach: 10)
        let boese = platte("../../evil/zzzzzzzzzzzzzz", "Böse", opId: "o3", nach: 20)
        let kaputt = Op(id: "o4", seq: nil, art: AlltagLogik.artPlatte, von: .ahmed, zeit: t0.addingTimeInterval(30), d: Data("[]".utf8))
        XCTAssertEqual(AlltagLogik.anwenden([gut, kurz, boese, kaputt]).platte?.titel, "Gut")
    }

    func testSpotifyLinkWirdAusDerIdGebaut() {
        let stand = AlltagLogik.anwenden([platte(rick, "T", opId: "o1")])
        XCTAssertEqual(stand.platte?.link?.absoluteString, "https://open.spotify.com/track/" + rick)
    }

    func testSpotifyIdAusLinksTextUndUri() {
        XCTAssertEqual(AlltagLogik.spotifyId(in: "https://open.spotify.com/track/\(rick)"), rick)
        XCTAssertEqual(AlltagLogik.spotifyId(in: "https://open.spotify.com/track/\(rick)?si=abc123def"), rick)
        XCTAssertEqual(AlltagLogik.spotifyId(in: "https://open.spotify.com/intl-de/track/\(rick)?si=x"), rick)
        XCTAssertEqual(AlltagLogik.spotifyId(in: "Hör mal rein 🎵 https://open.spotify.com/track/\(rick)?si=x und küss mich"), rick)
        XCTAssertEqual(AlltagLogik.spotifyId(in: "spotify:track:\(rick)"), rick)
        XCTAssertEqual(AlltagLogik.spotifyId(in: "  HTTPS://OPEN.SPOTIFY.COM/track/\(rick)  "), rick)
    }

    func testSpotifyIdLehntAlbenListenFremdesUndZuKurzesAb() {
        XCTAssertNil(AlltagLogik.spotifyId(in: "https://open.spotify.com/album/\(rick)"))
        XCTAssertNil(AlltagLogik.spotifyId(in: "https://open.spotify.com/playlist/\(rick)"))
        XCTAssertNil(AlltagLogik.spotifyId(in: "https://example.com/track/\(rick)"))
        XCTAssertNil(AlltagLogik.spotifyId(in: "https://open.spotify.com/track/abc"))
        XCTAssertNil(AlltagLogik.spotifyId(in: "https://open.spotify.com/track/" + String(rick.dropLast())), "21 Zeichen")
        XCTAssertNil(AlltagLogik.spotifyId(in: "https://open.spotify.com/track/" + rick + "x"), "23 Zeichen")
        XCTAssertNil(AlltagLogik.spotifyId(in: ""))
    }

    func testOembedLiefertTitelUndNurHttpsCover() {
        let gut = Data(#"{"title":"Never Gonna Give You Up","thumbnail_url":"https://image.example/c.jpg","type":"rich"}"#.utf8)
        XCTAssertEqual(AlltagLogik.oembed(gut)?.titel, "Never Gonna Give You Up")
        XCTAssertEqual(AlltagLogik.oembed(gut)?.cover, "https://image.example/c.jpg")
        let unsicher = Data(#"{"title":"T","thumbnail_url":"http://image.example/c.jpg"}"#.utf8)
        XCTAssertEqual(AlltagLogik.oembed(unsicher)?.titel, "T")
        XCTAssertNil(AlltagLogik.oembed(unsicher)?.cover)
        XCTAssertNil(AlltagLogik.oembed(Data(#"{"title":"  "}"#.utf8)))
        XCTAssertNil(AlltagLogik.oembed(Data("kein json".utf8)))
    }

    func testKuenstlerKommtAusOgDescription() {
        let kopf = #"<head><meta property="og:title" content="Song"/><meta property="og:description" content="Rick Astley · Whenever You Need Somebody · Song · 1987"/></head>"#
        XCTAssertEqual(AlltagLogik.kuenstler(ausKopf: kopf), "Rick Astley")
        let entities = #"<meta property="og:description" content="Simon &amp; Garfunkel · Bookends · Song · 1968"/>"#
        XCTAssertEqual(AlltagLogik.kuenstler(ausKopf: entities), "Simon & Garfunkel")
        XCTAssertNil(AlltagLogik.kuenstler(ausKopf: "<head><title>x</title>"))
        XCTAssertNil(AlltagLogik.kuenstler(ausKopf: #"<meta property="og:description" content=""/>"#))
    }

    // MARK: - Wecker

    private func wecker(_ min: Int?, an: Bool = true, von: Person, opId: String, nach s: TimeInterval = 0) -> Op {
        op(AlltagLogik.artWecker, AlltagLogik.WeckerD(min: min, an: an), von: von, id: opId, nach: s)
    }

    func testWeckzeitWirdAlsUhrzeitGezeigtUndNurWennAn() {
        let stand = AlltagLogik.anwenden([wecker(6 * 60 + 5, von: .ahmed, opId: "o1"), wecker(7 * 60, an: false, von: .annika, opId: "o2")])
        XCTAssertEqual(AlltagLogik.weckzeit(stand.wecker[.ahmed]), "6:05")
        XCTAssertNil(AlltagLogik.weckzeit(stand.wecker[.annika]), "Wecker aus: keine Zeit")
        XCTAssertNil(AlltagLogik.weckzeit(nil))
        XCTAssertEqual(AlltagLogik.weckzeit(AlltagLogik.anwenden([wecker(0, von: .ahmed, opId: "o3")]).wecker[.ahmed]), "0:00")
    }

    func testWeckerNeuesterJePersonUndUnsinnigeMinutenFallenWeg() {
        let a = wecker(360, von: .ahmed, opId: "o1")
        let b = wecker(400, von: .ahmed, opId: "o2", nach: 5)
        XCTAssertEqual(AlltagLogik.anwenden([b, a]).wecker[.ahmed]?.minuten, 400)
        XCTAssertNil(AlltagLogik.anwenden([wecker(5000, von: .ahmed, opId: "o3")]).wecker[.ahmed]?.minuten)
        XCTAssertNil(AlltagLogik.anwenden([wecker(-1, von: .ahmed, opId: "o4")]).wecker[.ahmed]?.minuten)
    }

    func testWerZuerstAufstehtUndDerSatzDazu() {
        var stand = AlltagLogik.anwenden([wecker(6 * 60 + 30, von: .ahmed, opId: "o1")])
        XCTAssertNil(AlltagLogik.fruehAufsteher(stand.wecker), "erst wenn beide gestellt haben")
        XCTAssertEqual(AlltagLogik.aufstehSatz(ich: .ahmed, stand.wecker), "Noch nicht beide Wecker gestellt")
        stand = AlltagLogik.anwenden([wecker(7 * 60, von: .annika, opId: "o2")], auf: stand)
        XCTAssertEqual(AlltagLogik.fruehAufsteher(stand.wecker), .ahmed)
        XCTAssertEqual(AlltagLogik.aufstehSatz(ich: .ahmed, stand.wecker), "Du stehst zuerst auf")
        XCTAssertEqual(AlltagLogik.aufstehSatz(ich: .annika, stand.wecker), "Ahmed steht zuerst auf")
        stand = AlltagLogik.anwenden([wecker(6 * 60, von: .annika, opId: "o3", nach: 10)], auf: stand)
        XCTAssertEqual(AlltagLogik.fruehAufsteher(stand.wecker), .annika)
        stand = AlltagLogik.anwenden([wecker(6 * 60 + 30, von: .annika, opId: "o4", nach: 20)], auf: stand)
        XCTAssertNil(AlltagLogik.fruehAufsteher(stand.wecker))
        XCTAssertEqual(AlltagLogik.aufstehSatz(ich: .ahmed, stand.wecker), "Ihr steht zur gleichen Zeit auf")
        stand = AlltagLogik.anwenden([wecker(nil, an: false, von: .annika, opId: "o5", nach: 30)], auf: stand)
        XCTAssertEqual(AlltagLogik.aufstehSatz(ich: .ahmed, stand.wecker), "Noch nicht beide Wecker gestellt")
    }

    // MARK: - Spiegel

    private func spiegel(_ medium: String?, tag: String, von: Person, opId: String, nach s: TimeInterval = 0) -> Op {
        op(AlltagLogik.artSpiegel, AlltagLogik.SpiegelD(medium: medium, tag: tag), von: von, id: opId, nach: s)
    }

    func testOutfitHaengtNurAnSeinemTag() {
        let stand = AlltagLogik.anwenden([spiegel("m1", tag: "2026-10-08", von: .annika, opId: "o1")])
        XCTAssertEqual(AlltagLogik.outfit(stand, von: .annika, heute: "2026-10-08"), "m1")
        XCTAssertNil(AlltagLogik.outfit(stand, von: .annika, heute: "2026-10-09"), "am nächsten Tag ist es abgehängt")
        XCTAssertNil(AlltagLogik.outfit(stand, von: .ahmed, heute: "2026-10-08"), "jede Person hat ihr eigenes")
    }

    func testOutfitNeuesGewinntUndNilNimmtEsAb() {
        let a = spiegel("m1", tag: "2026-10-08", von: .annika, opId: "o1")
        let b = spiegel("m2", tag: "2026-10-08", von: .annika, opId: "o2", nach: 30)
        let ab = spiegel(nil, tag: "2026-10-08", von: .annika, opId: "o3", nach: 60)
        XCTAssertEqual(AlltagLogik.outfit(AlltagLogik.anwenden([b, a]), von: .annika, heute: "2026-10-08"), "m2")
        XCTAssertNil(AlltagLogik.outfit(AlltagLogik.anwenden([ab, b, a]), von: .annika, heute: "2026-10-08"))
    }

    // MARK: - Kühlschrank

    func testZettelFaltenAbhakenLoeschenMitGrabsteinFuerBeide() {
        let milch = zettel("z1", "Milch", opId: "o1")
        let brot = zettel("z2", "Brot", von: .annika, opId: "o2", nach: 10)
        let haken = zettel("z1", "Milch", erledigt: true, von: .annika, opId: "o3", nach: 20)
        var stand = AlltagLogik.anwenden([brot, haken, milch, milch])
        XCTAssertEqual(AlltagLogik.zettelListe(stand).map(\.text), ["Brot", "Milch"], "offene zuerst, erledigte unten")
        XCTAssertEqual(AlltagLogik.zettelListe(stand).map(\.erledigt), [false, true])
        XCTAssertEqual(AlltagLogik.offene(stand), 1)

        let weg = op(AlltagLogik.artZettelWeg, AlltagLogik.ZettelWegD(id: "z2"), von: .ahmed, id: "o4", nach: 30)
        stand = AlltagLogik.anwenden([weg], auf: stand)
        XCTAssertEqual(AlltagLogik.zettelListe(stand).map(\.id), ["z1"])
        stand = AlltagLogik.anwenden([brot], auf: stand)
        XCTAssertEqual(AlltagLogik.zettelListe(stand).map(\.id), ["z1"], "eine spät eintreffende ältere Op holt nichts zurück")
        XCTAssertEqual(AlltagLogik.anwenden([weg, brot, haken, milch]), stand, "Löschen zuerst, gleiches Ergebnis")
    }

    func testZettelBehaeltLinkNotizUndBild() {
        let d = AlltagLogik.ZettelD(id: "z1", text: "Pasta", erledigt: nil, link: "https://www.tiktok.com/@koch/video/123", notiz: "Mit Zitrone", bild: "bild-1")
        let stand = AlltagLogik.anwenden([op(AlltagLogik.artZettel, d, von: .ahmed, id: "o1")])
        let z = stand.zettel["z1"]
        XCTAssertEqual(z?.link, "https://www.tiktok.com/@koch/video/123")
        XCTAssertEqual(z?.notiz, "Mit Zitrone")
        XCTAssertEqual(z?.bild, "bild-1")
        XCTAssertEqual(z?.erledigt, false)
    }

    func testNurTikTokUndInstagramHttpsLinksGelten() {
        XCTAssertEqual(AlltagLogik.zettelLink("https://www.tiktok.com/@x/video/1"), "https://www.tiktok.com/@x/video/1")
        XCTAssertEqual(AlltagLogik.zettelLink("https://vm.tiktok.com/ZMabc/"), "https://vm.tiktok.com/ZMabc/")
        XCTAssertEqual(AlltagLogik.zettelLink("Schau https://www.instagram.com/reel/Cabc/?igsh=1 an"), "https://www.instagram.com/reel/Cabc/?igsh=1")
        XCTAssertEqual(AlltagLogik.zettelLink("https://instagr.am/p/abc"), "https://instagr.am/p/abc")
        XCTAssertNil(AlltagLogik.zettelLink("http://www.tiktok.com/@x/video/1"), "kein http")
        XCTAssertNil(AlltagLogik.zettelLink("https://evil.com/tiktok.com"))
        XCTAssertNil(AlltagLogik.zettelLink("https://tiktok.com.evil.com/x"))
        XCTAssertNil(AlltagLogik.zettelLink("https://nottiktok.com/x"))
        XCTAssertNil(AlltagLogik.zettelLink("javascript:alert(1)"))
        XCTAssertNil(AlltagLogik.zettelLink(""))
    }

    func testFremderLinkInEinerOpWirdBeimFaltenGestrichen() {
        let d = AlltagLogik.ZettelD(id: "z1", text: "Pasta", erledigt: nil, link: "https://evil.com/x", notiz: nil, bild: nil)
        let stand = AlltagLogik.anwenden([op(AlltagLogik.artZettel, d, von: .annika, id: "o1")])
        XCTAssertNil(stand.zettel["z1"]?.link)
        XCTAssertEqual(stand.zettel["z1"]?.text, "Pasta")
    }

    // MARK: - Wärmflasche und Tee

    private let heute = "2026-10-08"

    private func tag(_ id: String, _ blutung: Blutung? = nil, _ symptome: Set<Symptom> = []) -> ZyklusTag {
        ZyklusTag(id: id, blutung: blutung, symptome: symptome)
    }

    func testSchwererTagBeiStarkerBlutungOderKraempfen() {
        XCTAssertTrue(AlltagLogik.schwererTag(tage: [tag(heute, .stark)], einstellung: ZyklusEinstellung(), heute: heute))
        XCTAssertTrue(AlltagLogik.schwererTag(tage: [tag(heute, nil, [.kraempfe])], einstellung: ZyklusEinstellung(), heute: heute))
        XCTAssertFalse(AlltagLogik.schwererTag(tage: [tag(heute, nil, [.kopfschmerzen])], einstellung: ZyklusEinstellung(), heute: heute))
        XCTAssertFalse(AlltagLogik.schwererTag(tage: [tag("2026-10-01", .stark)], einstellung: ZyklusEinstellung(), heute: heute), "vor einer Woche zählt nicht")
        XCTAssertFalse(AlltagLogik.schwererTag(tage: [], einstellung: ZyklusEinstellung(), heute: heute))
    }

    func testSchwererTagAmErstenBisDrittenPeriodentag() {
        let tage = [tag("2026-10-06", .leicht), tag("2026-10-07", .mittel), tag("2026-10-08", .leicht)]
        XCTAssertTrue(AlltagLogik.schwererTag(tage: tage, einstellung: ZyklusEinstellung(), heute: "2026-10-06"))
        XCTAssertTrue(AlltagLogik.schwererTag(tage: tage, einstellung: ZyklusEinstellung(), heute: "2026-10-08"), "dritter Tag")
        XCTAssertFalse(AlltagLogik.schwererTag(tage: tage, einstellung: ZyklusEinstellung(), heute: "2026-10-09"), "vierter Tag")
        XCTAssertFalse(AlltagLogik.schwererTag(tage: tage, einstellung: ZyklusEinstellung(), heute: "2026-10-20"), "Mitte des Zyklus")
    }

    func testWaermeSendetNurBeiAenderungUndNieOhneBisherUndAus() {
        let heutigeAn = WaermeEintrag(tag: heute, an: true, zeit: t0, opId: "o")
        XCTAssertEqual(AlltagLogik.waermeSenden(soll: true, heute: heute, bisher: nil), true)
        XCTAssertNil(AlltagLogik.waermeSenden(soll: true, heute: heute, bisher: heutigeAn), "schon gesendet")
        XCTAssertEqual(AlltagLogik.waermeSenden(soll: false, heute: heute, bisher: heutigeAn), false, "Schalter aus: zurücknehmen")
        XCTAssertNil(AlltagLogik.waermeSenden(soll: false, heute: heute, bisher: nil), "ausgeschaltet und nie gesendet: nichts")
        let gestern = WaermeEintrag(tag: "2026-10-07", an: true, zeit: t0, opId: "o")
        XCTAssertNil(AlltagLogik.waermeSenden(soll: false, heute: heute, bisher: gestern), "gestern ist schon vorbei")
        XCTAssertEqual(AlltagLogik.waermeSenden(soll: true, heute: heute, bisher: gestern), true)
    }

    func testWaermeAktivNurHeuteUndNurWennAn() {
        let an = op(AlltagLogik.artWaerme, AlltagLogik.WaermeD(tag: heute, an: true), von: .annika, id: "o1")
        let aus = op(AlltagLogik.artWaerme, AlltagLogik.WaermeD(tag: heute, an: false), von: .annika, id: "o2", nach: 10)
        XCTAssertTrue(AlltagLogik.waermeAktiv(AlltagLogik.anwenden([an]), von: .annika, heute: heute))
        XCTAssertFalse(AlltagLogik.waermeAktiv(AlltagLogik.anwenden([an]), von: .annika, heute: "2026-10-09"))
        XCTAssertFalse(AlltagLogik.waermeAktiv(AlltagLogik.anwenden([an]), von: .ahmed, heute: heute))
        XCTAssertFalse(AlltagLogik.waermeAktiv(AlltagLogik.anwenden([aus, an]), von: .annika, heute: heute))
    }

    func testWaermeOpEnthaeltKeinWortAusDemZyklus() throws {
        let o = Op.neu(AlltagLogik.artWaerme, AlltagLogik.WaermeD(tag: heute, an: true), von: .annika)
        let text = try XCTUnwrap(String(data: o.d, encoding: .utf8))
        XCTAssertEqual(Set(try XCTUnwrap(JSONSerialization.jsonObject(with: o.d) as? [String: Any]).keys), ["tag", "an"], text)
    }

    // MARK: - Speicher

    func testSpeicherPlatteWeckerOutfitSendenJeEineOpUndFaltenSofort() {
        let ziel = Ziel()
        let s = AlltagSpeicher(ich: { .annika }, senden: { ziel.ops.append($0) })
        s.platteSetzen(SpotifyAbfrage.Titel(id: rick, titel: "Song", kuenstler: "Band", cover: nil))
        s.weckerSetzen(minuten: 7 * 60, an: true)
        s.outfitHaengen(medium: "m1", heute: heute)
        XCTAssertEqual(s.stand.platte?.titel, "Song")
        XCTAssertEqual(AlltagLogik.weckzeit(s.stand.wecker[.annika]), "7:00")
        XCTAssertEqual(AlltagLogik.outfit(s.stand, von: .annika, heute: heute), "m1")
        XCTAssertEqual(ziel.ops.map(\.art), [AlltagLogik.artPlatte, AlltagLogik.artWecker, AlltagLogik.artSpiegel])
        XCTAssertTrue(ziel.ops.allSatisfy { $0.von == .annika })
    }

    func testSpeicherOhneIchSendetNichts() {
        let ziel = Ziel()
        let s = AlltagSpeicher(ich: { nil }, senden: { ziel.ops.append($0) })
        s.platteSetzen(SpotifyAbfrage.Titel(id: rick, titel: "Song", kuenstler: nil, cover: nil))
        s.weckerSetzen(minuten: 400, an: true)
        s.outfitHaengen(medium: "m", heute: heute)
        s.waermeAbgleichen(soll: true, heute: heute)
        XCTAssertFalse(s.zettelNeu("Milch"))
        XCTAssertTrue(ziel.ops.isEmpty)
    }

    func testSpeicherZettelNeuAbhakenLoeschen() throws {
        let ziel = Ziel()
        let s = AlltagSpeicher(ich: { .ahmed }, senden: { ziel.ops.append($0) })
        XCTAssertFalse(s.zettelNeu("   "), "leer wird nicht angeheftet")
        XCTAssertTrue(s.zettelNeu(" Milch ", link: "https://evil.com/x", notiz: "  ", bild: nil))
        let z = try XCTUnwrap(s.zettel.first)
        XCTAssertEqual(z.text, "Milch")
        XCTAssertNil(z.link, "fremder Link wird nicht angeheftet")
        XCTAssertNil(z.notiz, "leere Notiz ist keine")
        s.zettelAbhaken(z)
        let erledigt = try XCTUnwrap(s.zettel.first)
        XCTAssertTrue(erledigt.erledigt)
        s.zettelAbhaken(erledigt)
        XCTAssertFalse(try XCTUnwrap(s.zettel.first).erledigt)
        s.zettelLoeschen(z)
        XCTAssertTrue(s.zettel.isEmpty)
        XCTAssertEqual(ziel.ops.map(\.art), [AlltagLogik.artZettel, AlltagLogik.artZettel, AlltagLogik.artZettel, AlltagLogik.artZettelWeg])
    }

    func testSpeicherZettelMitLinkNotizUndBildUndKuerzung() throws {
        let s = AlltagSpeicher(ich: { .annika }, senden: { _ in })
        XCTAssertTrue(s.zettelNeu(String(repeating: "a", count: 300), link: "https://www.instagram.com/reel/Cabc/", notiz: String(repeating: "n", count: 500), bild: "bild-9"))
        let z = try XCTUnwrap(s.zettel.first)
        XCTAssertEqual(z.text.count, AlltagLogik.zettelMaxZeichen)
        XCTAssertEqual(z.notiz?.count, AlltagLogik.notizMaxZeichen)
        XCTAssertEqual(z.link, "https://www.instagram.com/reel/Cabc/")
        XCTAssertEqual(z.bild, "bild-9")
    }

    func testBeideHakenDenselbenZettelAbMitSpeicherAufZweiGeraeten() throws {
        let a = AlltagSpeicher(ich: { .ahmed }, senden: { _ in })
        let b = AlltagSpeicher(ich: { .annika }, senden: { _ in })
        let ziel = Ziel()
        let sender = AlltagSpeicher(ich: { .ahmed }, senden: { ziel.ops.append($0) })
        sender.zettelNeu("Eier")
        a.einarbeiten(ziel.ops)
        b.einarbeiten(ziel.ops)
        b.zettelAbhaken(try XCTUnwrap(b.zettel.first))
        XCTAssertTrue(try XCTUnwrap(b.zettel.first).erledigt)
        XCTAssertFalse(try XCTUnwrap(a.zettel.first).erledigt, "noch nicht angekommen")
    }

    func testSpeicherWaermeSendetEinmalProTagUndNimmtZurueck() {
        let ziel = Ziel()
        let s = AlltagSpeicher(ich: { .annika }, senden: { ziel.ops.append($0) })
        s.waermeAbgleichen(soll: false, heute: heute)
        XCTAssertTrue(ziel.ops.isEmpty, "Freigabe aus: nichts geht raus")
        s.waermeAbgleichen(soll: true, heute: heute)
        s.waermeAbgleichen(soll: true, heute: heute)
        XCTAssertEqual(ziel.ops.count, 1)
        XCTAssertTrue(AlltagLogik.waermeAktiv(s.stand, von: .annika, heute: heute))
        s.waermeAbgleichen(soll: false, heute: heute)
        XCTAssertEqual(ziel.ops.count, 2)
        XCTAssertFalse(AlltagLogik.waermeAktiv(s.stand, von: .annika, heute: heute))
    }

    func testSpeicherNimmtDieWaermeDerAnderenPersonAnOhneSelbstZuSenden() {
        let ziel = Ziel()
        let s = AlltagSpeicher(ich: { .ahmed }, senden: { ziel.ops.append($0) })
        s.einarbeiten([op(AlltagLogik.artWaerme, AlltagLogik.WaermeD(tag: heute, an: true), von: .annika, id: "o1")])
        XCTAssertTrue(AlltagLogik.waermeAktiv(s.stand, von: .annika, heute: heute))
        XCTAssertTrue(ziel.ops.isEmpty)
    }

    func testWaermePruefenOhneFreigabeSendetNichts() {
        UserDefaults.standard.removeObject(forKey: ZyklusSchalter.waerme)
        let ziel = Ziel()
        let s = AlltagSpeicher(ich: { .annika }, senden: { ziel.ops.append($0) })
        s.waermePruefen(heute: heute)
        XCTAssertTrue(ziel.ops.isEmpty)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: ZyklusSchalter.waerme), "Standard ist aus")
    }
}
