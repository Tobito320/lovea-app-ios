import SwiftUI
import XCTest
@testable import Lovea

/// Brief D render boards (Z-38, Z-39 and the controller addendum): bodies, hairstyles per person,
/// brand pieces, jewelry, extras, expressions, gym look and the new Bitmoji standard figures.
/// Static figures only (`animiert: false`), written by Agent A's `RenderTafel`.
@MainActor
final class RenderGalerieFigurenTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)
    private typealias A = FigurAussehen

    private func figur(_ a: FigurAussehen, _ z: FigurZustand = .ruhig, groesse: CGFloat = 120, ganz: Bool = false, extras: Set<FigurExtra> = []) -> AnyView {
        AnyView(FigurView(a, zustand: z, groesse: groesse, animiert: false, ganzkoerper: ganz, extras: extras))
    }

    /// Chest to hands of a large full body, so rings, bracelets and watches are visible.
    private func nah(_ a: FigurAussehen) -> AnyView {
        AnyView(FigurView(a, zustand: .ruhig, groesse: 300, animiert: false, ganzkoerper: true).frame(width: 110, height: 130).clipped())
    }

    private func person(_ tag: FigurGeschlecht) -> Person { tag == .w ? .annika : .ahmed }

    func testKoerper() {
        var zellen: [Zelle] = []
        for p in Person.allCases {
            for i in A.koerperformen.indices {
                var a = A.standard(for: p)
                a.koerperform = i
                zellen.append((titel: "\(p.name): \(A.koerperformen[i])", ansicht: figur(a, groesse: 160, ganz: true)))
            }
        }
        RenderTafel.speichern("figuren-koerper", spalten: 7, zellen: zellen)
    }

    func testGym() {
        var zellen: [Zelle] = []
        for p in Person.allCases {
            let formen = A.erlaubt(A.koerperformen, geschlecht: A.koerperformenGeschlecht, shop: A.koerperformenVersteckt, fuer: p)
            for i in formen {
                var a = A.standard(for: p)
                a.koerperform = i
                zellen.append((titel: "\(p.name) Gym: \(A.koerperformen[i])", ansicht: figur(a, .gym, groesse: 160, ganz: true)))
                zellen.append((titel: "\(p.name) Gym halb", ansicht: figur(a, .gym)))
            }
        }
        RenderTafel.speichern("figuren-gym", spalten: 8, zellen: zellen)
    }

    func testFrisuren() {
        for (p, name) in [(Person.ahmed, "frisuren-m"), (Person.annika, "frisuren-w")] {
            let erlaubt = A.erlaubt(A.frisuren, geschlecht: A.frisurenGeschlecht, fuer: p)
            let zellen: [Zelle] = erlaubt.map { i in
                var a = A.standard(for: p)
                a.frisur = i
                return (titel: "\(i) \(A.frisuren[i])", ansicht: figur(a))
            }
            RenderTafel.speichern(name, spalten: 8, zellen: zellen)
        }
    }

    func testMarken() {
        var zellen: [Zelle] = []
        func zeige(_ titel: String, _ p: Person, _ aendern: (inout FigurAussehen) -> Void) {
            var a = A.standard(for: p)
            aendern(&a)
            zellen.append((titel: titel, ansicht: figur(a, groesse: 160, ganz: true)))
        }
        let oberteilFarbe = [17: 2, 18: 13, 19: 4, 20: 9, 21: 3, 22: 2]
        for i in 17...22 {
            zeige(A.oberteile[i], person(A.oberteileGeschlecht[i])) {
                $0.oberteil = i
                $0.oberteilfarbe = oberteilFarbe[i] ?? 2
                $0.oberteilfarbeHex = nil
                $0.jacke = 0
            }
        }
        let jackenFarbe = [8: 5, 9: 9, 10: 14]
        for i in 8...10 {
            zeige(A.jacken[i], .ahmed) {
                $0.jacke = i
                $0.jackenfarbe = jackenFarbe[i] ?? 3
            }
        }
        let hosenFarbe = [12: 3, 13: 4, 14: 4, 15: 3]
        for i in 12...15 {
            zeige(A.hosen[i], person(A.hosenGeschlecht[i])) {
                $0.hose = i
                $0.hosenfarbe = hosenFarbe[i] ?? 3
                $0.hosenfarbeHex = nil
            }
        }
        let schuhFarbe = [10: 2, 11: 3, 12: 2]
        for i in 10...12 {
            zeige(A.schuhArten[i], .ahmed) {
                $0.schuhe = i
                $0.schuhfarbe = schuhFarbe[i] ?? 2
                $0.schuhfarbeHex = nil
            }
        }
        zeige(A.kopfbedeckungen[7], .ahmed) {
            $0.kopfbedeckung = 7
            $0.muetzenfarbe = 14
        }
        let luxus = ["mode.gucci-web-shirt", "mode.dior-oblique-pulli", "mode.lv-monogramm-hemd", "mode.balenciaga-hoodie",
                     "mode.moncler-maya", "mode.chanel-tweed", "mode.prada-nylon", "mode.gucci-ace", "mode.balenciaga-triple-s"]
        for id in luxus {
            zeige(id, id.contains("chanel") ? .annika : .ahmed) {
                $0.jacke = 0
                $0.anziehen(id)
            }
        }
        for id in taschenKatalog.keys.sorted() {
            zeige(id, .annika) { $0.tasche = id }
        }
        RenderTafel.speichern("marken", spalten: 8, zellen: zellen)
    }

    func testSchmuck() {
        var zellen: [Zelle] = []
        func zeige(_ titel: String, _ p: Person, kopf: Bool = false, _ aendern: (inout FigurAussehen) -> Void) {
            var a = A.standard(for: p)
            a.jacke = 0
            aendern(&a)
            zellen.append((titel: titel, ansicht: kopf ? figur(a) : nah(a)))
        }
        for i in 1..<A.ketten.count { zeige(A.ketten[i], person(A.kettenGeschlecht[i])) { $0.kette = i } }
        for i in 1..<A.ringe.count { zeige(A.ringe[i], person(A.ringeGeschlecht[i])) { $0.ring = i } }
        for i in 1..<A.armbaender.count { zeige(A.armbaender[i], person(A.armbaenderGeschlecht[i])) { $0.armband = i } }
        for i in 1..<A.uhrenAlltag.count { zeige(A.uhrenAlltag[i], .ahmed) { $0.uhrAlltag = i } }
        for i in 1..<A.ohrringArten.count { zeige(A.ohrringArten[i], .annika, kopf: true) { $0.ohrringe = i } }
        for id in schmuckKatalog.keys.sorted() {
            let ohr = schmuckKatalog[id]?.stil.ort == .ohr
            zeige(id, .annika, kopf: ohr) { $0.schmuck = id }
        }
        for id in uhrenKatalog.keys.sorted() { zeige(id, .ahmed) { $0.uhr = id } }
        RenderTafel.speichern("schmuck", spalten: 8, zellen: zellen)
    }

    func testExtras() {
        var zellen: [Zelle] = []
        for p in Person.allCases {
            let a = A.standard(for: p)
            for e in FigurExtra.allCases {
                zellen.append((titel: "\(p.name): \(e.rawValue)", ansicht: figur(a, extras: [e])))
                zellen.append((titel: "\(p.name): \(e.rawValue) ganz", ansicht: figur(a, groesse: 160, ganz: true, extras: [e])))
            }
            zellen.append((titel: "\(p.name): lädt + Kabel", ansicht: figur(a, .laedt, groesse: 160, ganz: true, extras: [.handyKabel])))
            zellen.append((titel: "\(p.name): Regen + Kabel", ansicht: figur(a, .laeuft, groesse: 160, ganz: true, extras: [.schirm, .handyKabel])))
        }
        RenderTafel.speichern("extras", spalten: 6, zellen: zellen)
    }

    func testMimik() {
        for (ganz, name) in [(false, "figuren-mimik"), (true, "figuren-mimik-ganz")] {
            var zellen: [Zelle] = []
            for p in Person.allCases {
                for z in FigurZustand.mimik {
                    zellen.append((titel: "\(p.name) \(z.titel)", ansicht: figur(A.standard(for: p), z, groesse: ganz ? 160 : 120, ganz: ganz)))
                }
            }
            RenderTafel.speichern(name, spalten: 7, zellen: zellen)
        }
    }

    func testStandardNeu() {
        var zellen: [Zelle] = []
        for p in Person.allCases {
            let a = A.standard(for: p)
            for z in [FigurZustand.ruhig, .imChat, .laeuft, .zwinkert] {
                zellen.append((titel: "\(p.name) \(z.titel)", ansicht: figur(a, z)))
                zellen.append((titel: "\(p.name) \(z.titel) ganz", ansicht: figur(a, z, groesse: 200, ganz: true)))
            }
        }
        RenderTafel.speichern("figuren-standard-neu", spalten: 8, zellen: zellen)
    }

    /// Fix round 3: every outfit preset on its person, plus Ahmed's own hairstyles and beards.
    func testOutfitsUndAhmed() {
        var zellen: [Zelle] = []
        for p in Person.allCases {
            for o in A.outfits(fuer: p) {
                var a = A.standard(for: p)
                a.anziehen(outfit: o)
                zellen.append((titel: o.name, ansicht: figur(a, groesse: 160, ganz: true)))
            }
        }
        for i in 78..<A.frisuren.count {
            var a = A.standard(for: .ahmed)
            a.frisur = i
            zellen.append((titel: A.frisuren[i], ansicht: figur(a)))
        }
        let baerte: [(Int, Int)] = [(14, 1), (15, 1), (14, 0), (15, 2)]
        for (bart, kinn) in baerte {
            var a = A.standard(for: .ahmed)
            a.bart = bart
            a.kinnbart = kinn
            zellen.append((titel: "\(A.baerte[bart]) + \(A.kinnbaerte[kinn])", ansicht: figur(a)))
        }
        RenderTafel.speichern("figuren-ahmed-outfits", spalten: 8, zellen: zellen)
    }

    /// Fix round 4: put these next to `design/ki/sticker/wir-ich.png` — standard half and full body,
    /// each of his hairstyles large, and the cap look.
    func testAhmedVergleich() {
        var zellen: [Zelle] = []
        let a = A.standard(for: .ahmed)
        zellen.append((titel: "Standard halb", ansicht: figur(a, groesse: 240)))
        // Fix round 5: full body large enough that its head matches the half figure's head.
        zellen.append((titel: "Standard ganz", ansicht: figur(a, groesse: 480, ganz: true)))
        for i in 78...82 {
            var b = a
            b.frisur = i
            zellen.append((titel: A.frisuren[i], ansicht: figur(b, groesse: 240)))
        }
        if let cap = A.outfits.first(where: { $0.name == "Cap Look" }) {
            var b = a
            b.anziehen(outfit: cap)
            zellen.append((titel: "Cap Look", ansicht: figur(b, groesse: 240)))
        }
        RenderTafel.speichern("figuren-ahmed-vergleich", spalten: 4, zellen: zellen)
    }
}
