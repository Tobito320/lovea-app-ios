import UIKit
import XCTest

/// Ein Element aus `app.debugDescription` (ein einziger Aufruf pro Bildschirm statt hunderter Abfragen).
struct TTElem {
    let typ: String
    let label: String
    let rahmen: CGRect
}

/// Grundlage der Tiefentest-Suite: Start mit lokalem Test-Raum (`-tiefentest`), Screenshot pro Schritt,
/// Prüfung auf Absturz, Hänger, leere Ansicht und abgeschnittenen Text, und ein Durchklicker, der
/// jeden sichtbaren Knopf antippt. Befunde landen als XCTFail und gesammelt in `Befunde.txt`.
@MainActor
class TiefenTestBasis: XCTestCase {
    var app: XCUIApplication!
    var bereich = "tt"
    var tabAktuell = "Home"
    var person = "ahmed"
    var zaehler = 0
    var befunde: [String] = []
    var gemeldet = Set<String>()
    var startArgumente: [String] = []

    static let tabNamen: Set<String> = ["Home", "Chat", "Zeichnen", "Health", "Profil"]
    /// Wird vom Durchklicker nie angetippt: Daten weg, Konto weg, Dinge, die den Test selbst kappen.
    static let gesperrt = ["lösch", "entfern", "abmeld", "person wechseln", "zurücksetzen", "konto", "entwickler", "absturz", "beenden", "verlassen", "abbrechen", "fertig", "schließen", "zurück", "close", "done", "nicht jetzt"]
    static let schliessWorte = ["fertig", "schließen", "abbrechen", "zurück", "close", "done", "nicht jetzt", "später", "ok", "verwerfen", "abbruch"]
    static let dialogKnoepfe = ["Beim Verwenden der App erlauben", "Beim Verwenden der App", "Erlauben", "Zulassen", "Allow While Using App", "Allow", "OK", "Alle Kategorien aktivieren", "Nicht erlauben", "Don’t Allow"]

    // MARK: - Start

    @MainActor
    func starten(_ bereich: String, person: String = "ahmed", erststart: Bool = false, extra: [String] = []) {
        continueAfterFailure = true
        self.bereich = bereich
        self.person = person
        zaehler = 0
        befunde = []
        gemeldet = []
        startArgumente = [
            "-tiefentest", "-tiefentestNeu", "YES",
            "-tiefentestPerson", erststart ? "keine" : person,
            "-lovea.ersterStartFertig", erststart ? "NO" : "YES",
            "-AppleLanguages", "(de)", "-AppleLocale", "de_DE",
        ] + extra
        addTeardownBlock { @MainActor [weak self] in self?.befundeAnhaengen() }
        addUIInterruptionMonitor(withDescription: "Systemdialog") { alert in
            for name in TiefenTestBasis.dialogKnoepfe where alert.buttons[name].exists {
                alert.buttons[name].tap()
                return true
            }
            if alert.buttons.count > 0 { alert.buttons.element(boundBy: alert.buttons.count - 1).tap(); return true }
            return false
        }
        app = XCUIApplication()
        app.launchArguments = startArgumente
        app.launch()
        if !app.wait(for: .runningForeground, timeout: 40) { befund("App kommt nicht in den Vordergrund", hart: true) }
        ruhe(2)
        if lesen().isEmpty {
            befund("Bildschirmbaum nicht lesbar (debugDescription leer oder anderes Format)", hart: true)
            anhaengen("Hierarchie-roh", text: app.debugDescription)
        }
        foto("start")
    }

