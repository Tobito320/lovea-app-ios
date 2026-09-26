import XCTest
@testable import Lovea

/// Prüft `lebensmittel-basis.json` direkt aus dem Quellordner (nicht über das Bundle) und die
/// Such-Hilfsfunktion `LebensmittelBasis.treffer`.
final class LebensmittelBasisTests: XCTestCase {
    private static let jsonURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Lovea/Tests
        .appendingPathComponent("../Sources/Health/Ernaehrung/lebensmittel-basis.json")
        .standardizedFileURL

    private static let alle: [Lebensmittel] = {
        guard let daten = try? Data(contentsOf: jsonURL) else { return [] }
        return (try? JSONDecoder().decode([Lebensmittel].self, from: daten)) ?? []
    }()

    func testDatenLassenSichLaden() {
        XCTAssertFalse(Self.alle.isEmpty, "lebensmittel-basis.json nicht gefunden oder leer unter \(Self.jsonURL.path)")
    }

    func testMindestens120Eintraege() {
        XCTAssertGreaterThanOrEqual(Self.alle.count, 120)
    }

    func testIdsEindeutig() {
        let ids = Self.alle.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "doppelte ids in lebensmittel-basis.json")
    }

    func testKalorienPlausibel() {
        for l in Self.alle {
            XCTAssertGreaterThanOrEqual(l.pro100.kcal, 0, "\(l.id): kcal < 0")
            XCTAssertLessThan(l.pro100.kcal, 950, "\(l.id): kcal >= 950")
        }
    }

    func testJedesHatMindestensEinePortionMitGewicht() {
        for l in Self.alle {
            let hatPortion = (l.portionen ?? []).contains { $0.gramm > 0 }
            XCTAssertTrue(hatPortion, "\(l.id) hat keine Portion mit gramm > 0")
        }
    }

    /// Echte USDA-Laborwerte (SR Legacy): mindestens 110 der 122 Grund-Lebensmittel haben
    /// pro100.mikro mit mindestens 10 Werten (Vitamine/Mineralstoffe).
    func testMindestens110HabenMikronaehrstoffe() {
        let mitMikro = Self.alle.filter { ($0.pro100.mikro?.count ?? 0) >= 10 }
        XCTAssertGreaterThanOrEqual(mitMikro.count, 110)
    }

    /// USDA fdc_id 170457 (Tomatoes, red, ripe, raw): Vitamin C 13,7 mg, Kalium 237 mg pro 100 g.
    func testTomatenVitaminCUndKalium() {
        guard let tomaten = Self.alle.first(where: { $0.id == "basis-tomaten" }) else {
            return XCTFail("basis-tomaten fehlt")
        }
        let vitaminC = tomaten.pro100.wert(.vitaminC) ?? -1
        let kalium = tomaten.pro100.wert(.kalium) ?? -1
        XCTAssertTrue((10...20).contains(vitaminC), "Vitamin C \(vitaminC) nicht in 10...20")
        XCTAssertTrue((200...260).contains(kalium), "Kalium \(kalium) nicht in 200...260")
    }

    /// 4·KH + 4·Protein + 9·Fett muss 70–130 % der kcal ergeben, außer Getränke mit kcal < 5
    /// (Wasser, Kaffee, Tee: die Energie steckt nicht in den Makros).
    func testMakroEnergieIstPlausibel() {
        for l in Self.alle where l.pro100.kcal >= 5 {
            let n = l.pro100
            let energie = 4 * n.kohlenhydrate + 4 * n.protein + 9 * n.fett
            let verhaeltnis = energie / n.kcal
            XCTAssertTrue((0.70...1.30).contains(verhaeltnis),
                          "\(l.id): Makros ergeben \(energie) kcal, aber pro100.kcal ist \(n.kcal) (Verhältnis \(verhaeltnis))")
        }
    }

    // MARK: - Suche

    private let testListe: [Lebensmittel] = [
        Lebensmittel(id: "1", name: "Tomaten, frisch", pro100: Naehrwerte(kcal: 18, protein: 0.9, kohlenhydrate: 3.9, fett: 0.2)),
        Lebensmittel(id: "2", name: "Ei, gekocht", pro100: Naehrwerte(kcal: 155, protein: 13, kohlenhydrate: 1.1, fett: 11)),
        Lebensmittel(id: "3", name: "Erdbeeren", pro100: Naehrwerte(kcal: 32, protein: 0.7, kohlenhydrate: 7.7, fett: 0.3)),
        Lebensmittel(id: "4", name: "Käse, Gouda", pro100: Naehrwerte(kcal: 356, protein: 25, kohlenhydrate: 0, fett: 28)),
    ]

    func testTrefferWortanfangUndUmlaute() {
        XCTAssertEqual(LebensmittelBasis.treffer(testListe, "tomate").map(\.name), ["Tomaten, frisch"])
        XCTAssertEqual(LebensmittelBasis.treffer(testListe, "TOMATE").map(\.name), ["Tomaten, frisch"])
        XCTAssertEqual(LebensmittelBasis.treffer(testListe, "kase").map(\.name), ["Käse, Gouda"])
        XCTAssertEqual(LebensmittelBasis.treffer(testListe, "ei").map(\.name), ["Ei, gekocht"])
    }

    func testTrefferNamensanfangZuerst() {
        let liste = [
            Lebensmittel(id: "a", name: "Kuchen mit Apfel", pro100: Naehrwerte(kcal: 1, protein: 0, kohlenhydrate: 0, fett: 0)),
            Lebensmittel(id: "b", name: "Apfel", pro100: Naehrwerte(kcal: 1, protein: 0, kohlenhydrate: 0, fett: 0)),
        ]
        let treffer = LebensmittelBasis.treffer(liste, "apfel")
        XCTAssertEqual(treffer.first?.name, "Apfel")
    }

    func testTrefferUnter2ZeichenLeer() {
        XCTAssertTrue(LebensmittelBasis.treffer(testListe, "t").isEmpty)
        XCTAssertTrue(LebensmittelBasis.treffer(testListe, "").isEmpty)
    }

    func testTrefferOhneUebereinstimmungLeer() {
        XCTAssertTrue(LebensmittelBasis.treffer(testListe, "xyz").isEmpty)
    }
}
