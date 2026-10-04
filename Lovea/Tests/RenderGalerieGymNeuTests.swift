import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel des neuen Gym-Bereichs, zum Vergleich mit dem Entwurf `Lovea-bilder/gym-entwurf.html`
/// (Woche A, Einchecken A, Splits A, Neuer Tag A). Heute = Freitag 2.10.2026, 15:19.
@MainActor
final class RenderGalerieGymNeuTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private let jetzt = Datum.datum("2026-10-02").addingTimeInterval(15 * 3600 + 19 * 60)

    private func zelle(_ schema: ColorScheme, titel: String, _ inhalt: some View) -> Zelle {
        let ansicht = inhalt
            .padding(18)
            .frame(width: 393, alignment: .top)
            .background(schema == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, schema)
        return (titel: titel, ansicht: AnyView(ansicht))
    }

    private func einheit(_ id: String, tag: String, uhr: Double, minuten: Double, saetze: Int) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(uhr * 3600)
        let lauf = UebungsLauf(plan: "p", uebung: "EIeI8Vf", start: start, ende: start + 600, fertig: true,
                               saetze: Array(repeating: PlanSatz(wdh: 10, kg: 40, failure: false), count: saetze))
        return GymSession(id: id, tag: nil, start: start, ende: start + minuten * 60, laeufe: [lauf])
    }

    private func plan(_ p: Person) -> TrainingsPlan {
        guard let v = SplitLogik.fuer(p).first else { return .leer }
        var n = 0
        return SplitLogik.alsPlan(v) { n += 1; return "\(p.rawValue)\(n)" }
    }

    private func stand(_ gewaehlt: String) -> GymStartStand {
        GymStartStand.bauen(
            ich: .ahmed,
            sessions: [
                .ahmed: [einheit("a1", tag: "2026-09-28", uhr: 18, minuten: 62, saetze: 18), einheit("a2", tag: "2026-09-29", uhr: 18, minuten: 58, saetze: 17), einheit("a3", tag: "2026-10-01", uhr: 18, minuten: 65, saetze: 19)],
                .annika: [einheit("b1", tag: "2026-09-28", uhr: 16, minuten: 50, saetze: 15), einheit("b2", tag: "2026-09-30", uhr: 16, minuten: 48, saetze: 14), einheit("b3", tag: "2026-10-02", uhr: 14.3, minuten: 54, saetze: 27)],
            ],
            plaene: [.ahmed: plan(.ahmed), .annika: plan(.annika)], gewaehlt: gewaehlt, jetzt: jetzt
        )
    }

    func testStandAusBeispieldaten() {
        let heute = stand("2026-10-02")
        XCTAssertEqual(heute.knopf, .starten)
        XCTAssertEqual(heute.statusPartner, "54 min · 27 Sätze")
        XCTAssertEqual(heute.statusIch, "noch nicht")
        XCTAssertEqual(heute.woche.tage.map(\.fertig), [true, true, false, true, false, false, false])
        XCTAssertNil(stand("2026-10-03").knopf, "Kapsel nur heute")
        XCTAssertEqual(heute.planTage, SplitLogik.fuer(.ahmed).first?.tage)
    }

    func testGymNeu() {
        let ahmed = plan(.ahmed)
        RenderTafel.speichern("gym-neu", spalten: 2, zellen: [
            zelle(.dark, titel: "Gym, heute, dunkel", GymStartInhalt(stand: stand("2026-10-02"))),
            zelle(.light, titel: "Gym, heute, hell", GymStartInhalt(stand: stand("2026-10-02"))),
            zelle(.dark, titel: "Gym, Mittwoch gewählt", GymStartInhalt(stand: stand("2026-09-30"))),
            zelle(.light, titel: "Gym, Sonntag (Ruhetag)", GymStartInhalt(stand: stand("2026-10-04"))),
            zelle(.dark, titel: "Splits, Ahmed", SplitBibliothekInhalt(person: .ahmed, splits: Array(SplitLogik.fuer(.ahmed).prefix(6)), planLeer: false)),
            zelle(.light, titel: "Splits, Ahmed, Für dich", SplitBibliothekInhalt(person: .ahmed, splits: SplitLogik.fuer(.ahmed), planLeer: false, art: "fuerdich")),
            zelle(.light, titel: "Splits, Annika, 4 Tage", SplitBibliothekInhalt(person: .annika, splits: SplitLogik.fuer(.annika), planLeer: true, filter: 4)),
            zelle(.dark, titel: "Vorschau", SplitVorschauInhalt(vorlage: SplitLogik.fuer(.annika).first ?? SplitKatalog.alle[0])),
            zelle(.dark, titel: "Split-Tag, Sätze offen", SplitEditorInhalt(plan: ahmed, tagId: ahmed.tage.first?.id, offen: ahmed.tage.first?.uebungen.first?.id)),
        ])
    }
}
