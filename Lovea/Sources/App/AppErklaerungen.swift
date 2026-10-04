import TipKit

// Kurze Hinweise zu versteckten Funktionen (lang drücken, wischen, "..."-Menüs, Schalter), die man
// nicht direkt sieht. Ein Weg für die ganze App: Apple TipKit, konfiguriert in `LoveaApp.init()`.
// Jeder Tip zeigt sich einmal (`.displayFrequency(.hourly)` in der Konfiguration, kein `.immediate`),
// damit nicht alles auf einen Schlag aufpoppt. Siehe `docs/erklaerungen.md` für die volle Liste.

struct TrainingBeendenTip: Tip {
    var title: Text { Text("Training beenden") }
    var message: Text? { Text("Fertige Sätze zählen. Was offen bleibt, steht beim nächsten Mal wieder im Plan.") }
}

struct TrainingstagWechselnTip: Tip {
    var title: Text { Text("Anderer Trainingstag") }
    var message: Text? { Text("Tippen wechselt zu einem anderen Trainingstag.") }
}

struct UebungMehrTip: Tip {
    var title: Text { Text("Mehr zur Übung") }
    var message: Text? { Text("Animation, Aufwärmsätze, Scheibenrechner, auslassen oder entfernen.") }
}

struct CardioSchnellTip: Tip {
    var title: Text { Text("Laufband und Stairmaster") }
    var message: Text? { Text("Öffnet ein Cardio-Formular für Zeit und Strecke. Zählt nicht als Satz.") }
}

struct GymStartMehrTip: Tip {
    var title: Text { Text("Mehr im Gym") }
    var message: Text? { Text("Plan vom Partner, Verlauf, Messungen, Übungen, Split wechseln oder frei trainieren ohne Plan.") }
}

struct SplitFuerDichTip: Tip {
    var title: Text { Text("Für dich") }
    var message: Text? { Text("Zeigt nur deine eigenen gespeicherten Splits.") }
}

struct EinkaufListeMehrTip: Tip {
    var title: Text { Text("Mehr zur Liste") }
    var message: Text? { Text("Erledigte löschen, Liste umbenennen oder löschen.") }
}

struct TerminMehrTip: Tip {
    var title: Text { Text("Mehr zum Termin") }
    var message: Text? { Text("Tippen bearbeitet. Lang drücken zeigt mehr: zum iPhone-Kalender, löschen.") }
}

struct ChatNachrichtGesteTip: Tip {
    var title: Text { Text("Nachricht-Gesten") }
    var message: Text? { Text("Doppelt tippen sendet ein Herz. Gedrückt halten zeigt Reaktionen und Antworten.") }
}

struct FotoGedruecktHaltenTip: Tip {
    var title: Text { Text("Foto speichern") }
    var message: Text? { Text("Gedrückt halten speichert das Foto in der Galerie.") }
}

struct ProjektMehrTip: Tip {
    var title: Text { Text("Mehr zum Projekt") }
    var message: Text? { Text("Projekt teilen, umbenennen oder löschen.") }
}

struct ZeichenstudioMehrTip: Tip {
    var title: Text { Text("Mehr im Studio") }
    var message: Text? { Text("Ansicht spiegeln oder zurücksetzen, und je nach Werkzeug weitere Optionen.") }
}

struct WerkzeugMehrTip: Tip {
    var title: Text { Text("Mehr Werkzeuge") }
    var message: Text? { Text("Als Schablone, als Ebene, Pinsel wählen.") }
}

struct EbeneGesteTip: Tip {
    var title: Text { Text("Ebenen-Optionen") }
    var message: Text? { Text("Gedrückt halten oder nach links wischen zeigt Optionen, auch Löschen.") }
}

struct FigurGesteTip: Tip {
    var title: Text { Text("Figur berühren") }
    var message: Text? { Text("Tippen öffnet Anstupsen, Kuss und Ausdrücke. Gedrückt halten schickt sofort ein Herz.") }
}

struct KachelGesteTip: Tip {
    var title: Text { Text("Mehr zur Kachel") }
    var message: Text? { Text("Tippen zählt eins hoch. Gedrückt halten zeigt Abziehen und den Verlauf des Tages.") }
}

struct SatzWischenTip: Tip {
    var title: Text { Text("Satz löschen") }
    var message: Text? { Text("Nach links wischen löscht einen Satz.") }
}

struct ErnaehrungMehrTip: Tip {
    var title: Text { Text("Mehr zum Tag") }
    var message: Text? { Text("Auswertung, Nährwerte, Fasten, Einkaufsliste, Tagebuch anpassen oder zum Tag des Partners wechseln.") }
}

struct MahlzeitMehrTip: Tip {
    var title: Text { Text("Mehr zur Mahlzeit") }
    var message: Text? { Text("Übernimmt die gestrige Mahlzeit für heute.") }
}

struct SplitTagMehrTip: Tip {
    var title: Text { Text("Mehr zum Tag") }
    var message: Text? { Text("Tag umbenennen oder löschen.") }
}

struct TreffenMehrTip: Tip {
    var title: Text { Text("Mehr zum Treffen") }
    var message: Text? { Text("Bearbeiten, zum iPhone-Kalender oder absagen.") }
}

struct DuellMehrTip: Tip {
    var title: Text { Text("Mehr zum Duell") }
    var message: Text? { Text("In den Chat senden oder in Aufnahmen speichern.") }
}

struct TrainingsplanZeileTip: Tip {
    var title: Text { Text("Übung in der Zeile") }
    var message: Text? { Text("Nach links wischen löscht. Nach rechts wischen verdoppelt die Übung.") }
}

struct ZyklusZahlenTip: Tip {
    var title: Text { Text("Deine Zahlen") }
    var message: Text? { Text("Durchschnitt aus deinen eingetragenen Zyklen. Streuung zeigt, wie stark sie sich unterscheiden – je mehr eingetragen ist, desto genauer.") }
}

struct VolumenTip: Tip {
    var title: Text { Text("Volumen") }
    var message: Text? { Text("Kilogramm mal Wiederholungen, über alle gezählten Sätze addiert.") }
}
