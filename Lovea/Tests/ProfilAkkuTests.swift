import XCTest

/// p69 (49): the profile and the rooms it draws put no timer load on the battery. Reads the sources straight
/// from the folder (not the bundle), like `LebensmittelBasisTests`.
///
/// Review result: no `Timer`, no display link, no endless animation. The only clocks are `TimelineView`s that
/// carry a `paused:` (`ProfilSzene`, `KussPaar`, `AlltagEbene`), plus the walking of the two figures
/// (`ZuhauseBuehne.lauf`), a `.task(id:)` that sleeps 20 to 60 s between steps and ends with the view.
/// The one `TimelineView` without `paused:` is `SteigendeHerzen`, which exists only while hearts rain.
final class ProfilAkkuTests: XCTestCase {
    private static let ordner = ["Profile", "Signale", "Alltag", "Zimmer"]
    private static let verboten = ["Timer.scheduledTimer", "Timer.publish", "CADisplayLink", ".repeatForever"]

    private static let quellen: [(datei: String, zeilen: [String])] = {
        let wurzel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Lovea/Tests
            .appendingPathComponent("../Sources")
            .standardizedFileURL
        var alle: [(datei: String, zeilen: [String])] = []
        for name in ordner {
            let ziel = wurzel.appendingPathComponent(name)
            guard let leser = FileManager.default.enumerator(at: ziel, includingPropertiesForKeys: nil) else { continue }
            for fall in leser {
                guard let url = fall as? URL, url.pathExtension == "swift",
                      let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                alle.append((url.lastPathComponent, text.components(separatedBy: .newlines)))
            }
        }
        return alle
    }()

    func testQuellenGefunden() {
        XCTAssertGreaterThan(Self.quellen.count, 20, "Quellordner nicht gefunden: \(Self.ordner)")
        XCTAssertTrue(Self.quellen.contains { $0.datei == "ProfilSzene.swift" })
    }

    func testKeinTimerKeineDauerAnimation() {
        for q in Self.quellen {
            for (i, zeile) in q.zeilen.enumerated() {
                let code = zeile.components(separatedBy: "//").first ?? zeile
                for wort in Self.verboten where code.contains(wort) {
                    XCTFail("\(q.datei):\(i + 1) \(wort): Timer und Dauer-Animationen gehoeren nicht ins Profil")
                }
            }
        }
    }

    func testJedeZeitleistePausiert() {
        var gesehen = 0
        for q in Self.quellen {
            // `SteigendeHerzen` runs only while hearts rain (a kiss, `HerzRegen` for 3 s): the one exception.
            let herzen = q.zeilen.firstIndex { $0.contains("struct SteigendeHerzen") }
            for (i, zeile) in q.zeilen.enumerated() where zeile.contains("TimelineView(.animation") {
                gesehen += 1
                if let herzen, i > herzen, i <= herzen + 6 { continue }
                let naechste = i + 1 < q.zeilen.count ? q.zeilen[i + 1] : ""
                XCTAssertTrue(zeile.contains("paused:") || naechste.contains("paused:"),
                              "\(q.datei):\(i + 1): TimelineView ohne paused: laeuft immer, auch wenn nichts zu sehen ist")
            }
        }
        XCTAssertGreaterThanOrEqual(gesehen, 3, "TimelineViews nicht gefunden: der Scan ist kaputt")
    }
}
