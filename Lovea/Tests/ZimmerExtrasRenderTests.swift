import SwiftUI
import XCTest
@testable import Lovea

/// p63: das Zuhause mit den Extras zu verschiedenen Anlässen, dazu Globus, Albumseite, Würfel und Feier.
/// Die Bühne steht fest (kein Treiber), jede Zelle ist ein Standbild.
@MainActor
final class ZimmerExtrasRenderTests: XCTestCase {
    private let jahrestag = Datum.datum("2026-08-26")

    private func raum(_ tag: String, _ zeit: Tageszeit = .tag, treffen: Int? = nil, pins: [GlobusPin] = [], augen: Int = 5) -> AnyView {
        let tagDatum = Datum.datum(tag)
        let stand = ZimmerExtrasStand(
            deko: ZimmerDeko.fuer(tag: tagDatum, jahrestag: jahrestag),
            countdown: treffen.map { ($0 == 0 ? ZimmerCountdown.Stand.heute : ZimmerCountdown.Stand.noch($0)) } ?? ZimmerCountdown.Stand.keins,
            treffen: nil, pins: pins, augen: augen
        )
        let fest = ZuhauseSzenenstand(zeit: zeit, ZuhauseAblauf.aufstellung(zeit, schritt: 0), mitGeste: true)
        let szene = ZuhauseBuehne(extras: stand, fest: fest) { f in
            FigurView(.standard(for: f.person), zustand: f.zustand, groesse: f.groesse, animiert: false, ganzkoerper: f.ganzkoerper)
        } paar: {
            EmptyView()
        }
        return AnyView(szene.frame(width: 390, height: 430).clipped())
    }

    private let pins = [
        GlobusPin(id: "paris", name: "Paris", lat: 48.85, lon: 2.35, besucht: true),
        GlobusPin(id: "rom", name: "Rom", lat: 41.9, lon: 12.5, besucht: true),
        GlobusPin(id: "tokio", name: "Tokio", lat: 35.7, lon: 139.7, besucht: false),
        GlobusPin(id: "ny", name: "New York", lat: 40.7, lon: -74, besucht: false),
        GlobusPin(id: "kapstadt", name: "Kapstadt", lat: -33.9, lon: 18.4, besucht: false),
        GlobusPin(id: "sydney", name: "Sydney", lat: -33.9, lon: 151.2, besucht: false),
    ]

    private func globus() -> AnyView {
        let pins = self.pins
        return AnyView(Canvas { g, _ in
            ZimmerGlobusZeichnung.zeichne(g, mitte: CGPoint(x: 195, y: 215), radius: 150, zentrum: ZimmerGlobus.mitte(pins), pins: pins)
        }
        .frame(width: 390, height: 430)
        .background(Color(red: 0.95, green: 0.92, blue: 0.88)))
    }

    private func album() -> AnyView {
        let monat = AlbumMonat(
            id: "2026-09", titel: "September 2026",
            fotos: ["a", "b", "c", "d"].map { AlbumFoto(medium: ChatModell.MedienEintrag(id: $0, typ: "foto", breite: 100, hoehe: 100), eigene: true) },
            saetze: [AlbumSatz(id: "1", text: "Ich vermisse dich", von: .annika), AlbumSatz(id: "2", text: "Bis Samstag, Schatz", von: .ahmed)]
        )
        return AnyView(ZimmerAlbumSeite(monat: monat)
            .frame(width: 390, height: 430)
            .background(Color(red: 0.99, green: 0.96, blue: 0.91)))
    }

    private func wuerfel() -> AnyView {
        AnyView(Canvas { g, _ in
            for n in 1...6 {
                ZimmerWuerfelZeichnung.zeichne(g, mitte: CGPoint(x: 40 + CGFloat(n - 1) * 62, y: 60), kante: 40, augen: n, drehung: 0.22)
            }
        }
        .frame(width: 390, height: 120)
        .background(Color(red: 0.95, green: 0.92, blue: 0.88)))
    }

    private func feier() -> AnyView {
        AnyView(ZStack {
            raum("2026-10-15", treffen: 0)
            ZimmerFeierBild(fortschritt: 0.45).frame(width: 390, height: 430)
        })
    }

    func testExtrasBrett() {
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Ahmeds Geburtstag 27.02.", ansicht: raum("2026-02-27", treffen: 12)),
            (titel: "Annikas Geburtstag 06.06. (Abend)", ansicht: raum("2026-06-06", .abend)),
            (titel: "Jahrestag 26.08.2027", ansicht: raum("2027-08-26")),
            (titel: "Monatstag 26.10.", ansicht: raum("2026-10-26", treffen: 5)),
            (titel: "Valentinstag", ansicht: raum("2026-02-14")),
            (titel: "Ostern", ansicht: raum("2026-04-05")),
            (titel: "Frühling", ansicht: raum("2026-04-20", .morgen)),
            (titel: "Sommer", ansicht: raum("2026-07-15", pins: pins)),
            (titel: "Herbst, noch 3 Tage", ansicht: raum("2026-10-08", treffen: 3, pins: pins)),
            (titel: "Halloween, heute Wiedersehen", ansicht: raum("2026-10-31", .abend, treffen: 0)),
            (titel: "Nikolaus", ansicht: raum("2026-12-06")),
            (titel: "Advent (3. Kerze)", ansicht: raum("2026-12-13", .abend)),
            (titel: "Weihnachten (Nacht)", ansicht: raum("2026-12-24", .nacht)),
            (titel: "Silvester", ansicht: raum("2026-12-31", .nacht)),
            (titel: "Neujahr", ansicht: raum("2027-01-01", .morgen)),
            (titel: "Winter, Schnee", ansicht: raum("2026-01-15", treffen: 1)),
            (titel: "Globus mit Wunschliste", ansicht: globus()),
            (titel: "Albumseite", ansicht: album()),
            (titel: "Würfel 1 bis 6", ansicht: wuerfel()),
            (titel: "Feier am Wiedersehen (Bild bei 45 %)", ansicht: feier()),
        ]
        RenderTafel.speichern("p63-extras", spalten: 4, zellen: zellen)
    }
}