    @MainActor
    func neustart() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = startArgumente
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 40)
        ruhe(2)
        if !startArgumente.contains("keine") { wechsleTab(tabAktuell, melden: false) }
    }

    // MARK: - Zeit, Anhänge, Befunde

    @MainActor
    func ruhe(_ sekunden: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "ruhe")], timeout: sekunden)
    }

    @MainActor
    func foto(_ name: String) {
        zaehler += 1
        let bild = XCUIScreen.main.screenshot().image
        let titel = String(format: "%@-%03d-%@", bereich, zaehler, bereinigt(name))
        if let daten = bild.jpegData(compressionQuality: 0.55) {
            let a = XCTAttachment(uniformTypeIdentifier: "public.jpeg", name: titel + ".jpg", payload: daten, userInfo: nil)
            a.lifetime = .keepAlways
            add(a)
        } else {
            let a = XCTAttachment(image: bild, quality: .medium)
            a.name = titel
            a.lifetime = .keepAlways
            add(a)
        }
    }

    @MainActor
    func anhaengen(_ name: String, text: String) {
        let a = XCTAttachment(string: text)
        a.name = name + ".txt"
        a.lifetime = .keepAlways
        add(a)
    }

    func bereinigt(_ name: String) -> String {
        let erlaubt = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let ersetzt = name.unicodeScalars.map { erlaubt.contains($0) ? Character($0) : "_" }
        return String(String(ersetzt).prefix(48))
    }

    /// `hart`: Absturz, Hänger, leere Ansicht, abgeschnittener Text, fehlender Kernknopf -> Test rot.
    /// Sonst nur Eintrag in `Befunde.txt` (z. B. App sprang kurz in eine andere App).
    @MainActor
    func befund(_ text: String, hart: Bool) {
        let eintrag = "[\(bereich)] \(hart ? "FEHLER" : "Hinweis"): \(text)"
        guard gemeldet.insert(eintrag).inserted else { return }
        befunde.append(eintrag)
        if hart {
            if befunde.count <= 8 { anhaengen("Hierarchie-\(bereich)-\(befunde.count)", text: app.debugDescription) }
            XCTFail(eintrag)
        }
    }

    @MainActor
    func befundeAnhaengen() {
        anhaengen("Befunde-" + bereich, text: befunde.isEmpty ? "keine Befunde" : befunde.joined(separator: "\n"))
    }

    // MARK: - Bildschirm lesen

    @MainActor
    func lesen() -> [TTElem] {
        var ergebnis: [TTElem] = []
        for zeile in app.debugDescription.split(separator: "\n") {
            let z = zeile.trimmingCharacters(in: .whitespaces)
            guard let komma = z.firstIndex(of: ",") else { continue }
            let typ = String(z[..<komma]).components(separatedBy: " ").first ?? ""
            guard let rahmen = Self.rahmen(z) else { continue }
            ergebnis.append(TTElem(typ: typ, label: Self.label(z), rahmen: rahmen))
        }
        return ergebnis
    }

    static func rahmen(_ zeile: String) -> CGRect? {
        guard let r = zeile.range(of: #"\{\{-?[0-9.]+, -?[0-9.]+\}, \{-?[0-9.]+, -?[0-9.]+\}\}"#, options: .regularExpression) else { return nil }
        let zahlen = zeile[r].split(whereSeparator: { !"-0123456789.".contains($0) }).compactMap { Double($0) }
        guard zahlen.count == 4 else { return nil }
        return CGRect(x: zahlen[0], y: zahlen[1], width: zahlen[2], height: zahlen[3])
    }

    static func label(_ zeile: String) -> String {
        guard let r = zeile.range(of: "label: '") else { return "" }
        var rest = String(zeile[r.upperBound...])
        for ende in ["', value: ", "', placeholderValue: ", "', Selected", "', Disabled", "', Not hittable"] {
            if let e = rest.range(of: ende) { rest = String(rest[..<e.lowerBound]); return rest }
        }
        if rest.hasSuffix("'") { rest.removeLast() }
        return rest
    }

    @MainActor
    func fenster(_ sicht: [TTElem]) -> CGRect {
        let fenster = sicht.filter { $0.typ == "Window" }.max { $0.rahmen.width * $0.rahmen.height < $1.rahmen.width * $1.rahmen.height }
        return fenster?.rahmen ?? app.windows.firstMatch.frame
    }

    /// Beschriftungen, an denen man einen Bildschirm wiedererkennt (ohne Tab-Leiste).
    func signatur(_ sicht: [TTElem]) -> Set<String> {
        Set(sicht.filter { ["Button", "Cell", "StaticText"].contains($0.typ) && !$0.label.isEmpty && !Self.tabNamen.contains($0.label) }.map(\.label))
    }

    func aehnlich(_ a: Set<String>, _ b: Set<String>) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        return Double(a.intersection(b).count) / Double(min(a.count, b.count)) >= 0.5
    }

    // MARK: - Bedienen

    @MainActor
    func tippe(_ e: TTElem) {
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: e.rahmen.midX, dy: e.rahmen.midY))
            .tap()
    }

    @MainActor
    func wechsleTab(_ name: String, melden: Bool = true) {
        tabAktuell = name
        let knopf = app.tabBars.buttons[name].firstMatch
        if knopf.waitForExistence(timeout: 8) {
            knopf.tap()
        } else if let e = lesen().first(where: { $0.typ == "Button" && $0.label == name && $0.rahmen.midY > 600 }) {
            tippe(e)
        } else if melden {
            befund("Tab \(name) nicht gefunden", hart: true)
        }
        ruhe(1.5)
    }

    /// Findet einen Knopf, eine Zeile oder einen Text mit dieser Teil-Beschriftung (auch nach Scrollen).
    @MainActor
    func finde(_ teile: [String], typen: Set<String> = ["Button", "Cell", "Link", "StaticText", "Other"], scrollen: Int = 3) -> TTElem? {
        for versuch in 0...scrollen {
            let sicht = lesen()
            let w = fenster(sicht)
            let treffer = sicht.first { e in
                typen.contains(e.typ) && !e.label.isEmpty
                    && teile.contains { e.label.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
                    && e.rahmen.midX >= 0 && e.rahmen.midX <= w.width && e.rahmen.midY > 40 && e.rahmen.midY < w.height - 4
            }
            if let treffer { return treffer }
            if versuch < scrollen { app.swipeUp(); ruhe(0.6) }
        }
        return nil
    }

    func sichtbar(_ teil: String) -> Bool {
        lesen().contains { $0.label.range(of: teil, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// Antippen mit Pruefung. `hart`: fehlt der Knopf, ist das ein Fehler. Gibt zurück, ob getippt wurde.
    @MainActor
    @discardableResult
    func oeffne(_ teile: [String], name: String? = nil, hart: Bool = false, scrollen: Int = 3, typen: Set<String> = ["Button", "Cell", "Link", "StaticText", "Other"]) -> Bool {
        let t0 = Date()
        guard let e = finde(teile, typen: typen, scrollen: scrollen) else {
            befund("nicht gefunden: \(teile.joined(separator: " / "))", hart: hart)
            return false
        }
        tippe(e)
        ruhe(1.2)
        pruefe(name ?? teile[0], dauer: Date().timeIntervalSince(t0) - 1.2)
        return true
    }

    @MainActor
    func erwarte(_ teil: String, hart: Bool, scrollen: Int = 0) {
        for versuch in 0...scrollen {
            if sichtbar(teil) { return }
            if versuch < scrollen { app.swipeUp(); ruhe(0.5) }
        }
        befund("erwartet, aber nicht sichtbar: \(teil)", hart: hart)
    }

    @MainActor
    func scrolle(_ mal: Int, name: String) {
        for i in 1...max(1, mal) {
            app.swipeUp()
            ruhe(0.7)
            pruefe("\(name)-scroll\(i)", dauer: 0)
        }
    }

    @MainActor
    func nachObenScrollen() {
        for _ in 0..<4 { app.swipeDown(velocity: .fast) }
        ruhe(0.5)
    }

    // MARK: - Prüfung

    /// Screenshot, dann Absturz / Hänger / leer / abgeschnitten. Gibt false zurück, wenn die App neu starten musste.
    @MainActor
    @discardableResult
    func pruefe(_ name: String, dauer: TimeInterval, erwartetLeer: Bool = false) -> Bool {
        systemDialog()
        guard lebt(name) else { return false }
        foto(name)
        if dauer > 15 { befund("Hänger: \(name) brauchte \(Int(dauer)) s", hart: true) }
        let sicht = lesen()
        inhaltPruefen(name, sicht: sicht, erwartetLeer: erwartetLeer)
        return true
    }

    @MainActor
    func systemDialog() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.exists else { return }
        for name in Self.dialogKnoepfe where alert.buttons[name].exists {
            alert.buttons[name].tap()
            ruhe(0.8)
            return
        }
        if alert.buttons.count > 0 { alert.buttons.element(boundBy: alert.buttons.count - 1).tap(); ruhe(0.8) }
    }

    @MainActor
    func lebt(_ name: String) -> Bool {
        switch app.state {
        case .runningForeground:
            return true
        case .runningBackground, .runningBackgroundSuspended:
            befund("App verließ den Vordergrund nach \(name) (fremde App geöffnet?)", hart: false)
            app.activate()
            _ = app.wait(for: .runningForeground, timeout: 10)
            return app.state == .runningForeground
        default:
            befund("ABSTURZ nach \(name)", hart: true)
            neustart()
            return false
        }
    }

    @MainActor
    func inhaltPruefen(_ name: String, sicht: [TTElem], erwartetLeer: Bool) {
        let w = fenster(sicht)
        let inhalt = sicht.filter {
            ["StaticText", "Button", "Cell", "TextField", "TextView", "Image", "Switch", "Slider"].contains($0.typ)
                && !Self.tabNamen.contains($0.label) && $0.rahmen.width > 0
        }
        if !erwartetLeer && inhalt.count < 2 { befund("leere Ansicht bei \(name)", hart: true) }
        for e in sicht where e.typ == "StaticText" && !e.label.isEmpty && e.rahmen.width > 0 && e.rahmen.height > 0 {
            if e.label.hasSuffix("…") || e.label.hasSuffix("...") {
                befund("Text endet mit Auslassung bei \(name): '\(e.label)'", hart: true)
                continue
            }
            // Einzeilig und mindestens 11 pt: braucht der Text deutlich mehr Breite als sein Rahmen?
            if e.rahmen.height < 24, !e.label.contains("\n") {
                let noetig = (e.label as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 11)]).width
                if noetig > e.rahmen.width * 1.15 + 4 {
                    befund("Text wahrscheinlich abgeschnitten bei \(name): '\(e.label)' (Rahmen \(Int(e.rahmen.width)) pt, braucht mind. \(Int(noetig)) pt)", hart: true)
                }
            }
            if e.rahmen.width < w.width * 1.2, e.rahmen.minX < -3 || e.rahmen.maxX > w.width + 3, e.rahmen.midY > 40, e.rahmen.midY < w.height {
                befund("Text ragt aus dem Bildschirm bei \(name): '\(e.label)'", hart: false)
            }
        }
    }

    // MARK: - Durchklicker

    @MainActor
    func kandidaten(_ sicht: [TTElem]) -> [TTElem] {
        let w = fenster(sicht)
        var ergebnis: [TTElem] = []
        for e in sicht where ["Button", "Cell", "Link"].contains(e.typ) && !e.label.isEmpty {
            let klein = e.label.lowercased()
            if Self.tabNamen.contains(e.label) || Self.gesperrt.contains(where: { klein.contains($0) }) { continue }
            if e.rahmen.midX < 0 || e.rahmen.midX > w.width || e.rahmen.midY < 60 || e.rahmen.midY > w.height - 4 { continue }
            if e.rahmen.minX < 100, e.rahmen.midY < 130 { continue } // Zurück-Pfeil in der Titelleiste
            if e.rahmen.width < 8 || e.rahmen.height < 8 { continue }
            if ergebnis.contains(where: { abs($0.rahmen.midX - e.rahmen.midX) < 12 && abs($0.rahmen.midY - e.rahmen.midY) < 12 }) { continue }
            ergebnis.append(e)
        }
        return ergebnis
    }

    /// Zurück zum Ausgangsbildschirm: Alarm, Schließen-Knopf, Zurück-Pfeil, Sheet wegwischen, Rand-Wisch.
    @MainActor
    func zurueck(zu wurzel: Set<String>) -> Bool {
        for versuch in 0..<5 {
            systemDialog()
            guard app.state == .runningForeground else { return false }
            let sicht = lesen()
            if aehnlich(signatur(sicht), wurzel) { return true }
            let alert = app.alerts.firstMatch
            if alert.exists {
                for name in ["Abbrechen", "Nicht erlauben", "Schließen", "OK"] where alert.buttons[name].exists {
                    alert.buttons[name].tap()
                    break
                }
                if alert.exists, alert.buttons.count > 0 { alert.buttons.element(boundBy: 0).tap() }
            } else if let knopf = sicht.first(where: { $0.typ == "Button" && Self.schliessWorte.contains($0.label.lowercased()) }) {
                tippe(knopf)
            } else if let pfeil = sicht.first(where: { $0.typ == "Button" && $0.rahmen.minX < 100 && $0.rahmen.midY < 130 && $0.rahmen.midY > 40 }) {
                tippe(pfeil)
            } else if versuch % 2 == 0 {
                let von = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
                von.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
            } else {
                let von = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
                von.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
            }
            ruhe(0.9)
        }
        return aehnlich(signatur(lesen()), wurzel)
    }

    /// Tippt nacheinander jeden sichtbaren Knopf (beim Scrollen weitere), fotografiert, prüft und geht zurück.
    /// Die ersten `tiefe2Fuer` Knöpfe, die einen neuen Bildschirm öffnen, werden eine Ebene tiefer ebenfalls durchgeklickt.
    @MainActor
    func erkunde(_ name: String, ebene1: Int = 14, ebene2: Int = 4, tiefe2Fuer: Int = 5, minuten: Double = 6) {
        let ende = Date().addingTimeInterval(minuten * 60)
        var getan = Set<String>()
        var anzahl = 0
        var tiefer = 0
        for phase in 0..<4 {
            if phase > 0 { app.swipeUp(); ruhe(0.7) }
            while anzahl < ebene1 && Date() < ende {
                let wurzelSicht = lesen()
                let wurzel = signatur(wurzelSicht)
                guard let k = kandidaten(wurzelSicht).first(where: { !getan.contains($0.label) }) else { break }
                getan.insert(k.label)
                anzahl += 1
                let t0 = Date()
                tippe(k)
                ruhe(1.0)
                let dauer = Date().timeIntervalSince(t0) - 1.0
                let schritt = "\(name)-\(k.label)"
                guard pruefe(schritt, dauer: dauer) else { continue }
                let nach = lesen()
                let neuerBildschirm = !aehnlich(signatur(nach), wurzel)
                guard neuerBildschirm else { continue }
                if tiefer < tiefe2Fuer {
                    tiefer += 1
                    zweiteEbene(schritt, sicht: nach, max: ebene2)
                }
                if !zurueck(zu: wurzel) {
                    befund("kein Rückweg von '\(k.label)' (\(name)), App neu gestartet", hart: false)
                    neustart()
                    return
                }
            }
        }
    }

    @MainActor
    func zweiteEbene(_ name: String, sicht: [TTElem], max: Int) {
        let wurzel = signatur(sicht)
        var getan = Set<String>()
        for _ in 0..<max {
            let aktuell = lesen()
            guard let k = kandidaten(aktuell).first(where: { !getan.contains($0.label) }) else { return }
            getan.insert(k.label)
            let t0 = Date()
            tippe(k)
            ruhe(1.0)
            let dauer = Date().timeIntervalSince(t0) - 1.0
            guard pruefe("\(name)-\(k.label)", dauer: dauer) else { return }
            if !aehnlich(signatur(lesen()), wurzel), !zurueck(zu: wurzel) { return }
        }
    }
}
