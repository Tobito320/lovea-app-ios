import XCTest

/// Tiefentest: klickt jeden Tab und jeden Kernablauf durch (Start mit `-tiefentest`, lokaler Test-Raum,
/// kein Netz). Pro Schritt ein Screenshot, Absturz / Hänger / leere Ansicht / abgeschnittener Text = Fehler.
/// Läuft nur im Job `tiefentest` (workflow_dispatch / Zweig tiefentest-ui), nicht in den normalen Läufen.
@MainActor
final class TiefenTestUITests: TiefenTestBasis {

    // MARK: - Erststart

    @MainActor
    func testErststart() {
        starten("erststart", erststart: true)
        erwarte("Wer bist du", hart: true)
        guard oeffne(["Ahmed"], name: "person-waehlen", hart: true, typen: ["Button"]) else { return }
        erwarte("Deine Figur", hart: true)
        oeffne(["Weiter"], name: "figur-weiter", hart: true, typen: ["Button"])
        erwarte("Mitteilungen", hart: true)
        oeffne(["Erlauben"], name: "mitteilungen-erlauben", hart: true, typen: ["Button"])
        systemDialog(warten: 5)
        erwarte("Standort", hart: false)
        oeffne(["Erlauben"], name: "standort-erlauben", hart: false, typen: ["Button"])
        // erst "Beim Verwenden", dann "Immer"-Nachfrage
        systemDialog(warten: 5)
        systemDialog(warten: 5)
        ruhe(2)
        pruefe("nach-erststart", dauer: 0)
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 15), "Nach dem Erststart fehlt die Tab-Leiste")
    }

    // MARK: - Tabs

    @MainActor
    func testTabHome() {
        starten("home")
        tour("Home", minuten: 7)
        erwarte("Schritte", hart: false, scrollen: 4)
    }

    @MainActor
    func testTabChatSenden() {
        starten("chat")
        wechsleTab("Chat")
        pruefe("chat-offen", dauer: 0)
        erwarte("Bis später", hart: false)
        // Chat-Tab zeigt zuerst die Konversationsliste
        guard oeffne(["Annika, Bis später", "Annika"], name: "chat-konversation", hart: true, typen: ["Button"]) else { return }
        ruhe(1)
        erwarte("Hallo aus dem Test-Raum", hart: true)
        nachricht("Tiefentest Nachricht eins")
        erwarte("Tiefentest Nachricht eins", hart: true)
        nachricht("Zweite Nachricht mit etwas mehr Text, damit der Umbruch in der Blase geprüft wird und nichts abgeschnitten wird.")
        erwarte("Zweite Nachricht", hart: true)
        scrolle(2, name: "chat-verlauf")
        // Im Chat suchen, antworten, lange drücken
        let chatWurzel = signatur(lesen())
        if let e = finde(["Tiefentest Nachricht eins"], typen: ["StaticText", "Other", "Cell"]) {
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: e.rahmen.midX, dy: e.rahmen.midY)).press(forDuration: 1.2)
            ruhe(1)
            pruefe("chat-nachrichtenmenue", dauer: 0)
            _ = zurueck(zu: chatWurzel)
        }
        pruefe("chat-ende", dauer: 0)
    }

    @MainActor
    func testChatPlusMedienSpiele() {
        starten("chatplus")
        wechsleTab("Chat")
        ruhe(1)
        guard oeffne(["Annika, Bis später", "Annika"], name: "chatplus-konversation", hart: true, typen: ["Button"]) else { return }
        ruhe(1)
        let wurzel = signatur(lesen())
        for ziel in ["Fotos", "GIFs", "Spiele", "Effekte"] {
            guard oeffne(["Mehr: Fotos", "Mehr schließen"], name: "plus-auf-\(ziel)", hart: false, typen: ["Button"]) else { return }
            ruhe(0.8)
            if oeffne([ziel], name: "plus-\(ziel)", hart: false, scrollen: 0) {
                ruhe(1.5)
                systemDialog()
                pruefe("plus-\(ziel)-offen", dauer: 0)
                if ziel == "Fotos" { fotoAuswaehlen() }
                if ziel == "Spiele" { spieleDurchgehen() }
                if ziel == "GIFs" { erkunde("gif", ebene1: 4, ebene2: 0, tiefe2Fuer: 0, minuten: 1.5) }
                _ = zurueck(zu: wurzel)
            }
        }
        // Snap-Kamera: im Simulator gibt es keine Kamera, die Ansicht darf nur nicht abstürzen
        if oeffne(["Snap aufnehmen"], name: "snap-kamera", hart: false, typen: ["Button"]) {
            ruhe(2)
            systemDialog()
            pruefe("snap-kamera-offen", dauer: 0)
            _ = zurueck(zu: wurzel)
        }
        pruefe("chatplus-ende", dauer: 0)
    }

    @MainActor
    func testTabZeichnenUndTeilen() {
        starten("zeichnen")
        wechsleTab("Zeichnen")
        pruefe("zeichnen-start", dauer: 0)
        // Neue Zeichnung anlegen
        if oeffne(["Neu", "Neue Zeichnung", "Hinzufügen", "plus"], name: "zeichnen-neu", hart: false, typen: ["Button"]) {
            ruhe(1.5)
            oeffne(["Quadrat", "Leinwand", "Erstellen", "Anlegen", "Weiter"], name: "zeichnen-format", hart: false, typen: ["Button", "Cell"])
            ruhe(2)
            pruefe("zeichnen-atelier", dauer: 0)
            // Striche malen
            let mitte = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            for i in 0..<4 {
                let von = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25 + 0.1 * Double(i), dy: 0.35))
                von.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75 - 0.1 * Double(i), dy: 0.6)))
            }
            _ = mitte
            ruhe(1)
            pruefe("zeichnen-striche", dauer: 0)
            let atelier = signatur(lesen())
            for knopf in ["Pinsel", "Radierer", "Farbe", "Ebenen", "Rückgängig", "Wiederholen", "Mehr"] {
                if oeffne([knopf], name: "zeichnen-\(knopf)", hart: false, scrollen: 0, typen: ["Button"]) {
                    _ = zurueck(zu: atelier)
                }
            }
            // Teilen mit dem Partner
            for teil in ["Teilen", "Mit Partner teilen", "Senden"] {
                if oeffne([teil], name: "zeichnen-teilen", hart: false, scrollen: 0, typen: ["Button"]) { break }
            }
            pruefe("zeichnen-teilen-offen", dauer: 0)
        }
        erkunde("zeichnen", ebene1: 10, ebene2: 2, tiefe2Fuer: 3, minuten: 5)
    }

    @MainActor
    func testTabHealth() {
        starten("health")
        wechsleTab("Health")
        systemDialog()
        pruefe("health-start", dauer: 0)
        nachObenScrollen()
        let healthWurzel = signatur(lesen())
        for abschnitt in ["Training", "Gym", "Schritte", "Habits", "Wasser", "Punkte", "Zyklus", "Schlaf", "Essen", "Ernährung"] {
            nachObenScrollen()
            if oeffne([abschnitt], name: "health-\(abschnitt)", hart: false, scrollen: 4, typen: ["Button", "Cell", "Link"]) {
                ruhe(1)
                pruefe("health-\(abschnitt)-offen", dauer: 0)
                scrolle(2, name: "health-\(abschnitt)")
                _ = zurueck(zu: healthWurzel)
                if app.state != .runningForeground { return }
            }
        }
        nachObenScrollen()
        tour("Health", minuten: 8)
    }

    @MainActor
    func testHealthGymTraining() {
        starten("gym")
        wechsleTab("Health")
        systemDialog()
        guard oeffne(["Training starten", "Gym", "Training"], name: "gym-start", hart: false, scrollen: 5, typen: ["Button", "Cell", "Link"]) else { return }
        ruhe(1.5)
        pruefe("gym-ansicht", dauer: 0)
        // Einheit anlegen und Satz eintragen, soweit die Knöpfe gefunden werden
        for teil in ["Training starten", "Starten", "Los", "Neue Einheit", "Übung hinzufügen", "Übung", "Satz hinzufügen", "Satz", "Hinzufügen"] {
            if oeffne([teil], name: "gym-\(teil)", hart: false, scrollen: 1, typen: ["Button", "Cell"]) {
                ruhe(1)
                if let feld = lesen().first(where: { $0.typ == "TextField" }) {
                    tippe(feld)
                    app.typeText("Bankdrücken")
                }
            }
        }
        scrolle(2, name: "gym")
        erkunde("gym", ebene1: 10, ebene2: 2, tiefe2Fuer: 3, minuten: 5)
        oeffne(["Training beenden", "Beenden"], name: "gym-beenden", hart: false, scrollen: 2, typen: ["Button"])
        pruefe("gym-ende", dauer: 0)
    }

    @MainActor
    func testTabProfil() {
        starten("profil")
        wechsleTab("Profil")
        pruefe("profil-start", dauer: 0)
        scrolle(2, name: "profil")
        nachObenScrollen()
        let profilWurzel = signatur(lesen())
        for bereich in ["Zimmer gestalten", "Shop", "Kleidung", "Deine Figur", "Einstellungen", "Karte", "Geschenk"] {
            nachObenScrollen()
            if oeffne([bereich], name: "profil-\(bereich)", hart: false, scrollen: 4, typen: ["Button", "Cell", "Link", "Other"]) {
                ruhe(1.5)
                pruefe("profil-\(bereich)-offen", dauer: 0)
                scrolle(2, name: "profil-\(bereich)")
                erkunde("profil-\(bereich)", ebene1: 6, ebene2: 1, tiefe2Fuer: 2, minuten: 3)
                _ = zurueck(zu: profilWurzel)
                wechsleTab("Profil", melden: false)
                if app.state != .runningForeground { return }
            }
        }
    }

    @MainActor
    func testProfilEinstellungenKomplett() {
        starten("einstellungen")
        wechsleTab("Profil")
        guard oeffne(["Einstellungen"], name: "einstellungen", hart: false, scrollen: 5, typen: ["Button", "Cell", "Link", "Other"]) else { return }
        ruhe(1)
        scrolle(4, name: "einstellungen")
        erkunde("einstellungen", ebene1: 18, ebene2: 3, tiefe2Fuer: 8, minuten: 7)
    }

    @MainActor
    func testKalenderUndTreffen() {
        starten("kalender")
        wechsleTab("Home")
        var offen = oeffne(["Kalender", "Nächstes Treffen", "Treffen", "Kino"], name: "kalender", hart: false, scrollen: 5, typen: ["Button", "Cell", "Link", "Other", "StaticText"])
        if !offen {
            wechsleTab("Profil", melden: false)
            offen = oeffne(["Kalender"], name: "kalender-profil", hart: false, scrollen: 5)
        }
        guard offen else { return }
        ruhe(1.5)
        pruefe("kalender-offen", dauer: 0)
        // Treffen anlegen
        for teil in ["Neues Treffen", "Treffen planen", "Treffen hinzufügen", "Neu", "Hinzufügen", "plus"] {
            if oeffne([teil], name: "kalender-\(teil)", hart: false, scrollen: 0, typen: ["Button"]) {
                ruhe(1)
                if let feld = lesen().first(where: { $0.typ == "TextField" }) {
                    tippe(feld)
                    app.typeText("Eis essen")
                }
                pruefe("kalender-formular", dauer: 0)
                oeffne(["Sichern", "Speichern", "Fertig", "Hinzufügen"], name: "kalender-sichern", hart: false, scrollen: 0, typen: ["Button"])
                break
            }
        }
        erkunde("kalender", ebene1: 12, ebene2: 2, tiefe2Fuer: 3, minuten: 5)
    }

    @MainActor
    func testDateIdeen() {
        starten("dateideen")
        wechsleTab("Home")
        guard oeffne(["Date-Ideen"], name: "dateideen", hart: false, scrollen: 6, typen: ["Button", "Cell", "Link", "Other", "StaticText"]) else {
            wechsleTab("Profil", melden: false)
            return
        }
        ruhe(1.5)
        pruefe("dateideen-offen", dauer: 0)
        scrolle(3, name: "dateideen")
        erkunde("dateideen", ebene1: 10, ebene2: 2, tiefe2Fuer: 3, minuten: 5)
    }

    @MainActor
    func testPartnerAnnikaAlleTabs() {
        starten("annika", person: "annika")
        for tab in ["Home", "Chat", "Zeichnen", "Health", "Profil"] {
            tour(tab, minuten: 3)
        }
    }

    // MARK: - Bausteine

    /// Tab öffnen, scrollen, durchklicken.
    @MainActor
    func tour(_ tab: String, minuten: Double) {
        wechsleTab(tab)
        systemDialog()
        pruefe("\(tab.lowercased())-start", dauer: 0)
        scrolle(3, name: tab.lowercased())
        nachObenScrollen()
        erkunde(tab.lowercased(), minuten: minuten)
    }

    @MainActor
    func nachricht(_ text: String) {
        let feld = lesen().first { ($0.typ == "TextView" || $0.typ == "TextField") && $0.label.contains("Nachricht") }
            ?? lesen().first { $0.typ == "TextView" || $0.typ == "TextField" }
        guard let feld else {
            befund("Eingabefeld im Chat nicht gefunden", hart: true)
            return
        }
        tippe(feld)
        ruhe(1)
        app.typeText(text)
        pruefe("chat-getippt", dauer: 0)
        app.typeText("\n")
        ruhe(1.5)
        pruefe("chat-gesendet", dauer: 0)
    }

    @MainActor
    func fotoAuswaehlen() {
        ruhe(2)
        systemDialog()
        // Der Foto-Picker läuft in einem eigenen Prozess; erstes Bild antippen, falls sichtbar.
        let bild = app.images.firstMatch
        if bild.waitForExistence(timeout: 6), bild.isHittable {
            bild.tap()
            ruhe(1)
            oeffne(["Hinzufügen", "Add", "Fertig"], name: "foto-bestaetigen", hart: false, scrollen: 0, typen: ["Button"])
            ruhe(2)
            pruefe("foto-ausgewaehlt", dauer: 0)
            if oeffne(["Anhang entfernen"], name: "foto-entfernen", hart: false, scrollen: 0, typen: ["Button"]) { ruhe(0.5) }
        }
    }

    @MainActor
    func spieleDurchgehen() {
        let titel = ["Kritzel-Duell", "XO", "Schere-Stein-Papier", "Wie gut kennst du mich", "Reaktions-Duell", "Memory", "Wer von uns ist eher", "Wordle-Duell", "Schiffe versenken"]
        let wurzel = signatur(lesen())
        for t in titel {
            guard oeffne([t], name: "spiel-\(t)", hart: false, scrollen: 2, typen: ["Button", "Cell", "Other"]) else { continue }
            ruhe(1.5)
            pruefe("spiel-\(t)-offen", dauer: 0)
            for aktion in ["Starten", "Los", "Einladen", "Spielen", "Neu"] {
                if oeffne([aktion], name: "spiel-\(t)-\(aktion)", hart: false, scrollen: 0, typen: ["Button"]) { ruhe(1); break }
            }
            erkunde("spiel-\(t)", ebene1: 4, ebene2: 0, tiefe2Fuer: 0, minuten: 1.5)
            if !zurueck(zu: wurzel) { return }
        }
    }
}
