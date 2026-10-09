import XCTest
@testable import Lovea

final class LebensmittelIndexTests: XCTestCase {
    private func l(_ id: String, _ name: String) -> Lebensmittel {
        Lebensmittel(id: id, name: name, pro100: Naehrwerte(kcal: 100, protein: 1, kohlenhydrate: 1, fett: 1),
                     suche: LebensmittelBasis.normal(name))
    }

    func testNormalUmlauteUndEszett() {
        XCTAssertEqual(LebensmittelBasis.normal("Käse, Gouda"), "kase gouda")
        XCTAssertEqual(LebensmittelBasis.normal("Grieß"), "griess")
    }

    /// Gleiche 5 Zufallsnamen wie `suchschluessel()` in `tools/bls-import/bls_import.py` lieferte
    /// (per `random.seed(1)` aus `lebensmittel-basis.json`), damit Swift und Python wirklich dasselbe rechnen.
    func testNormalStimmtMitPythonSuchschluesselUeberein() {
        XCTAssertEqual(LebensmittelBasis.normal("Frischkäsezubereitung mind. 50 % Fett i. Tr., mit Gemüse/Kräutern"),
                       "frischkasezubereitung mind 50 fett i tr mit gemuse krautern")
        XCTAssertEqual(LebensmittelBasis.normal("Kartoffel-Gemüsesuppe mit Gemüsebrühe"),
                       "kartoffel gemusesuppe mit gemusebruhe")
        XCTAssertEqual(LebensmittelBasis.normal("Teufelssauce/Grillsauce"), "teufelssauce grillsauce")
        XCTAssertEqual(LebensmittelBasis.normal("Rührei gebraten mit Käse und Kochschinken"),
                       "ruhrei gebraten mit kase und kochschinken")
        XCTAssertEqual(LebensmittelBasis.normal("Eier-Frischteigwaren Spätzle mit Gulasch einfach (mit Rindfleisch)"),
                       "eier frischteigwaren spatzle mit gulasch einfach mit rindfleisch")
    }

    func testUmlautSucheFindetGleiches() {
        let liste = [l("1", "Käse, Gouda"), l("2", "Grießbrei"), l("3", "Kakao")]
        for q in ["käse", "kase", "Käse"] { XCTAssertEqual(LebensmittelBasis.treffer(liste, q).first?.id, "1", q) }
        for q in ["griess", "Grieß"] { XCTAssertEqual(LebensmittelBasis.treffer(liste, q).first?.id, "2", q) }
    }

    /// Deutsche Komposita hängen das Hauptwort hinten an ("Hühner-ei"): "ei" muss das auch über das
    /// Wortende finden, aber ein Name, der mit "Ei" beginnt, steht davor (Rang 1 vor Rang 3).
    func testSuffixSucheFindetHuehnereiUndRanktNamensanfangZuerst() {
        let liste = [l("1", "Hühnerei, gekocht"), l("2", "Ei, gekocht")]
        let treffer = LebensmittelBasis.treffer(liste, "ei")
        XCTAssertEqual(treffer.map(\.id), ["2", "1"], "Ei, gekocht (Namensanfang) muss vor Hühnerei (nur Suffix) stehen")
    }

    /// Edge Cases aus den globalen Vorgaben, gegen die echte `suchschluessel()` in
    /// `tools/bls-import/bls_import.py` gerechnet (siehe Fix-Report): Akzente wie `è`/`î` fallen weg,
    /// ein Apostroph zählt wie jedes andere Satzzeichen als Worttrenner.
    func testCremeFraicheUndApostroph() {
        XCTAssertEqual(LebensmittelBasis.normal("Crème fraîche"), "creme fraiche")
        XCTAssertEqual(LebensmittelBasis.normal("Kellogg's Cornflakes"), "kellogg s cornflakes")
    }

    /// Nicht-blockierendes An/Aus-Signal für die Race-Tests unten: `warten()` hängt sich per
    /// `withCheckedContinuation` ein, statt (wie ein `DispatchSemaphore`) einen Thread zu belegen.
    /// Das ist der eigentliche Fix gegen die CI-Flakiness: ein blockierter Test-Thread konnte auf
    /// einem ausgelasteten Simulator dem `.utility`-`Task.detached` die Ausführung streitig machen,
    /// ein `await` dagegen gibt den Thread sofort zurück an den Scheduler.
    private actor AsyncSignal {
        private var ausgeloest = false
        private var wartende: [CheckedContinuation<Void, Never>] = []

        func signalisieren() {
            guard !ausgeloest else { return }
            ausgeloest = true
            wartende.forEach { $0.resume() }
            wartende.removeAll()
        }

        func warten() async {
            if ausgeloest { return }
            await withCheckedContinuation { wartende.append($0) }
        }
    }

    /// Wartet über eine `XCTestExpectation` (großzügiges Timeout statt Hängenbleiben) auf ein
    /// `AsyncSignal`, ohne dabei selbst zu blockieren.
    private func warte(auf signal: AsyncSignal, _ beschreibung: String) async {
        let erwartung = expectation(description: beschreibung)
        Task { await signal.warten(); erwartung.fulfill() }
        await fulfillment(of: [erwartung], timeout: 30)
    }

