import XCTest
@testable import Lovea

final class KalenderLogikTests: XCTestCase {

    // MARK: - Z-9.1 Feiertage

    func testOsterabhaengigeFeiertage2027() {
        // Ostersonntag 2027 = 28.03.2027 (Gauß) => Karfreitag 26.03., Ostermontag 29.03.
        let feiertage = Feiertage.nrw(jahr: 2027)

        XCTAssertTrue(feiertage.contains("2027-03-26"), "Karfreitag")
        XCTAssertTrue(feiertage.contains("2027-03-29"), "Ostermontag")
    }

    func testFronleichnam2026() {
        // Fronleichnam = Ostersonntag + 60 Tage = 04.06.2026
        let feiertage = Feiertage.nrw(jahr: 2026)

        XCTAssertTrue(feiertage.contains("2026-06-04"))
    }

    func testFesteFeiertage2026() {
        let feiertage = Feiertage.nrw(jahr: 2026)

        XCTAssertTrue(feiertage.contains("2026-01-01")) // Neujahr
        XCTAssertTrue(feiertage.contains("2026-05-01")) // 1. Mai
        XCTAssertTrue(feiertage.contains("2026-10-03")) // Tag der Deutschen Einheit
        XCTAssertTrue(feiertage.contains("2026-11-01")) // Allerheiligen
        XCTAssertTrue(feiertage.contains("2026-12-25"))
        XCTAssertTrue(feiertage.contains("2026-12-26"))
    }

    // MARK: - Z-9.2 Ferien

    func testHerbstferien2026() {
        XCTAssertTrue(Ferien.istFerien("2026-10-19"))
        XCTAssertFalse(Ferien.istFerien("2026-10-16"))
        XCTAssertFalse(Ferien.istFerien("2026-11-02"))
    }

    // MARK: - Z-9.3 Wochenplan.tag

    /// Ahmeds Wechselwoche: Di+Mi Schule in Woche A, nur Mi in Woche B, sonst Mo–Fr Arbeit.
    /// Annika: Schule Mo–Fr. Muster gelten „ab“ 2020, also für alle Testtage.
    private func standardDaten() -> KalenderDaten {
        KalenderDaten(muster: [
            Muster(id: "annika-schule", person: "annika", typ: "schule", titel: "Schule", wochentage: [1, 2, 3, 4, 5], wochen: "alle", start: nil, ende: nil, ab: "2020-01-01"),
            Muster(id: "ahmed-schule-a", person: "ahmed", typ: "schule", titel: "Schule", wochentage: [2, 3], wochen: "A", start: nil, ende: nil, ab: "2020-01-01"),
            Muster(id: "ahmed-schule-b", person: "ahmed", typ: "schule", titel: "Schule", wochentage: [3], wochen: "B", start: nil, ende: nil, ab: "2020-01-01"),
            Muster(id: "ahmed-arbeit-a", person: "ahmed", typ: "arbeit", titel: "Arbeit", wochentage: [1, 4, 5], wochen: "A", start: nil, ende: nil, ab: "2020-01-01"),
            Muster(id: "ahmed-arbeit-b", person: "ahmed", typ: "arbeit", titel: "Arbeit", wochentage: [1, 2, 4, 5], wochen: "B", start: nil, ende: nil, ab: "2020-01-01"),
        ])
    }

    func testAhmedDienstagWocheAIstSchule() {
        let bloecke = Wochenplan.tag("2026-09-22", person: "ahmed", daten: standardDaten())

        XCTAssertEqual(bloecke.map(\.typ), ["schule"])
    }

    func testAhmedDienstagWocheBIstArbeit() {
        let bloecke = Wochenplan.tag("2026-09-29", person: "ahmed", daten: standardDaten())

        XCTAssertEqual(bloecke.map(\.typ), ["arbeit"])
    }

    func testAnnikaInDenHerbstferienKeineSchule() {
        let bloecke = Wochenplan.tag("2026-10-19", person: "annika", daten: standardDaten())

        XCTAssertTrue(bloecke.isEmpty)
    }

    func testDritterOktoberIstFrei() {
        let daten = standardDaten()

        XCTAssertTrue(Wochenplan.tag("2026-10-03", person: "ahmed", daten: daten).isEmpty)
        XCTAssertTrue(Wochenplan.tag("2026-10-03", person: "annika", daten: daten).isEmpty)
    }

    func testFronleichnamEntferntAhmedsArbeit() {
        // 04.06.2026 ist ein Donnerstag (Feiertag) und in beiden Wechselwochen ein Arbeitstag,
        // also ist das ein echter Test dafür, dass der Feiertags-Zweig `arbeit` entfernt
        // (anders als der 3. Oktober 2026, der zufällig auch ein Samstag ist).
        let bloecke = Wochenplan.tag("2026-06-04", person: "ahmed", daten: standardDaten())

        XCTAssertTrue(bloecke.isEmpty)
    }

    func testKrankErsetztArbeit() {
        var daten = standardDaten()
        // Donnerstag 24.09.2026, Woche A: Ahmed hat Arbeit.
        daten.ausnahmen = [
            Ausnahme(person: "ahmed", datum: "2026-09-24", musterId: nil, status: "krank", bisDatum: nil, start: nil, ende: nil),
        ]

        let bloecke = Wochenplan.tag("2026-09-24", person: "ahmed", daten: daten)

        XCTAssertEqual(bloecke.count, 1)
        XCTAssertEqual(bloecke.first?.typ, "arbeit")
        XCTAssertEqual(bloecke.first?.status, "krank")
        XCTAssertEqual(bloecke.first?.ausnahme, daten.ausnahmen.first) // Z-42.2: antippen → ändern/zurücknehmen
        XCTAssertNil(Wochenplan.tag("2026-09-25", person: "ahmed", daten: daten).first?.ausnahme)
    }

