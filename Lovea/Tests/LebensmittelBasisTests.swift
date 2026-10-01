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

    /// Seit dem BLS-4.0-Import (Ahmed, 01.10.) über 7.000 statt 122 Einträge, alle mit `id` "bls-…".
    func testMindestens7000Eintraege() {
        XCTAssertGreaterThanOrEqual(Self.alle.count, 7000)
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

    /// Anders als bei den 122 handkuratierten Grund-Lebensmitteln hat der BLS-Import nur für
    /// Treffer in der alten JSON oder in `portionen.json` Portionsgrößen (siehe Importskript) -
    /// die meisten der 7.140 Einträge haben bewusst keine. Diese Garantie gilt daher nicht mehr.

    /// Das BLS 4.0 deckt fast jedes Lebensmittel mit Vitaminen/Mineralstoffen ab (siehe Report
    /// zu Task 2: 7135 von 7140 mit mindestens 10 Werten).
    func testFastAlleHabenMikronaehrstoffe() {
        let mitMikro = Self.alle.filter { ($0.pro100.mikro?.count ?? 0) >= 10 }
        XCTAssertGreaterThanOrEqual(mitMikro.count, 7000)
    }

    /// BLS 4.0 "Tomate roh" (G561100): Vitamin C und Kalium aus der echten Tabelle (siehe Report).
    func testTomatenVitaminCUndKalium() {
        guard let tomaten = Self.alle.first(where: { $0.id == "bls-G561100" }) else {
            return XCTFail("bls-G561100 (Tomate roh) fehlt")
        }
        let vitaminC = tomaten.pro100.wert(.vitaminC) ?? -1
        let kalium = tomaten.pro100.wert(.kalium) ?? -1
        XCTAssertTrue((20...30).contains(vitaminC), "Vitamin C \(vitaminC) nicht in 20...30")
        XCTAssertTrue((200...260).contains(kalium), "Kalium \(kalium) nicht in 200...260")
    }

    /// 4·KH + 4·Protein + 9·Fett muss 35–180 % der kcal ergeben (grosszuegig wegen des BLS-Umfangs:
    /// Ballaststoffe und organische Saeuren liefern Energie, zaehlen hier aber nicht mit). Ausgenommen:
    /// kcal < 5 (Wasser, Gewürze), Alkohol (Bier, Wein: Energie steckt nicht in den Makros) und reine
    /// Saeuren/Suessstoffe ohne nennenswerte Makros (z. B. Zitronensäure, Sorbit-Tabletten).
    func testMakroEnergieIstPlausibel() {
        for l in Self.alle where l.pro100.kcal >= 5 && (l.pro100.wert(.alkohol) ?? 0) < 0.5 {
            let n = l.pro100
            guard n.kohlenhydrate + n.protein + n.fett >= 2 else { continue }
            let energie = 4 * n.kohlenhydrate + 4 * n.protein + 9 * n.fett
            let verhaeltnis = energie / n.kcal
            XCTAssertTrue((0.35...1.80).contains(verhaeltnis),
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