    /// Verlässt der Nutzer den Bildschirm (`freigeben()`), während ein `laden()` noch im Hintergrund
    /// läuft, darf das spät eintreffende Ergebnis die Daten nicht wieder befüllen (Generation-Zähler).
    func testFreigebenWaehrendLadenVerwirftErgebnis() async {
        let index = LebensmittelIndex()
        let spaeteDaten = [l("x", "Testlebensmittel")]
        let gestartet = AsyncSignal()
        let weiter = AsyncSignal()

        index.laden(lader: {
            await gestartet.signalisieren()
            await weiter.warten()
            return spaeteDaten
        }, prioritaet: .userInitiated)
        await warte(auf: gestartet, "Ladevorgang gestartet")

        index.freigeben()
        await weiter.signalisieren()

        // Nicht-blockierend abwarten, bis der Abschlussblock (Generation-Prüfung) gelaufen ist.
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(index.bereit, "freigeben() waehrend des Ladens darf die alten Daten nicht zurueckholen")
    }

    /// Thread-sicherer Aufruf-Zähler für den Race-Test unten: `Task.detached` läuft auf einem
    /// Hintergrund-Thread, ein simples `var` wäre eine Datenrennen-Warnung unter Swift 6.
    private final class Aufrufzaehler: @unchecked Sendable {
        private let lock = NSLock()
        private var wert = 0
        func zaehlen() -> Int { lock.withLock { wert += 1; return wert } }
        var anzahl: Int { lock.withLock { wert } }
    }

    /// A (Generation 0) startet, dann `freigeben()` (Generation 1), dann B (Generation 1) startet,
    /// dann wird A durchgelassen (stale) und darf `laedt` NICHT löschen – sonst hält ein drittes
    /// `laden()` fälschlich für frei und startet einen zweiten, parallel laufenden Ladevorgang,
    /// während B noch lädt. Gezählt wird über den Loader-Aufrufzähler.
    func testLaedtBleibtGesetztBisZurPassendenGeneration() async {
        let aufrufe = Aufrufzaehler()
        let aGestartet = AsyncSignal(), aWeiter = AsyncSignal()
        let bGestartet = AsyncSignal(), bWeiter = AsyncSignal()

        let index = LebensmittelIndex()

        index.laden(lader: {
            _ = aufrufe.zaehlen()
            await aGestartet.signalisieren()
            await aWeiter.warten()
            return []
        }, prioritaet: .userInitiated)
        await warte(auf: aGestartet, "Ladevorgang A gestartet")

        index.freigeben()

        index.laden(lader: {
            _ = aufrufe.zaehlen()
            await bGestartet.signalisieren()
            await bWeiter.warten()
            return []
        }, prioritaet: .userInitiated)
        await warte(auf: bGestartet, "Ladevorgang B gestartet")

        // A (stale Generation 0) durchlassen, nicht-blockierend warten, bis seine Abschluss-Klausel
        // gelaufen ist.
        await aWeiter.signalisieren()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Dritter Versuch, während B (Generation 1) noch lädt: darf keinen weiteren Loader starten.
        index.laden(lader: { _ = aufrufe.zaehlen(); return [] }, prioritaet: .userInitiated)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(aufrufe.anzahl, 2, "Nur A und B durften den Loader aufrufen, kein dritter paralleler Ladevorgang")

        // Aufräumen: B durchlassen, damit kein Hintergrund-Task über das Testende hinausläuft.
        await bWeiter.signalisieren()
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    func testVorneKommtZuerstUndOhneDoppelte() {
        let ei = l("bls-1", "Hühnerei, gekocht")
        let index = LebensmittelIndex(testDaten: [ei, l("bls-2", "Eierlikör")])
        let verlauf = [l("off-9", "Bio-Eier (L)"), ei]
        let t = index.suchen("ei", vorne: verlauf)
        XCTAssertEqual(t.first?.id, "off-9")
        XCTAssertEqual(t.filter { $0.id == "bls-1" }.count, 1)
        XCTAssertLessThanOrEqual(index.suchen("e", vorne: []).count, 50)
    }

    func testTempoUeberGanzenIndex() {
        let alle = LebensmittelBasis.laden(.main).isEmpty ? LebensmittelBasis.laden(Bundle(for: Self.self)) : LebensmittelBasis.laden(.main)
        let index = LebensmittelIndex(testDaten: alle)
        _ = index.suchen("ei", vorne: [])
        let start = Date()
        for q in ["ei", "banane", "kase gouda", "mager"] { _ = index.suchen(q, vorne: []) }
        let proSuche = Date().timeIntervalSince(start) / 4
        print("LEBENSMITTEL_SUCHE_MS \(Int(proSuche * 1000))")
        // ponytail: Grenze mit Luft für laute CI-Simulatoren; nach dem ersten CI-Lauf auf gemessen x 3 setzen.
        XCTAssertLessThan(proSuche, 0.050, "Suche \(Int(proSuche * 1000)) ms")
    }
}
