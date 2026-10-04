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
