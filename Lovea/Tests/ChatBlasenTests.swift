import XCTest
@testable import Lovea

/// Z-32.4/Z-33.1: bubble grouping, emoji-only detection and where the long-press bar and menu go.
@MainActor
final class ChatBlasenTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func text(_ id: String, _ von: Person, nach sekunden: TimeInterval) -> ChatModell.Nachricht {
        ChatModell.Nachricht(id: id, von: von, zeit: t0.addingTimeInterval(sekunden), text: "hi")
    }

    func testGruppeGleicherAbsenderInnerhalbVon5Minuten() {
        XCTAssertTrue(BlasenGruppe.zusammen(text("a", .ahmed, nach: 0), text("b", .ahmed, nach: 299)))
        XCTAssertFalse(BlasenGruppe.zusammen(text("a", .ahmed, nach: 0), text("b", .ahmed, nach: 301)))
        XCTAssertFalse(BlasenGruppe.zusammen(text("a", .ahmed, nach: 0), text("b", .annika, nach: 10)))
        var weg = text("c", .ahmed, nach: 20)
        weg.geloescht = true
        XCTAssertFalse(BlasenGruppe.zusammen(text("a", .ahmed, nach: 0), weg), "a caption breaks the group")
    }

    func testLesekopfSitztUnterDerZuletztGelesenenEigenen() {
        let liste = [text("a", .ahmed, nach: 0), text("b", .annika, nach: 5), text("c", .ahmed, nach: 10), text("d", .ahmed, nach: 20)]
        let status = LeseStatus(nachrichten: liste, ich: .ahmed, gelesenBisPartner: t0.addingTimeInterval(12))
        XCTAssertEqual(status.gelesenID, "c")
        XCTAssertEqual(status.offen?.id, "d")
        let nieGelesen = LeseStatus(nachrichten: liste, ich: .ahmed, gelesenBisPartner: nil)
        XCTAssertNil(nieGelesen.gelesenID)
        XCTAssertEqual(nieGelesen.offen?.id, "d")
    }

    // Fix round 2: header place label.
    func testOrtLabelKurzerNameSonstKategorie() {
        XCTAssertEqual(ChatKopfLogik.ortLabel(name: "Home", kategorie: "zuhause"), "Home")
        XCTAssertEqual(ChatKopfLogik.ortLabel(name: "Gym", kategorie: "gym"), "Gym")
        XCTAssertEqual(ChatKopfLogik.ortLabel(name: "Berufskolleg Geilenkirchen", kategorie: "schule"), "Schule")
        XCTAssertEqual(ChatKopfLogik.ortLabel(name: "Wohnung bei Mama und Papa", kategorie: "zuhause"), "Home")
        XCTAssertEqual(ChatKopfLogik.ortLabel(name: "  ", kategorie: "arbeit"), "Arbeit")
        XCTAssertEqual(ChatKopfLogik.ortLabel(name: "Oma", kategorie: "sonstiges"), "Oma")
    }

    // Fix round 3: screenshot/recording notices, at most one per 10 s.
    func testHinweisDrosselZehnSekunden() {
        XCTAssertTrue(ChatHinweis.darfMelden(letzte: nil, jetzt: t0))
        XCTAssertFalse(ChatHinweis.darfMelden(letzte: t0, jetzt: t0.addingTimeInterval(9.9)))
        XCTAssertTrue(ChatHinweis.darfMelden(letzte: t0, jetzt: t0.addingTimeInterval(10)))
    }

    func testHinweisTexte() {
        XCTAssertEqual(ChatHinweis.text(von: "Ahmed", art: ChatHinweis.gespeichertFoto), "Ahmed hat ein Bild in Aufnahmen gespeichert")
        XCTAssertEqual(ChatHinweis.text(von: "Annika", art: ChatHinweis.gespeichertVideo), "Annika hat ein Video in Aufnahmen gespeichert")
        XCTAssertEqual(ChatHinweis.text(von: "Ahmed", art: ChatHinweis.chatScreenshot), "Ahmed hat einen Screenshot vom Chat gemacht")
        XCTAssertEqual(ChatHinweis.text(von: "Ahmed", art: ChatHinweis.chatAufnahme), "Ahmed nimmt den Chat auf")
        XCTAssertEqual(ChatHinweis.text(von: "Annika", art: "screenshot"), "Annika hat einen Screenshot gemacht", "snap screenshots unchanged")
    }

    // Screenshot notices follow what is on screen; the most specific visible context wins.
    func testScreenshotKontextVorrang() {
        XCTAssertNil(ScreenshotKontext.aktiv([]), "Home, Health, own profile: nothing registered, no notice")
        XCTAssertEqual(ScreenshotKontext.aktiv([.chat]), .chat)
        XCTAssertEqual(ScreenshotKontext.aktiv([.chat, .partnerProfil]), .partnerProfil, "profile sheet over the chat")
        XCTAssertEqual(ScreenshotKontext.aktiv([.partnerProfil, .chat]), .partnerProfil, "order doesn't matter")
        XCTAssertEqual(ScreenshotKontext.aktiv([.chat, .sticker]), .sticker)
        XCTAssertEqual(ScreenshotKontext.aktiv([.partnerProfil, .medium(video: false, eigen: false)]), .medium(video: false, eigen: false))
    }

    func testScreenshotKontextArtUndText() {
        let faelle: [(ScreenshotKontext, Bool, String, String)] = [
            (.chat, false, "chatScreenshot", "Ahmed hat einen Screenshot vom Chat gemacht"),
            (.chat, true, "chatAufnahme", "Ahmed nimmt den Chat auf"),
            (.partnerProfil, false, "profilScreenshot", "Ahmed hat einen Screenshot von deinem Profil gemacht"),
            (.partnerProfil, true, "profilAufnahme", "Ahmed nimmt dein Profil auf"),
            (.sticker, false, "stickerScreenshot", "Ahmed hat einen Screenshot von einem Sticker gemacht"),
            (.medium(video: false, eigen: false), false, "fotoScreenshot", "Ahmed hat einen Screenshot von deinem Foto gemacht"),
            (.medium(video: true, eigen: false), true, "videoAufnahme", "Ahmed nimmt dein Video auf"),
            (.medium(video: false, eigen: true), false, "chatFotoScreenshot", "Ahmed hat einen Screenshot von einem Foto im Chat gemacht"),
            (.medium(video: true, eigen: true), false, "chatVideoScreenshot", "Ahmed hat einen Screenshot von einem Video im Chat gemacht"),
        ]
        for (kontext, aufnahme, art, text) in faelle {
            XCTAssertEqual(kontext.art(aufnahme: aufnahme), art)
            XCTAssertEqual(ChatHinweis.text(von: "Ahmed", art: art), text)
        }
        for art in ["stickerAufnahme", "fotoAufnahme", "videoScreenshot", "chatFotoAufnahme", "chatVideoAufnahme"] {
            XCTAssertNotNil(ChatHinweis.texte[art], art)
        }
    }

    func testNurEmoji() {
        XCTAssertTrue(NachrichtBlase.nurEmoji("😂"))
        XCTAssertTrue(NachrichtBlase.nurEmoji("❤️ 😘"))
        XCTAssertFalse(NachrichtBlase.nurEmoji("😂😂😂😂"))
        XCTAssertFalse(NachrichtBlase.nurEmoji("ok 👍"))
        XCTAssertFalse(NachrichtBlase.nurEmoji(""))
    }

    func testLeisteUeberDerBlaseMenueDarunter() {
        let r = CGRect(x: 100, y: 400, width: 200, height: 40)
        let lage = FokusLayout.positionen(rahmen: r, leiste: 56, menue: 200, oben: 50, unten: 800)
        XCTAssertEqual(lage.leisteY, 336)
        XCTAssertEqual(lage.menueY, 448)
    }

    func testUntenGehtDasMenueNachOben() {
        let r = CGRect(x: 100, y: 700, width: 200, height: 40)
        let lage = FokusLayout.positionen(rahmen: r, leiste: 56, menue: 200, oben: 50, unten: 800)
        XCTAssertEqual(lage.leisteY, 636)
        XCTAssertEqual(lage.menueY, 428)
    }

    func testObenGehtDieLeisteUnterDieBlase() {
        let r = CGRect(x: 100, y: 60, width: 200, height: 40)
        let lage = FokusLayout.positionen(rahmen: r, leiste: 56, menue: 200, oben: 50, unten: 800)
        XCTAssertEqual(lage.leisteY, 108)
        XCTAssertEqual(lage.menueY, 172)
    }

    func testLeisteBleibtAufDemBildschirm() {
        let rechts = CGRect(x: 300, y: 400, width: 80, height: 40)
        XCTAssertEqual(FokusLayout.mitteX(rahmen: rechts, breite: 344, rechts: true, flaeche: 390), 208)
        let ganzRechts = CGRect(x: 350, y: 400, width: 40, height: 40)
        XCTAssertEqual(FokusLayout.mitteX(rahmen: ganzRechts, breite: 344, rechts: true, flaeche: 390), 210, "8 pt margin")
        let links = CGRect(x: 10, y: 400, width: 80, height: 40)
        XCTAssertEqual(FokusLayout.mitteX(rahmen: links, breite: 250, rechts: false, flaeche: 390), 135)
    }
}
