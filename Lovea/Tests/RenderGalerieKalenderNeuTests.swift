import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel des neuen Kalenders (Variante C), Beispieldaten wie im Zielbild `kalender-variante-C.png`:
/// Oktober 2026, heute Freitag 2.10., gewählt Donnerstag 8.10. Vier Zellen: Monat und Tag, hell und dunkel.
@MainActor
final class RenderGalerieKalenderNeuTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private let heute = "2026-10-02"
    private let gewaehlt = "2026-10-08"
    private let erster = "2026-10-01"

    private func termin(_ id: String, _ fuer: String, _ titel: String, _ datum: String, _ start: String? = nil, _ ende: String? = nil) -> Termin {
        Termin(id: id, fuer: [fuer], titel: titel, typ: "sonstiges", datum: datum, start: start, ende: ende)
    }

    private var daten: KalenderDaten {
        KalenderDaten(
            muster: [
                Muster(id: "m1", person: "ahmed", typ: "arbeit", titel: "Lurse", wochentage: [4], wochen: "alle", start: "08:00", ende: "16:30", ab: "2026-09-01"),
                Muster(id: "m2", person: "annika", typ: "schule", titel: "Schule", wochentage: [4], wochen: "alle", start: "08:15", ende: "13:45", ab: "2026-09-01"),
            ],
            termine: [
                termin("t1", "ahmed", "Fahrschule", "2026-10-08", "17:30", "19:00"),
                termin("t2", "annika", "Friseur", "2026-10-06"),
                termin("t3", "ahmed", "Fahrschule", "2026-10-14"),
                termin("t4", "annika", "Zahnarzt", "2026-10-23"),
                termin("t5", "ahmed", "Fahrschule", "2026-10-29"),
            ],
            treffen: [
                Treffen(datum: "2026-10-02", uhrzeit: nil, wasMachenWir: nil),
                Treffen(datum: "2026-10-08", uhrzeit: "20:00", wasMachenWir: "Pizza & Film"),
                Treffen(datum: "2026-10-10", uhrzeit: nil, wasMachenWir: nil),
                Treffen(datum: "2026-10-17", uhrzeit: nil, wasMachenWir: nil),
                Treffen(datum: "2026-10-24", uhrzeit: nil, wasMachenWir: nil),
                Treffen(datum: "2026-10-31", uhrzeit: nil, wasMachenWir: nil),
            ]
        )
    }

    /// Feste Breite, eigener Hintergrund und eigenes Farbschema: das Brett der Tafel ist immer hell.
    private func zelle(_ schema: ColorScheme, titel: String, _ inhalt: some View) -> Zelle {
        let ansicht = inhalt
            .padding(16)
            .frame(width: 393, alignment: .top)
            .background(schema == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, schema)
        return (titel: titel, ansicht: AnyView(ansicht))
    }

    private func monat() -> some View {
        let daten = self.daten
        return VStack(spacing: 16) {
            RasterMonatInhalt(
                raster: MonatsRaster(erster: erster, daten: daten), daten: daten, erster: erster,
                heute: heute, gewaehlt: gewaehlt, statisch: true
            )
            TagesBlatt(tag: gewaehlt, daten: daten, ich: .ahmed)
        }
    }

    private func tag() -> some View {
        TagNeuInhalt(tag: gewaehlt, daten: daten, heute: heute, ich: .ahmed)
    }

    func testBeispieldatenGebenDieFreienZeitenDesZielbilds() {
        let ahmed = Wochenplan.tag(gewaehlt, person: "ahmed", daten: daten)
        let annika = Wochenplan.tag(gewaehlt, person: "annika", daten: daten)

        XCTAssertEqual(TagesWerte.freiText(TagesWerte.freieZeiten(ahmed + annika)), "Gemeinsam frei 16:30–17:30, 19:00–20:00")
    }

    func testKalenderNeu() {
        RenderTafel.speichern("kalender-neu", spalten: 2, zellen: [
            zelle(.light, titel: "Monat, hell", monat()),
            zelle(.dark, titel: "Monat, dunkel", monat()),
            zelle(.light, titel: "Tag, hell", tag()),
            zelle(.dark, titel: "Tag, dunkel", tag()),
        ])
    }
}
