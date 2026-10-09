import SwiftUI
import UIKit
import XCTest
@testable import Lovea

/// Example data for the Verlauf tests and board. "Heute" is Wednesday 2026-09-23 (week 21. to 27.).
private enum VerlaufBeispiel {
    static let heute = "2026-09-23"

    static let bank = Uebung(id: "bank", name: "Bankdrücken mit Langhantel", en: "barbell bench press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: ["Trizeps", "Schultern"])
    static let curl = Uebung(id: "curl", name: "Bizeps-Curls mit Kurzhanteln", en: "dumbbell biceps curl", muskel: "Bizeps", koerper: "Oberarme", geraet: "Kurzhantel", neben: ["Unterarme"])
    static let beuge = Uebung(id: "beuge", name: "Kniebeuge mit Langhantel", en: "barbell squat", muskel: "Quadrizeps", koerper: "Beine", geraet: "Langhantel", neben: ["Po"])
    static let laufband = Uebung(id: "laufband", name: "Laufband", en: "treadmill", muskel: "Herz-Kreislauf", koerper: "Cardio", geraet: "Laufband", neben: [])

    static func katalog(_ id: String) -> Uebung? { [bank, curl, beuge, laufband].first { $0.id == id } }

    static func zeit(_ tag: String, _ stunde: Double = 18) -> Date { Datum.datum(tag).addingTimeInterval(stunde * 3600) }

    static func lauf(_ u: Uebung, _ saetze: [(kg: Double, wdh: Int)]) -> UebungsLauf {
        UebungsLauf(plan: u.id, uebung: u.id, start: nil, ende: nil, fertig: true,
                    saetze: saetze.map { PlanSatz(wdh: $0.wdh, kg: $0.kg, failure: false) })
    }

    static func session(_ id: String, _ tag: String, _ laeufe: [UebungsLauf]) -> GymSession {
        GymSession(id: id, tag: nil, start: zeit(tag), ende: zeit(tag, 19), laeufe: laeufe)
    }

    static let sessions: [GymSession] = [
        session("s4", "2026-09-23", [lauf(curl, [(14, 10), (14, 9), (14, 8)])]),
        session("s2", "2026-09-21", [lauf(bank, [(65, 8), (65, 8), (65, 7)]), lauf(beuge, [(80, 8), (80, 8), (80, 8), (80, 6)])]),
        session("s1", "2026-09-16", [lauf(bank, [(60, 10), (62.5, 8), (62.5, 8)]), lauf(curl, [(12, 12), (14, 10), (14, 8)])]),
        session("s0", "2026-09-02", [lauf(bank, [(60, 8), (60, 8), (60, 8)])]),
        session("s3", "2026-08-26", [
            lauf(beuge, [(70, 10), (70, 10), (70, 10)]),
            UebungsLauf(plan: "l", uebung: "laufband", start: nil, ende: nil, fertig: true, saetze: nil),
        ]),
    ]

    static var laeufe: [VerlaufLogik.Lauf] { VerlaufLogik.laeufe(sessions, katalog: katalog) }
}

final class VerlaufLogikTests: XCTestCase {
    private typealias B = VerlaufBeispiel

    func testLeereEingabeGibtNichts() {
        XCTAssertEqual(VerlaufLogik.laeufe([]), [])
        XCTAssertTrue(VerlaufLogik.gruppen([], heute: B.heute).isEmpty)
        XCTAssertTrue(VerlaufLogik.uebungen(.brust, [], heute: B.heute).isEmpty)
    }

    func testCardioEigeneUndUnfertigeZaehlenNicht() {
        let unfertig = UebungsLauf(plan: "b", uebung: "bank", start: nil, ende: nil, fertig: false, saetze: [PlanSatz(wdh: 8, kg: 60, failure: false)])
        let eigen = UebungsLauf(plan: "e", uebung: "eigen", start: nil, ende: nil, fertig: true, saetze: [PlanSatz(wdh: 8, kg: 60, failure: false)])
        let laufband = UebungsLauf(plan: "l", uebung: "laufband", start: nil, ende: nil, fertig: true, saetze: [PlanSatz(wdh: 8, kg: nil, failure: false)])
        let s = B.session("x", B.heute, [unfertig, eigen, laufband])
        XCTAssertEqual(VerlaufLogik.laeufe([s], katalog: B.katalog), [])
    }