    // MARK: - Z-42.1 Monatsraster

    func testMonatsRasterZeigtRoutineUndMarker() {
        var daten = standardDaten()
        daten.ausnahmen = [
            Ausnahme(person: "ahmed", datum: "2026-09-24", musterId: nil, status: "krank", bisDatum: nil, start: nil, ende: nil),
            Ausnahme(person: "annika", datum: "2026-09-25", musterId: nil, status: "verschoben", bisDatum: nil, start: "10:00", ende: "14:00"),
        ]
        daten.termine = [Termin(id: "t", fuer: ["annika"], titel: "Arzt", typ: "sonstiges", datum: "2026-09-23", start: nil, ende: nil)]
        daten.treffen = [Treffen(datum: "2026-09-26", uhrzeit: nil, wasMachenWir: "Kino")]

        let raster = MonatsRaster(erster: "2026-09-01", daten: daten)
        func zelle(_ tag: String) -> MonatsRaster.Zelle? { raster.zellen.compactMap { $0 }.first { $0.tag == tag } }

        XCTAssertEqual(raster.zellen.count, 42)
        XCTAssertNil(raster.zellen[0]) // der 1.9.2026 ist ein Dienstag
        XCTAssertEqual(raster.zellen[1]?.tag, "2026-09-01")
        XCTAssertEqual(raster.zellen.compactMap { $0 }.count, 30)
        XCTAssertEqual(zelle("2026-09-22")?.ahmed, "schule") // Di, Woche A
        XCTAssertEqual(zelle("2026-09-22")?.annika, "schule")
        XCTAssertEqual(zelle("2026-09-21")?.ahmed, "arbeit") // Mo, Woche A
        XCTAssertNil(zelle("2026-09-24")?.ahmed) // Arbeit, aber krank
        XCTAssertEqual(zelle("2026-09-25")?.annika, "schule") // verschoben findet trotzdem statt
        XCTAssertEqual(zelle("2026-09-23")?.termin, true)
        XCTAssertEqual(zelle("2026-09-22")?.termin, false)
        XCTAssertEqual(zelle("2026-09-26")?.treffen, true)
        XCTAssertNil(zelle("2026-09-26")?.ahmed) // Samstag
        XCTAssertEqual(zelle("2026-09-26")?.nummer, "26")
        XCTAssertTrue(zelle("2026-09-22")?.vorlesen(heute: true).contains("Ahmed: Schule") ?? false)
    }

    // MARK: - Z-42.2 Uhrzeit-Hilfen

    func testUhrzeitHilfen() {
        XCTAssertEqual(Datum.minuten("08:30"), 510)
        XCTAssertNil(Datum.minuten(nil))
        XCTAssertNil(Datum.minuten("ganztägig"))
        XCTAssertEqual(Datum.uhrzeit(minuten: 510), "08:30")
        XCTAssertEqual(Datum.uhrzeit("10:00", plus: 90), "11:30")
        XCTAssertEqual(Datum.uhrzeit("22:30", plus: 180), "23:59") // endet am selben Tag
        // Zeitumstellung am 25.10.2026: die Uhrzeit bleibt in Berlin dieselbe.
        XCTAssertEqual(Datum.uhrzeit(IPhoneKalenderDatum.kombiniert("2026-10-25", "18:15")), "18:15")
    }

    // MARK: - Z-9.7 DateVorschlag.naechste

    func testNaechsteDreiFreienAbende() {
        var daten = KalenderDaten(muster: [
            Muster(id: "annika-schule", person: "annika", typ: "schule", titel: "Schule", wochentage: [1, 2, 3, 4, 5], wochen: "alle", start: "08:00", ende: "13:00", ab: "2020-01-01"),
            Muster(id: "ahmed-arbeit", person: "ahmed", typ: "arbeit", titel: "Arbeit", wochentage: [1, 2, 3, 4, 5], wochen: "alle", start: "08:00", ende: "16:00", ab: "2020-01-01"),
        ])
        daten.termine = [
            // Mittwoch 23.09.: Ahmed abends beschäftigt.
            Termin(id: "t1", fuer: ["ahmed"], titel: "Elternabend", typ: "sonstiges", datum: "2026-09-23", start: "18:00", ende: "20:00"),
            // Donnerstag 24.09.: Annika den ganzen Tag beschäftigt (kein Ende).
            Termin(id: "t2", fuer: ["annika"], titel: "Geburtstag Freundin", typ: "sonstiges", datum: "2026-09-24", start: nil, ende: nil),
        ]

        let vorschlaege = DateVorschlag.naechste(daten: daten, ab: "2026-09-23")

        XCTAssertEqual(vorschlaege, ["2026-09-25", "2026-09-26", "2026-09-27"])
    }

    func testUrlaubGiltAlsAbendFrei() {
        // Ganztägige Muster ohne Uhrzeiten (Standardzustand vor Z-9.4) wären ohne die
        // Ausnahme "belegt". Urlaub macht den Tag trotzdem zu einem gültigen Vorschlag.
        var daten = standardDaten()
        daten.ausnahmen = [
            Ausnahme(person: "ahmed", datum: "2026-09-24", musterId: nil, status: "urlaub", bisDatum: nil, start: nil, ende: nil),
            Ausnahme(person: "annika", datum: "2026-09-24", musterId: nil, status: "urlaub", bisDatum: nil, start: nil, ende: nil),
        ]

        let vorschlaege = DateVorschlag.naechste(daten: daten, ab: "2026-09-24")

        XCTAssertTrue(vorschlaege.contains("2026-09-24"))
    }
}
