import SwiftUI
import XCTest
@testable import Lovea

/// Brief G render boards: every profile scene with its figure, drawn like the own header (still,
/// full header size), and every bed with two sleepers. Frame photos can't load here, so the frames
/// show their drawn stand-in.
@MainActor
final class RenderGalerieSzeneTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private let eingerichtet = Zimmer(
        bett: 2, wand: 1, boden: 3, deko: Zimmer.dekoArten.map { $0.id },
        rahmen: [.init(slot: 0, medienId: "a"), .init(slot: 1, medienId: "b"), .init(slot: 2, medienId: "c")]
    )

    private func kopf(_ szene: ProfilSzene, _ p: Person = .annika, zimmer: Zimmer = Zimmer(), nacht: Bool = false, code: Int? = nil, temperatur: Double? = nil, live: FigurZustand = .ruhig, tisch: Int = 0) -> AnyView {
        let figuren: AnyView
        if case .schlafen(let zusammen) = szene {
            let schlaefer = zusammen ? [p, p.partner] : [p]
            figuren = AnyView(SchlafendeFiguren(zimmer: zimmer, schlaefer: schlaefer.map { FigurAussehen.standard(for: $0) }, animiert: false))
        } else {
            let zustand = szene.figur(live)
            let extras = szene.extras(zustand, wetterCode: code, temperatur: temperatur)
            figuren = AnyView(FigurView(.standard(for: p), zustand: zustand, groesse: 340, animiert: false, ganzkoerper: true, extras: extras, tisch: tisch))
        }
        return AnyView(
            ZStack(alignment: .bottom) {
                ProfilSzeneHintergrund(szene: szene, zimmer: zimmer, nacht: nacht, animiert: false)
                figuren
            }
            .frame(width: 390, height: 430)
            .clipped()
        )
    }

    func testSzenen() {
        var zellen: [Zelle] = [
            (titel: "Zimmer (Standard)", ansicht: kopf(.zimmer)),
            (titel: "Zimmer eingerichtet", ansicht: kopf(.zimmer, .ahmed, zimmer: eingerichtet)),
            (titel: "Zimmer bei Nacht", ansicht: kopf(.zimmer, .ahmed, zimmer: eingerichtet, nacht: true)),
            (titel: "Schlafen allein", ansicht: kopf(.schlafen(zusammen: false))),
            (titel: "Schlafen zusammen", ansicht: kopf(.schlafen(zusammen: true), zimmer: eingerichtet)),
            (titel: "Gym Ahmed", ansicht: kopf(.gym, .ahmed)),
            (titel: "Gym Annika", ansicht: kopf(.gym, .annika)),
            (titel: "Draußen Regen", ansicht: kopf(.draussen(wetter: .regen, nacht: false), code: 61, temperatur: 12)),
            (titel: "Draußen Sonne", ansicht: kopf(.draussen(wetter: .sonne, nacht: false), .ahmed, code: 0, temperatur: 24)),
            (titel: "Draußen Nacht", ansicht: kopf(.draussen(wetter: .sonne, nacht: true), code: 0, temperatur: 14)),
            (titel: "Draußen Wolken", ansicht: kopf(.draussen(wetter: .wolken, nacht: false), .ahmed, code: 3, temperatur: 16)),
            (titel: "Draußen Schnee", ansicht: kopf(.draussen(wetter: .schnee, nacht: false), code: 73, temperatur: -2)),
        ]
        let unterwegs = ProfilSzene.unterwegs(wetter: .wolken, nacht: false)
        zellen.append((titel: "Unterwegs (Auto)", ansicht: kopf(unterwegs, .ahmed)))
        zellen.append((titel: "Unterwegs (Zug)", ansicht: kopf(unterwegs, .ahmed, live: .zug)))
        zellen.append((titel: "Schule Annika", ansicht: kopf(.schule, .annika)))
        zellen.append((titel: "Schule Ahmed", ansicht: kopf(.schule, .ahmed)))
        zellen.append((titel: "Arbeit Annika", ansicht: kopf(.arbeit, .annika)))
        zellen.append((titel: "Arbeit Ahmed", ansicht: kopf(.arbeit, .ahmed)))
        RenderTafel.speichern("profil-szenen", spalten: 4, zellen: zellen)
    }

    /// Brief G fix: only the sleeper in bed (Annika left, Ahmed right), the dark room with the lit
    /// lamp, and the tired look from 22:00.
    func testNacht() {
        let muede = AnyView(FigurView(.standard(for: .annika), zustand: .ruhig, groesse: 340, animiert: false, ganzkoerper: true, extras: [.schlaefrig]))
        let nurAhmed = AnyView(
            HStack(alignment: .bottom, spacing: -30) {
                FigurView(.standard(for: .annika), zustand: .ruhig, groesse: 340, animiert: false, ganzkoerper: true, extras: [.schlaefrig])
                SchlafendeFiguren(zimmer: eingerichtet, schlaefer: [.standard(for: .ahmed)], animiert: false, skala: 0.75)
            }
        )
        let nurAnnika = AnyView(
            HStack(alignment: .bottom, spacing: -30) {
                SchlafendeFiguren(zimmer: Zimmer(), schlaefer: [.standard(for: .annika)], animiert: false, skala: 0.75)
                FigurView(.standard(for: .ahmed), zustand: .ruhig, groesse: 340, animiert: false, ganzkoerper: true, extras: [.schlaefrig])
            }
        )
        let zellen: [Zelle] = [
            (titel: "Nur Ahmed schläft", ansicht: nacht(nurAhmed, zimmer: eingerichtet)),
            (titel: "Nur Annika schläft", ansicht: nacht(nurAnnika, zimmer: Zimmer())),
            (titel: "Müde ab 22 Uhr", ansicht: nacht(muede, zimmer: Zimmer(), mitBett: true)),
            (titel: "Annika sitzt auf, Ahmed schläft", ansicht: nacht(AnyView(SchlafendeFiguren(
                zimmer: eingerichtet, schlaefer: [.standard(for: .annika), .standard(for: .ahmed)], animiert: false, sitzend: [0]
            )), zimmer: eingerichtet)),
            (titel: "Ahmed sitzt auf (allein)", ansicht: nacht(AnyView(SchlafendeFiguren(
                zimmer: Zimmer(), schlaefer: [.standard(for: .ahmed)], animiert: false, sitzend: [0]
            )), zimmer: Zimmer())),
        ]
        RenderTafel.speichern("profil-nacht", spalten: 5, zellen: zellen)
    }

    private func nacht(_ figuren: AnyView, zimmer: Zimmer, mitBett: Bool = false) -> AnyView {
        AnyView(
            ZStack(alignment: .bottom) {
                ProfilSzeneHintergrund(szene: .zimmer, zimmer: zimmer, nacht: true, animiert: false, mitBett: mitBett)
                figuren.brightness(-0.1)
            }
            .frame(width: 390, height: 430)
            .clipped()
        )
    }

    func testBetten() {
        let zellen: [Zelle] = Zimmer.betten.indices.map { i in
            var z = Zimmer()
            z.bett = i
            let schlaefer = [FigurAussehen.standard(for: .annika), FigurAussehen.standard(for: .ahmed)]
            return (titel: Zimmer.betten[i], ansicht: AnyView(SchlafendeFiguren(zimmer: z, schlaefer: schlaefer, animiert: false).background(Color(white: 0.93))))
        }
        RenderTafel.speichern("profil-betten", spalten: 5, zellen: zellen)
    }

    /// Brief G: every place furnished, each with its desk or bed, poster, lights and deco.
    func testOrteEingerichtet() {
        let zuhause = Zimmer(bett: 2, wand: 4, boden: 4, deko: ["fenster", "lampe", "teppichRund", "monstera", "ledStreifen", "sneakerRegal", "plattenspieler", "kerze", "sitzsack"], poster: 2)
        let buero = Zimmer(wand: 5, boden: 1, deko: ["buecherregal", "stehlampe", "kaffeemaschine", "kaktus", "tresor", "wanduhr", "lautsprecher", "teppich"], poster: 8, tisch: 3)
        let schule = Zimmer(wand: 3, boden: 3, deko: ["globus", "pinnwand", "wanduhr", "blumen", "ledWeiss", "teppichRund"], poster: 4, tisch: 1)
        var zellen: [Zelle] = []
        for p in [Person.annika, .ahmed] {
            zellen.append((titel: "\(p.name) Zuhause (Standard)", ansicht: kopf(.zimmer, p, zimmer: Zimmer(ort: .zuhause, person: p))))
            if p == .annika { zellen.append((titel: "Annika Zuhause eingerichtet", ansicht: kopf(.zimmer, p, zimmer: zuhause))) }
            zellen.append((titel: "\(p.name) Büro", ansicht: kopf(.arbeit, p, zimmer: buero, tisch: buero.tisch)))
            zellen.append((titel: "\(p.name) Klassenzimmer", ansicht: kopf(.schule, p, zimmer: schule, tisch: schule.tisch)))
        }
        zellen.append((titel: "Zuhause bei Nacht", ansicht: kopf(.zimmer, .annika, zimmer: zuhause, nacht: true)))
        zellen.append((titel: "Ahmed Zuhause bei Nacht", ansicht: kopf(.zimmer, .ahmed, zimmer: Zimmer(ort: .zuhause, person: .ahmed), nacht: true)))
        let geld = Zimmer(bett: 5, wand: 7, boden: 1, deko: ["ledRot", "tresor", "bargeld", "sneakerRegal", "jordanBox", "stehlampe", "teppichSchwarz", "hanteln"], poster: 17, posterLinks: 3, posterBett: 12)
        zellen.append((titel: "Ahmed Zuhause, Geld und Jordan", ansicht: kopf(.zimmer, .ahmed, zimmer: geld)))
        RenderTafel.speichern("profil-orte", spalten: 3, zellen: zellen)
    }

    /// Every deco piece alone in a plain room, half size.
    func testDekoBogen() {
        let zellen: [Zelle] = Zimmer.dekoArten.map { d in
            let z = Zimmer(deko: [d.id])
            let ansicht = ProfilSzeneHintergrund(szene: .zimmer, zimmer: z, nacht: false, animiert: false)
                .frame(width: 195, height: 215)
                .clipped()
            return (titel: d.name, ansicht: AnyView(ansicht))
        }
        RenderTafel.speichern("profil-deko", spalten: 6, zellen: zellen)
    }

    /// Every poster, large.
    func testPosterBogen() {
        let zellen: [Zelle] = Zimmer.posterAuswahl.filter { $0 > 0 }.map { i in
            let ansicht = Canvas { g, size in
                var p = g
                p.translateBy(x: size.width / 2, y: size.height / 2)
                p.scaleBy(x: 2.2, y: 2.2)
                SzenenZeichnung.posterZeichnen(p, i)
            }
            .frame(width: 140, height: 180)
            return (titel: Zimmer.posterArten[i], ansicht: AnyView(ansicht))
        }
        RenderTafel.speichern("profil-poster", spalten: 5, zellen: zellen)
        // All three spots of a home at once, with real pictures of each shape.
        let wand = Zimmer(bett: 5, wand: 6, boden: 5, deko: ["ledWeiss", "teppichSchwarz"], poster: 13, posterLinks: 18, posterBett: 19)
        let dreiPlaetze = ProfilSzeneHintergrund(szene: .zimmer, zimmer: wand, nacht: false, animiert: false).frame(width: 390, height: 430)
        RenderTafel.speichern("profil-poster-wand", spalten: 1, zellen: [(titel: "Take Care, Scorpion, SVJ", ansicht: AnyView(dreiPlaetze))])
    }
}