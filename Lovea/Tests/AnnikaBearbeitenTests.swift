import SwiftUI
import UIKit
import XCTest
@testable import Lovea

/// p68: Ahmed bearbeitet Annikas Figur (`figur.aussehenFuer`) und legt Blumen auf sein Bord. Die Op-Tests
/// falten wie der Beobachter im `FigurenModell` (gleiche Funktion `aussehenZiel`, Op für Op in Reihenfolge).
@MainActor
final class AnnikaBearbeitenTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Wer darf wessen Figur ändern

    func testFigurBearbeitbarNurSelbstUndAhmedFuerAnnika() {
        XCTAssertTrue(Person.ahmed.figurBearbeitbar(durch: .ahmed))
        XCTAssertTrue(Person.annika.figurBearbeitbar(durch: .annika))
        XCTAssertTrue(Person.annika.figurBearbeitbar(durch: .ahmed), "Ahmed darf Annikas Figur ändern")
        XCTAssertFalse(Person.ahmed.figurBearbeitbar(durch: .annika), "Annika darf Ahmeds Figur nicht ändern")
    }

    // MARK: - Falten

    private func look(_ person: Person, oberteil: Int) -> FigurAussehen {
        var a = FigurAussehen.standard(for: person)
        a.oberteil = oberteil
        a.person = nil // `person` wird nicht mitgesendet, die Op trägt es nicht
        return a
    }

    private func eigene(_ von: Person, _ a: FigurAussehen, _ s: Double) -> Op {
        Op(id: UUID().uuidString, seq: nil, art: "figur.aussehen", von: von, zeit: t0.addingTimeInterval(s), d: Op.neu("figur.aussehen", a, von: von).d)
    }

    private func fuer(_ von: Person, _ ziel: Person, _ a: FigurAussehen, _ s: Double) -> Op {
        let d = AussehenFuerD(fuer: ziel, aussehen: a)
        return Op(id: UUID().uuidString, seq: nil, art: "figur.aussehenFuer", von: von, zeit: t0.addingTimeInterval(s), d: Op.neu("figur.aussehenFuer", d, von: von).d)
    }

    /// Dasselbe wie der Beobachter im `FigurenModell`: die Ops der Reihe nach, der letzte gewinnt.
    private func falten(_ ops: [Op]) -> [Person: FigurAussehen] {
        var stand: [Person: FigurAussehen] = [:]
        for op in ops {
            guard let ziel = FigurenModell.aussehenZiel(op) else { continue }
            stand[ziel.person] = ziel.aussehen
        }
        return stand
    }

    func testAhmedAendertAnnikasLookUndSeinEigenerBleibt() {
        let ahmed = look(.ahmed, oberteil: 2)
        let annikaAlt = look(.annika, oberteil: 1)
        let annikaNeu = look(.annika, oberteil: 5)
        let stand = falten([eigene(.ahmed, ahmed, 0), eigene(.annika, annikaAlt, 1), fuer(.ahmed, .annika, annikaNeu, 2)])
        XCTAssertEqual(stand[.annika]?.oberteil, 5, "Annikas Look ist der, den Ahmed gesetzt hat")
        XCTAssertEqual(stand[.ahmed], ahmed, "Ahmeds Look bleibt unverändert")
    }

    func testAnnikaKannAhmedsFigurNichtAendern() {
        let ahmed = look(.ahmed, oberteil: 2)
        let fremd = look(.ahmed, oberteil: 9)
        let op = fuer(.annika, .ahmed, fremd, 5)
        XCTAssertNil(FigurenModell.aussehenZiel(op), "die Op von Annika für Ahmed zählt nicht")
        let stand = falten([eigene(.ahmed, ahmed, 0), op])
        XCTAssertEqual(stand[.ahmed], ahmed)
    }

    func testAnnikaAendertWeiterIhreEigeneFigur() {
        let stand = falten([eigene(.annika, look(.annika, oberteil: 4), 0)])
        XCTAssertEqual(stand[.annika]?.oberteil, 4)
        // Auch als `Fuer`-Op für sich selbst gilt sie (Erlaubnis ist "selbst oder Ahmed").
        let selbst = falten([fuer(.annika, .annika, look(.annika, oberteil: 6), 1)])
        XCTAssertEqual(selbst[.annika]?.oberteil, 6)
    }

    func testDieLetzteAenderungGewinntInDerReihenfolgeDesLogs() {
        let a1 = look(.annika, oberteil: 1), a2 = look(.annika, oberteil: 2), a3 = look(.annika, oberteil: 3)
        // Ahmed, dann Annika selbst, dann wieder Ahmed.
        XCTAssertEqual(falten([fuer(.ahmed, .annika, a1, 0), eigene(.annika, a2, 1)])[.annika]?.oberteil, 2)
        XCTAssertEqual(falten([eigene(.annika, a2, 1), fuer(.ahmed, .annika, a1, 2)])[.annika]?.oberteil, 1)
        XCTAssertEqual(falten([fuer(.ahmed, .annika, a1, 0), eigene(.annika, a2, 1), fuer(.ahmed, .annika, a3, 2)])[.annika]?.oberteil, 3)
    }

    func testEineOpKommtDoppeltAnUndFaltetGleich() {
        let op = fuer(.ahmed, .annika, look(.annika, oberteil: 7), 0)
        XCTAssertEqual(falten([op, op])[.annika]?.oberteil, 7, "optimistisch und bestätigt: dasselbe Ergebnis")
    }

    func testKaputteFuerOpWirdUebergangen() {
        let kaputt = Op(id: "k", seq: nil, art: "figur.aussehenFuer", von: .ahmed, zeit: t0, d: Data("{\"fuer\":\"annika\"}".utf8))
        XCTAssertNil(FigurenModell.aussehenZiel(kaputt))
    }

    func testEigeneOpBleibtBeimSenderUndKenntV1() {
        let op = eigene(.annika, look(.annika, oberteil: 3), 0)
        let ziel = FigurenModell.aussehenZiel(op)
        XCTAssertEqual(ziel?.person, .annika)
        XCTAssertEqual(ziel?.aussehen.oberteil, 3)
    }

    // MARK: - Münzen: Geschenk von Ahmed an Annika

    func testKaufFuerAnnikaZahltAhmedUndGehoertAnnika() {
        let kauf = BesitzLogik.Kauf(seq: 1, id: "k1", von: .ahmed, artikel: "socken", fuer: .annika, verdient: 200)
        let e = BesitzLogik.auswerten([kauf], verdient: [.ahmed: 200, .annika: 0], preis: { $0 == "socken" ? 150 : nil })
        XCTAssertEqual(e.ausgegeben[.ahmed], 150, "Ahmed zahlt")
        XCTAssertNil(e.ausgegeben[.annika], "Annikas Konto bleibt unberührt")
        XCTAssertTrue(e.besitzt("socken", .annika))
        XCTAssertFalse(e.besitzt("socken", .ahmed))
    }

    // MARK: - Ahmeds Bord

    private let rahmen = ZuhauseZeichnung.strauss

    func testBordPlaetzeLiegenAufDemBordUndTeilenSichNichts() {
        let bord = ZuhauseZeichnung.bord
        let plaetze = ZuhauseZeichnung.bordPlaetze
        XCTAssertEqual(plaetze.count, 4)
        let rects = plaetze.map { CGRect(x: $0.x - rahmen.width / 2, y: $0.y - rahmen.height, width: rahmen.width, height: rahmen.height) }
        for r in rects { XCTAssertTrue(bord.contains(r), "\(r) liegt nicht im Bord \(bord)") }
        for i in rects.indices { for j in rects.indices where j > i { XCTAssertFalse(rects[i].intersects(rects[j]), "Plätze \(i) und \(j) überlappen") } }
        let vase = ZuhauseZeichnung.bordVasenPlatz
        let vasenRect = CGRect(x: vase.x - rahmen.width / 2, y: vase.y - rahmen.height, width: rahmen.width, height: rahmen.height)
        XCTAssertTrue(bord.contains(vasenRect), "Vasen-Strauß ragt aus dem Bord")
    }

    func testBordBerueehrtAnnikasKommodeNicht() {
        XCTAssertFalse(ProfilSlots.welt(.bord).intersects(ProfilSlots.welt(.kommode)))
        XCTAssertEqual(ProfilSlots.zone(.bord), .schlaf, "das Bord hängt in Ahmeds Schlafzone")
    }

    func testLeereStraeusseSindLeerUndDieAuswahlIstProPersonGetrennt() {
        XCTAssertTrue(ZuhauseStraeusse().leer)
        XCTAssertFalse(ZuhauseStraeusse(schrank: ["lila"]).leer)
        XCTAssertFalse(ZuhauseStraeusse(vase: "lila").leer)
        // Zwei Personen, zwei Werte unter demselben Schlüssel: kein gemeinsamer Zustand in der Struktur.
        let ahmed = ZimmerStraeusse(schrank: [.lila], vase: nil)
        let annika = ZimmerStraeusse(schrank: [.rotBunt, .pinkCreme], vase: .lila)
        XCTAssertEqual(ZimmerStraeusse.lesen(ahmed.json), ahmed)
        XCTAssertEqual(ZimmerStraeusse.lesen(annika.json), annika)
        XCTAssertNotEqual(ahmed.fuerBuehne, annika.fuerBuehne)
    }

    // MARK: - Bild: das Bord in der Welt

    private struct Bild {
        let breite: Int
        let hoehe: Int
        let rgba: [UInt8]
    }

    private func bild(_ ansicht: some View) -> Bild? {
        let r = ImageRenderer(content: ansicht)
        r.scale = 1
        guard let cg = r.uiImage?.cgImage else { return nil }
        let b = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: b * h * 4)
        let ok: Bool = px.withUnsafeMutableBytes { roh in
            guard let ctx = CGContext(data: roh.baseAddress, width: b, height: h, bitsPerComponent: 8, bytesPerRow: b * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: b, height: h))
            return true
        }
        return ok ? Bild(breite: b, hoehe: h, rgba: px) : nil
    }

    private func welt(_ ahmed: ZuhauseStraeusse) -> AnyView {
        let stand = ZuhauseSzenenstand(zeit: .tag, ZuhauseAblauf.aufstellung(.tag, schritt: 2), mitGeste: false)
        let szene = ZuhauseBuehne(ahmedStraeusse: ahmed, fest: stand, welt: .panorama) { f in
            FigurView(.standard(for: f.person), zustand: f.zustand, groesse: f.groesse, animiert: false, ganzkoerper: f.ganzkoerper)
        } paar: {
            EmptyView()
        }
        return AnyView(szene.frame(width: ProfilSlots.weltBreite, height: ProfilSlots.hoehe).clipped())
    }

    /// Mit Ahmeds Sträußen ändern sich nur Pixel auf dem Bord (die Bühne zeichnet ohne Sträuße nichts davon).
    func testBordZeichnetNurAufDemBord() throws {
        let leer = try XCTUnwrap(bild(welt(ZuhauseStraeusse())))
        let mit = try XCTUnwrap(bild(welt(ZuhauseStraeusse(schrank: ["lila", "rotBunt"], vase: "pinkCreme"))))
        XCTAssertEqual(mit.breite, leer.breite)
        var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1, n = 0
        for i in stride(from: 0, to: leer.rgba.count, by: 4) where leer.rgba[i..<i + 4] != mit.rgba[i..<i + 4] {
            let p = i / 4
            minX = min(minX, p % leer.breite); maxX = max(maxX, p % leer.breite)
            minY = min(minY, p / leer.breite); maxY = max(maxY, p / leer.breite)
            n += 1
        }
        XCTAssertGreaterThan(n, 800, "Bord und Sträuße müssen sichtbar sein")
        let bord = ZuhauseZeichnung.bord
        let k = CGFloat(leer.breite) / ProfilSlots.weltBreite
        XCTAssertGreaterThanOrEqual(CGFloat(minX), (bord.minX - 6) * k)
        XCTAssertLessThanOrEqual(CGFloat(maxX), (bord.maxX + 6) * k)
        XCTAssertGreaterThanOrEqual(CGFloat(minY), (bord.minY - 6) * k)
        XCTAssertLessThanOrEqual(CGFloat(maxY), (bord.maxY + 6) * k)
    }

    func testTafelBord() {
        let voll = ZuhauseStraeusse(schrank: ["lila", "rotBunt", "rosaGerbera"], vase: "pinkCreme")
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Ahmeds Bord: drei Sträuße und die Vase", ansicht: welt(voll)),
            (titel: "Ahmeds Bord: einer", ansicht: welt(ZuhauseStraeusse(schrank: ["glitzerRot"]))),
            (titel: "Ohne Sträuße: kein Bord", ansicht: welt(ZuhauseStraeusse())),
        ]
        RenderTafel.speichern("p68-bord", spalten: 1, zellen: zellen)
    }
}
