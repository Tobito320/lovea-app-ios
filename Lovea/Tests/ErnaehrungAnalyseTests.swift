import XCTest
@testable import Lovea

/// Reine Logik der Auswertung: Bucket-Bildung, Schnitt nur über Tage mit Einträgen, Serie,
/// Prozent der EU-Referenz. Ohne Modell, ohne Singletons.
final class ErnaehrungAnalyseTests: XCTestCase {
    // MARK: - Tage und Buckets

    func testTageAeltesteZuerst() {
        let tage = AnalyseLogik.tage(bis: "2026-09-10", anzahl: 3)
        XCTAssertEqual(tage, ["2026-09-08", "2026-09-09", "2026-09-10"])
    }

    func testBucketsProTag() {
        let tage = AnalyseLogik.tage(bis: "2026-09-10", anzahl: 3)
        let buckets = AnalyseLogik.buckets(tage, gruppierung: .tag)
        XCTAssertEqual(buckets.count, 3)
        XCTAssertEqual(buckets.map(\.start), tage)
        XCTAssertEqual(buckets[0].tage, ["2026-09-08"])
    }

    func testBucketsProWoche() {
        // 2026-09-21 ist ein Montag (siehe Datum.wechselwoche), also zwei volle Wochen ab dort.
        let tage = AnalyseLogik.tage(bis: "2026-10-04", anzahl: 14)
        let buckets = AnalyseLogik.buckets(tage, gruppierung: .woche)
        XCTAssertEqual(buckets.count, 2)
        XCTAssertEqual(buckets[0].start, "2026-09-21")
        XCTAssertEqual(buckets[0].tage.count, 7)
        XCTAssertEqual(buckets[1].start, "2026-09-28")
        XCTAssertEqual(buckets[1].tage.count, 7)
    }

    func testBucketsProMonat() {
        let tage = AnalyseLogik.tage(bis: "2026-10-05", anzahl: 40)
        let buckets = AnalyseLogik.buckets(tage, gruppierung: .monat)
        XCTAssertEqual(buckets.map(\.start), ["2026-08", "2026-09", "2026-10"])
    }

    // MARK: - Schnitt

    func testBucketSchnittNurTageMitWerten() {
        let bucket = AnalyseBucket(start: "2026-09-08", tage: ["2026-09-08", "2026-09-09", "2026-09-10"])
        let werte = ["2026-09-08": 2000.0, "2026-09-10": 1000.0]
        XCTAssertEqual(AnalyseLogik.bucketSchnitt(bucket, werte) ?? 0, 1500, accuracy: 0.001)
    }

    func testBucketSchnittOhneWerteIstNil() {
        let bucket = AnalyseBucket(start: "2026-09-08", tage: ["2026-09-08"])
        XCTAssertNil(AnalyseLogik.bucketSchnitt(bucket, [:]))
    }

    func testSchnittUeberAlleTageMitWerten() {
        let werte = ["a": 100.0, "b": 200.0, "c": 300.0]
        XCTAssertEqual(AnalyseLogik.schnitt(werte), 200, accuracy: 0.001)
        XCTAssertEqual(AnalyseLogik.schnitt([:]), 0)
    }

    func testTageImZiel() {
        // Ziel 2000, ±10 % = 1800...2200.
        let werte = [1900.0, 2100.0, 2500.0, 1500.0]
        XCTAssertEqual(AnalyseLogik.tageImZiel(werte, ziel: 2000), 2)
        XCTAssertEqual(AnalyseLogik.tageImZiel(werte, ziel: 0), 0)
    }

    // MARK: - Prozent der Referenz

    func testProzentReferenz() {
        XCTAssertEqual(AnalyseLogik.prozentReferenz(40, .vitaminC) ?? 0, 50, accuracy: 0.001) // Referenz 80
        XCTAssertNil(AnalyseLogik.prozentReferenz(10, .natrium)) // keine Referenz
    }

    // MARK: - Serie

    func testSerieZaehltRueckwaertsBisZurLuecke() {
        let tage: Set<String> = ["2026-09-08", "2026-09-09", "2026-09-10"]
        XCTAssertEqual(AnalyseLogik.serie(tage, heute: "2026-09-10"), 3)
        XCTAssertEqual(AnalyseLogik.serie(tage, heute: "2026-09-12"), 0)
    }

    func testSerieHeuteNochOffenZaehltAbGestern() {
        let tage: Set<String> = ["2026-09-08", "2026-09-09"]
        // Heute (09-10) noch nichts eingetragen, die Serie reißt deshalb noch nicht.
        XCTAssertEqual(AnalyseLogik.serie(tage, heute: "2026-09-10"), 2)
    }

    func testSerieLeerOhneEintraege() {
        XCTAssertEqual(AnalyseLogik.serie([], heute: "2026-09-10"), 0)
    }

    // MARK: - Beschriftung

    func testLabelProTagUndMonat() {
        let tagBucket = AnalyseBucket(start: "2026-09-08", tage: ["2026-09-08"])
        XCTAssertEqual(AnalyseLogik.label(tagBucket, .tag), "8")
        let monatBucket = AnalyseBucket(start: "2026-09", tage: [])
        XCTAssertFalse(AnalyseLogik.label(monatBucket, .monat).isEmpty)
    }
}