    func testLaeufeAelteresZuerst() {
        XCTAssertEqual(B.laeufe.map(\.tag), ["2026-08-26", "2026-09-02", "2026-09-16", "2026-09-16", "2026-09-21", "2026-09-21", "2026-09-23"])
    }

    func testGruppeBrust() {
        let z = VerlaufLogik.gruppen(B.laeufe, heute: B.heute)[.brust]
        XCTAssertEqual(z?.gesamt.einheiten, 3)
        XCTAssertEqual(z?.gesamt.saetze, 9)
        XCTAssertEqual(z?.monat.einheiten, 3)
        XCTAssertEqual(z?.woche.einheiten, 1)
        XCTAssertEqual(z?.woche.saetze, 3)
    }

    func testHelfendeMuskelnZaehlenHalb() {
        let z = VerlaufLogik.gruppen(B.laeufe, heute: B.heute)
        XCTAssertEqual(z[.trizeps]?.gesamt.saetze, 4.5)
        XCTAssertEqual(z[.trizeps]?.woche.saetze, 1.5)
        XCTAssertEqual(z[.unterarme]?.gesamt.saetze, 3)
    }

    func testBeineSummeUeberTeile() {
        let z = VerlaufLogik.gruppen(B.laeufe, heute: B.heute)[.beine]
        XCTAssertEqual(z?.gesamt.einheiten, 2)
        XCTAssertEqual(z?.gesamt.saetze, 10.5)
        XCTAssertEqual(z?.monat.einheiten, 1)
        XCTAssertEqual(z?.monat.saetze, 6)
        XCTAssertEqual(z?.woche.saetze, 6)
    }

    func testUntrainierteGruppeFehlt() {
        XCTAssertNil(VerlaufLogik.gruppen(B.laeufe, heute: B.heute)[.nacken])
    }

    func testWochenwechselAmMontag() {
        let sonntag = B.session("so", "2026-09-20", [B.lauf(B.bank, [(60, 8)])])
        let sonntagSpaet = GymSession(id: "so", tag: nil, start: B.zeit("2026-09-20", 23.98), ende: nil, laeufe: sonntag.laeufe)
        let montag = GymSession(id: "mo", tag: nil, start: B.zeit("2026-09-21", 0), ende: nil, laeufe: sonntag.laeufe)
        let laeufe = VerlaufLogik.laeufe([sonntagSpaet, montag], katalog: B.katalog)
        let z = VerlaufLogik.gruppen(laeufe, heute: "2026-09-21")[.brust]
        XCTAssertEqual(z?.woche.einheiten, 1)
        XCTAssertEqual(z?.monat.einheiten, 2)
    }

    func testUebungBank() {
        let v = VerlaufLogik.uebung(B.bank, B.laeufe, heute: B.heute)
        XCTAssertEqual(v.monat, 3)
        XCTAssertEqual(v.gesamt, 3)
        XCTAssertEqual(v.tage.map(\.tag), ["2026-09-21", "2026-09-16", "2026-09-02"])
        XCTAssertEqual(v.tage.first?.text, "65 × 8 · 65 × 8 · 65 × 7")
        XCTAssertEqual(v.tage[1].text, "60 × 10 · 62,5 × 8 · 62,5 × 8")
        XCTAssertEqual(v.e1rm ?? 0, 65 * (1 + 8.0 / 30), accuracy: 0.001)
    }

    func testUebungVormonatZaehltNurInsgesamt() {
        let v = VerlaufLogik.uebung(B.beuge, B.laeufe, heute: B.heute)
        XCTAssertEqual(v.monat, 1)
        XCTAssertEqual(v.gesamt, 2)
    }

