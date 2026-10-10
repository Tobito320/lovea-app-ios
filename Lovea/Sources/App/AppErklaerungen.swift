import TipKit

// Kurze Hinweise zu versteckten Funktionen (lang drücken, wischen, "..."-Menüs, Schalter), die man
// nicht direkt sieht. Ein Weg für die ganze App: Apple TipKit, konfiguriert in `LoveaApp.init()`.
// Höchstens ein neuer Tip pro Stunde (`.displayFrequency(.hourly)` in der Konfiguration), damit nicht alles
// auf einen Schlag aufpoppt. Jeder Tip kommt genau einmal (Ahmed, 05.10.2026), siehe `Erklaerung`.
// Siehe `docs/erklaerungen.md` für die volle Liste.

/// Alle Hinweise der App: nach dem ersten Erscheinen nie wieder, auch ohne Wegtippen.
// ponytail: kein Wiederzeigen nach langer Pause; TipKit zählt MaxDisplayCount für immer.
protocol Erklaerung: Tip {}

extension Erklaerung {
    var options: [any TipOption] { [Tips.MaxDisplayCount(1)] }
}

struct ZyklusEintragenTip: Erklaerung {
    var title: Text { Text("Eintragen und Vorhersage") }
    var message: Text? { Text("Heute eintragen: Periode, Stimmung oder Symptome. Periode beginnt heute setzt den ersten Tag und rechnet die Vorhersage neu. Andere Tage trägst du im Kalender ein.") }
}

struct TrainingBeendenTip: Erklaerung {
    var title: Text { Text("Training beenden") }
    var message: Text? { Text("Fertige Sätze zählen. Was offen bleibt, steht beim nächsten Mal wieder im Plan.") }
}

struct TrainingstagWechselnTip: Erklaerung {
    var title: Text { Text("Anderer Trainingstag") }
    var message: Text? { Text("Tippen wechselt zu einem anderen Trainingstag.") }
}

struct UebungMehrTip: Erklaerung {
    var title: Text { Text("Mehr zur Übung") }
    var message: Text? { Text("Animation, Aufwärmsätze, Scheibenrechner, auslassen oder entfernen.") }
}

struct CardioSchnellTip: Erklaerung {
    var title: Text { Text("Laufband und Stairmaster") }
    var message: Text? { Text("Öffnet ein Cardio-Formular für Zeit und Strecke. Zählt nicht als Satz.") }
}

struct GymStartMehrTip: Erklaerung {
    var title: Text { Text("Mehr im Gym") }
    var message: Text? { Text("Plan vom Partner, Verlauf, Messungen, Übungen, Split wechseln oder frei trainieren ohne Plan.") }
}

struct SplitFuerDichTip: Erklaerung {
    var title: Text { Text("Für dich") }
    var message: Text? { Text("Zeigt nur deine eigenen gespeicherten Splits.") }
}

struct EinkaufListeMehrTip: Erklaerung {
    var title: Text { Text("Mehr zur Liste") }
    var message: Text? { Text("Erledigte löschen, Liste umbenennen oder löschen.") }
}

struct TerminMehrTip: Erklaerung {
    var title: Text { Text("Mehr zum Termin") }
    var message: Text? { Text("Tippen bearbeitet. Lang drücken zeigt mehr: zum iPhone-Kalender, löschen.") }
}

struct ChatNachrichtGesteTip: Erklaerung {
    var title: Text { Text("Nachricht-Gesten") }
    var message: Text? { Text("Doppelt tippen sendet ein Herz. Gedrückt halten zeigt Reaktionen und Antworten.") }
}

struct FotoGedruecktHaltenTip: Erklaerung {
    var title: Text { Text("Foto speichern") }
    var message: Text? { Text("Gedrückt halten speichert das Foto in der Galerie.") }
}

struct ProjektMehrTip: Erklaerung {
    var title: Text { Text("Mehr zum Projekt") }
    var message: Text? { Text("Projekt teilen, umbenennen oder löschen.") }
}

struct ZeichenstudioMehrTip: Erklaerung {
    var title: Text { Text("Mehr im Studio") }
    var message: Text? { Text("Ansicht spiegeln oder zurücksetzen, und je nach Werkzeug weitere Optionen.") }
}

struct WerkzeugMehrTip: Erklaerung {
    var title: Text { Text("Mehr Werkzeuge") }
    var message: Text? { Text("Als Schablone, als Ebene, Pinsel wählen.") }
}

struct EbeneGesteTip: Erklaerung {
    var title: Text { Text("Ebenen-Optionen") }
    var message: Text? { Text("Gedrückt halten oder nach links wischen zeigt Optionen, auch Löschen.") }
}

struct FigurGesteTip: Erklaerung {
    var title: Text { Text("Figur berühren") }
    var message: Text? { Text("Tippen öffnet Anstupsen, Kuss und Ausdrücke. Gedrückt halten schickt sofort ein Herz.") }
}

struct KachelGesteTip: Erklaerung {
    var title: Text { Text("Mehr zur Kachel") }
    var message: Text? { Text("Tippen zählt eins hoch. Gedrückt halten zeigt Abziehen und den Verlauf des Tages.") }
}

struct SatzWischenTip: Erklaerung {
    var title: Text { Text("Satz kopieren oder löschen") }
    var message: Text? { Text("Nach rechts wischen kopiert einen Satz, nach links löscht ihn. Rückgängig geht kurz danach.") }
}

struct ErnaehrungMehrTip: Erklaerung {
    var title: Text { Text("Mehr zum Tag") }
    var message: Text? { Text("Auswertung, Nährwerte, Fasten, Einkaufsliste, Tagebuch anpassen oder zum Tag des Partners wechseln.") }
}

struct MahlzeitMehrTip: Erklaerung {
    var title: Text { Text("Mehr zur Mahlzeit") }
    var message: Text? { Text("Übernimmt die gestrige Mahlzeit für heute.") }
}

struct SplitTagMehrTip: Erklaerung {
    var title: Text { Text("Mehr zum Tag") }
    var message: Text? { Text("Tag umbenennen oder löschen.") }
}

struct TreffenMehrTip: Erklaerung {
    var title: Text { Text("Mehr zum Treffen") }
    var message: Text? { Text("Bearbeiten, zum iPhone-Kalender oder absagen.") }
}

struct DuellMehrTip: Erklaerung {
    var title: Text { Text("Mehr zum Duell") }
    var message: Text? { Text("In den Chat senden oder in Aufnahmen speichern.") }
}

struct TrainingsplanZeileTip: Erklaerung {
    var title: Text { Text("Übung in der Zeile") }
    var message: Text? { Text("Nach links wischen löscht. Nach rechts wischen verdoppelt die Übung.") }
}

struct ZyklusZahlenTip: Erklaerung {
    var title: Text { Text("Deine Zahlen") }
    var message: Text? { Text("Durchschnitt aus deinen eingetragenen Zyklen. Streuung zeigt, wie stark sie sich unterscheiden – je mehr eingetragen ist, desto genauer.") }
}

struct VolumenTip: Erklaerung {
    var title: Text { Text("Volumen") }
    var message: Text? { Text("Kilogramm mal Wiederholungen, über alle gezählten Sätze addiert.") }
}
