import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel der Treffen-Lesen-Ansicht, Beispieldaten wie im Zielbild `treffen-lesen.png`: Samstag
/// 3.10., vier Punkte, der letzte für Annika versteckt. Zellen: Ahmed (Ersteller) hell und dunkel,
/// Annika (Partner, Block ohne Inhalt) hell und dunkel, iPad breit. Der Bearbeiten-Modus ist nicht
/// dabei: `DatePicker` und `TextField` zeichnet der `ImageRenderer` nicht.
@MainActor
final class RenderGalerieTreffenTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private let datum = "2026-10-03"

    private func berlin(_ j: Int, _ m: Int, _ t: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = j; c.month = m; c.day = t; c.hour = h; c.minute = min
        return Datum.kalender.date(from: c)!
    }

    private var jetzt: Date { berlin(2026, 10, 2, 12) }

    private func ort(_ name: String) -> PunktOrt {
        PunktOrt(name: name, lat: 51.2202, lon: 6.7945, adresse: nil)
    }

    /// `ersteller` sieht den Inhalt des versteckten Punkts, der Partner nur den Platzhalter.
    private func punkte(ersteller: Bool) -> [TreffenPunkt] {
        func p(_ id: String, _ start: String, _ ende: String, _ titel: String?, _ ort: PunktOrt?, _ notiz: String?, versteckt: Bool = false) -> TreffenPunkt {
            TreffenPunkt(
                id: id, datum: datum, von: .ahmed, start: start, ende: ende, titel: titel, notiz: notiz, ort: ort,
                versteckt: versteckt, sichtbarAb: versteckt ? berlin(2026, 10, 3, 9) : nil
            )
        }
        return [
            p("1", "12:00", "14:00", "Ankommen und Mittag", ort("Düsseldorf Hauptbahnhof"), "Ich warte unten am Haupteingang."),
            p("2", "14:00", "16:30", "Altstadt", ort("Düsseldorf Altstadt"), "Kaffee, dann einfach laufen."),
            p("3", "16:30", "19:00", "Am Rhein", ort("Rheinuferpromenade"), "Eis holen, am Wasser sitzen."),
            ersteller
                ? p("4", "19:30", "22:00", "Abendessen", ort("Rheinturm"), "Tisch am Fenster.", versteckt: true)
                : p("4", "19:30", "22:00", nil, nil, nil, versteckt: true),
        ]
    }

    private let checkliste = [
        KalenderModell.ChecklistEintrag(id: "c1", text: "Tickets", erledigt: true),
        KalenderModell.ChecklistEintrag(id: "c2", text: "Ladekabel", erledigt: true),
        KalenderModell.ChecklistEintrag(id: "c3", text: "Regenjacke", erledigt: false),
        KalenderModell.ChecklistEintrag(id: "c4", text: "Geschenk", erledigt: false),
    ]

    private func lesen(ich: Person) -> some View {
        TreffenLesenInhalt(
            datum: datum, titel: "Düsseldorf", von: "12:00", bis: "22:00",
            punkte: punkte(ersteller: ich == .ahmed), ich: ich, jetzt: jetzt, vorherige: nil, checkliste: checkliste
        )
    }

    private func zelle(_ schema: ColorScheme, titel: String, breite: CGFloat = 393, _ inhalt: some View) -> Zelle {
        let ansicht = inhalt
            .padding(.vertical, 16)
            .frame(width: breite, alignment: .top)
            .background(schema == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, schema)
            .environment(\.ortVorschauEinfach, true)
        return (titel: titel, ansicht: AnyView(ansicht))
    }

    func testKopfZeigtVonBisUndDauer() {
        XCTAssertEqual(TreffenAnsichtWerte.zeitKopf(von: "12:00", bis: "22:00"), "12:00 bis 22:00")
        XCTAssertEqual(TreffenAnsichtWerte.dauerText(von: "12:00", bis: "22:00"), "10 Std.")
    }

    func testBeispielPartnerSiehtKeinenInhalt() {
        let p = punkte(ersteller: false)[3]
        XCTAssertEqual(TreffenLogik.ansicht(p, ich: .annika, jetzt: jetzt), .versteckt(ab: berlin(2026, 10, 3, 9), gleich: false))
        XCTAssertEqual(TreffenLogik.ansicht(punkte(ersteller: true)[3], ich: .ahmed, jetzt: jetzt), .voll)
    }

    func testTreffenLesen() {
        RenderTafel.speichern("treffen-lesen", spalten: 2, zellen: [
            zelle(.light, titel: "Ahmed, hell", lesen(ich: .ahmed)),
            zelle(.dark, titel: "Ahmed, dunkel", lesen(ich: .ahmed)),
            zelle(.light, titel: "Annika, hell", lesen(ich: .annika)),
            zelle(.dark, titel: "Annika, dunkel", lesen(ich: .annika)),
            zelle(.light, titel: "iPad, hell", breite: 820, lesen(ich: .ahmed).environment(\.horizontalSizeClass, .regular)),
        ])
    }
}