    func testUebungenEinerGruppe() {
        XCTAssertEqual(VerlaufLogik.uebungen(.brust, B.laeufe, heute: B.heute).map(\.id), ["bank"])
        XCTAssertEqual(VerlaufLogik.uebungen(.unterarme, B.laeufe, heute: B.heute).map(\.id), ["curl"])
        XCTAssertTrue(VerlaufLogik.uebungen(.nacken, B.laeufe, heute: B.heute).isEmpty)
    }

    func testE1RM() {
        XCTAssertNil(VerlaufLogik.e1rm(PlanSatz(wdh: 8, kg: nil, failure: false)))
        XCTAssertNil(VerlaufLogik.e1rm(PlanSatz(wdh: 8, kg: 0, failure: false)))
        XCTAssertEqual(VerlaufLogik.e1rm(PlanSatz(wdh: 1, kg: 100, failure: false)), 100)
        XCTAssertEqual(VerlaufLogik.e1rm(PlanSatz(wdh: 30, kg: 10, failure: false)) ?? 0, 20, accuracy: 0.001)
    }

    func testSatzUndZahlText() {
        XCTAssertEqual(VerlaufLogik.satzText(PlanSatz(wdh: 8, kg: 62.5, failure: false)), "62,5 × 8")
        XCTAssertEqual(VerlaufLogik.satzText(PlanSatz(wdh: 8, kg: 60, failure: false)), "60 × 8")
        XCTAssertEqual(VerlaufLogik.satzText(PlanSatz(wdh: 12, kg: nil, failure: false)), "12 Wdh")
        XCTAssertEqual(VerlaufLogik.zahl(4.5), "4,5")
        XCTAssertEqual(VerlaufLogik.saetzeText(1), "1 Satz")
        XCTAssertEqual(VerlaufLogik.saetzeText(0), "0 Sätze")
    }
}

/// Render board "verlauf": group tiles, empty state, a group page and an exercise page. Light and dark.
@MainActor
final class RenderGalerieVerlaufTests: XCTestCase {
    private typealias B = VerlaufBeispiel

    private func zelle(_ titel: String, _ ansicht: some View, _ schema: ColorScheme = .light) -> (titel: String, ansicht: AnyView) {
        (titel, AnyView(ansicht.frame(width: 390).background(Color(uiColor: .systemBackground)).environment(\.colorScheme, schema)))
    }

    private func gruppe(_ g: MuskelGruppe) -> VerlaufGruppe {
        let jetzt = B.zeit(B.heute, 20)
        return VerlaufGruppe(
            gruppe: g, laeufe: B.laeufe, heute: B.heute,
            wochenSaetze: MuskelLogik.wochenSaetze(B.sessions, woche: B.heute, katalog: B.katalog),
            erholung: MuskelLogik.erholung(B.sessions, jetzt: jetzt, katalog: B.katalog)
        )
    }

    func testVerlauf() {
        let bank = VerlaufLogik.uebung(B.bank, B.laeufe, heute: B.heute)
        RenderTafel.speichern("verlauf", spalten: 4, zellen: [
            zelle("Kacheln, hell", VerlaufInhalt(laeufe: B.laeufe, heute: B.heute)),
            zelle("Kacheln, dunkel", VerlaufInhalt(laeufe: B.laeufe, heute: B.heute), .dark),
            zelle("Leer, hell", VerlaufInhalt(laeufe: [], heute: B.heute)),
            zelle("Leer, dunkel", VerlaufInhalt(laeufe: [], heute: B.heute), .dark),
            zelle("Gruppe Beine, hell", gruppe(.beine)),
            zelle("Gruppe Brust, dunkel", gruppe(.brust), .dark),
            zelle("Gruppe ohne Übung (Nacken), hell", gruppe(.nacken)),
            zelle("Übung Bankdrücken, hell", VerlaufUebung(verlauf: bank)),
            zelle("Übung Bankdrücken, dunkel", VerlaufUebung(verlauf: bank), .dark),
        ])
    }
}
