# Erklärungen – versteckte Funktionen

Auftrag Ahmed 04.10.2026: kurze Hinweise zu Funktionen, die man nicht direkt sieht (lang drücken,
wischen, Menüs hinter "...", Schalter, Rechenlogik). Zielgruppe Ahmed und Annika, keine Techniker.

Weg: Apple TipKit (`Tip`, `.popoverTip`, `TipView`), ein Weg für die ganze App. Deployment-Target
iOS 26 (project.yml), TipKit ab iOS 17 verfügbar. Alle Tips in `Lovea/Sources/App/AppErklaerungen.swift`.
`Tips.configure([.displayFrequency(.hourly)])` in `LoveaApp.init()`, nicht `.immediate` (nervt sonst,
zeigt sonst beim ersten Start alles auf einmal). UI-Tests (`istTest`) überspringen configure, wie
schon beim restlichen Start-Code.

Status-Spalten: **umgesetzt** = Tip im Code eingefügt. **nur Vorschlag (gesperrt)** = Datei ist für
diese Sitzung gesperrt (PR #83 läuft dort), Text hier nur als Vorschlag für später. **fehlt in
runde-3** = Funktion im Auftrag genannt, aber in diesem Branch nicht gefunden.

## Zyklus (gesperrt – nur Textvorschläge)

Gesperrte Dateien: `ZyklusHeuteView.swift`, `ZyklusEinstellungenBlatt.swift`, `ZyklusLogik.swift`,
`ZyklusVorhersage.swift`. Wer die Tips einbaut: gleiches Muster wie unten (TipKit, Tip aus
`AppErklaerungen.swift`, `.popoverTip` oder `TipView` über der jeweiligen Stelle).

| Bereich | Hinweistext | Status |
|---|---|---|
| Eintragen (Periode/Symptome loggen) | "Tippe auf einen Tag, um Periode, Stimmung oder Symptome einzutragen." | nur Vorschlag (gesperrt) |
| "Periode beginnt heute" | "Setzt den heutigen Tag als ersten Periodentag und rechnet die Vorhersage neu." | nur Vorschlag (gesperrt) |
| Insights/Vorhersage-Karte | "Die Vorhersage rechnet aus deinen letzten Zyklen. Je mehr eingetragen ist, desto genauer." | nur Vorschlag (gesperrt) |

Geprüft: `Eintragen`, `Periode beginnt heute` und `Insights` leben nur in den vier gesperrten Dateien.
Die übrigen 22 Zyklus-Dateien (`ZyklusEintragBlatt.swift`, `ZyklusInsightsView.swift`,
`ZyklusKalenderView.swift` …) haben keine versteckten Gesten oder Menüs (kein `contextMenu`,
`swipeActions`, `onLongPressGesture`, `Menu {`, `ellipsis`) — nichts dort zu erklären.

## Gym / Training

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Health/WorkoutView.swift:526` (Training beenden) | Button | "Fertige Sätze zählen. Was offen bleibt, steht beim nächsten Mal wieder im Plan." | umgesetzt |
| `Health/WorkoutView.swift:389` (Titel-Menü, Trainingstag wechseln) | Menu (Pfeil am Titel) | "Tippen wechselt zu einem anderen Trainingstag." | umgesetzt |
| `Health/WorkoutView.swift:750` ("..." bei einer Übung) | Menu | "Mehr zu dieser Übung: Animation, Aufwärmsätze, Scheibenrechner, auslassen oder entfernen." | umgesetzt |
| `Health/WorkoutView.swift:506` (Laufband/Stairmaster-Knöpfe) | Button | "Öffnet ein Cardio-Formular für Zeit und Strecke. Zählt nicht als Satz." | umgesetzt |
| `Health/GymNeu/GymStartView.swift:293` ("..." im Gym-Start, Freies Training) | Menu | "Mehr: Plan vom Partner, Verlauf, Messungen, Übungen, Split wechseln oder frei trainieren ohne Plan." | umgesetzt |
| `Health/GymNeu/SplitAnsichten.swift:92` (Chip "Für dich") | Filterchip | "Für dich zeigt nur deine eigenen gespeicherten Splits." | umgesetzt |
| `Health/WorkoutView.swift:206` (Puls-Schalter) | Toggle | bereits mit sichtbarem Text erklärt ("Braucht AirPods Pro 3...") | übersprungen, schon erklärt |
| `Health/WorkoutView.swift:362` (Übung gedrückt halten = auslassen) | onLongPressGesture (indirekt über contextMenu) | bereits als sichtbarer Text da: "Halte eine Übung gedrückt, um sie auszulassen." | übersprungen, schon erklärt |
| `Health/WorkoutView.swift:718` (Satz wischen) | swipeActions, TipView über der Tabelle | "Nach links wischen löscht einen Satz." | umgesetzt |
| `Health/TrainingsPlanView.swift:387/392` (Übungszeile wischen, Plan bearbeiten) | swipeActions beidseitig, TipView über der Liste | "Nach links wischen löscht. Nach rechts wischen verdoppelt die Übung." | umgesetzt |
| `Health/GymNeu/SplitEditorView.swift:167` ("..." beim Trainingstag) | Menu | "Tag umbenennen oder löschen." | umgesetzt |

## Health / Ernährung

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Health/Ernaehrung/EinkaufView.swift:112` ("..." in einer Einkaufsliste) | Menu | "Mehr: Erledigte löschen, Liste umbenennen oder löschen." | umgesetzt |
| `Health/Ernaehrung/EinkaufView.swift:22` (Einkaufsliste wischen) | swipeActions (Zeile in `ForEach`) | "Nach links wischen löscht eine Liste oder benennt sie um." | nicht umgesetzt — Zeile liegt in `ForEach`, ein Tip pro Zeile hätte auf jeder Liste gleichzeitig gepoppt, siehe Regel "nicht nerven" |
| `Health/Ernaehrung/ErnaehrungView.swift:115` ("..." Tagesmenü) | Menu | "Auswertung, Nährwerte, Fasten, Einkaufsliste, Tagebuch anpassen oder zum Tag des Partners wechseln." | umgesetzt |
| `Health/Ernaehrung/ErnaehrungMahlzeit.swift:56` ("..." bei einer Mahlzeit) | Menu | "Übernimmt die gestrige Mahlzeit für heute." | umgesetzt |
| `Health/Heute/HeuteView.swift:777/794` (Wasser-/Koffein-/Creatin-Kachel gedrückt halten) | contextMenu | "Tippen zählt eins hoch. Gedrückt halten zeigt Abziehen und den Verlauf des Tages." | umgesetzt — ein Tip auf der Wasser-Kachel, gilt für alle drei (gleiches Muster) |
| `Health/Ernaehrung/HinzufuegenTeile.swift:268/336` (Lebensmittel gedrückt halten) | contextMenu (Zeile in `ForEach`) | "Gedrückt halten bearbeitet oder löscht ein eigenes Lebensmittel." | nicht umgesetzt — Zeile in `ForEach`, gleiche Begründung wie oben |

## Kalender

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Kalender/Neu/TagesListe.swift:96` (Termin gedrückt halten) | contextMenu | "Tippen bearbeitet einen Termin. Lang drücken zeigt mehr: zum iPhone-Kalender, löschen." | umgesetzt |
| `Kalender/TreffenTagView.swift:87` ("Mehr" beim Treffen) | Menu | "Bearbeiten, zum iPhone-Kalender oder absagen." | umgesetzt |

## Chat

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Chat/ChatNachrichtRow.swift` (Nachricht gedrückt halten / doppelt tippen) | simultaneousGesture + onTapGesture(count:2) | "Doppelt tippen sendet ein Herz. Gedrückt halten zeigt Reaktionen und Antworten." | umgesetzt — TipView im festen Kopfbereich `ChatTab.swift` (`oben`), nicht pro Nachrichtenzeile (sonst ein Tip pro Zeile) |
| `Chat/Medien/FotoStapel.swift:146` (Foto im Vollbild gedrückt halten) | contextMenu | "Gedrückt halten speichert das Foto in der Galerie." | umgesetzt — TipView im festen Kopf-Overlay von `MedienGalerie`, nicht pro Seite |

## Zeichnen (Drawing)

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Drawing/Library/DrawingView.swift:330` ("..." Projekt) | Menu | "Mehr: Projekt teilen, umbenennen oder löschen." | umgesetzt |
| `Drawing/Studio/DrawingStudioView.swift:161` ("..." im Zeichenstudio) | Menu | "Mehr: Ansicht spiegeln oder zurücksetzen, und je nach Werkzeug weitere Optionen." | umgesetzt |
| `Drawing/Studio/ToolRail.swift:159` ("..." Werkzeugleiste) | Menu | "Mehr Werkzeuge: als Schablone, als Ebene, Pinsel wählen." | umgesetzt |
| `Drawing/Studio/ArtworkLayersView.swift:31` (Ebene gedrückt halten / wischen) | contextMenu + swipeActions | "Gedrückt halten oder nach links wischen zeigt Ebenen-Optionen, auch Löschen." | umgesetzt |

## Figuren

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Figuren/FigurGesten.swift` (Figur tippen/gedrückt halten) | onTapGesture + onLongPressGesture | "Tippen öffnet Anstupsen, Kuss und Ausdrücke. Gedrückt halten schickt sofort ein Herz." | umgesetzt |

(`FigurView.swift` und `GesichterNeuPfade.swift` sind gesperrt und nicht angefasst — `FigurGesten.swift` ist das nicht.)

## Spiele

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Spiele/DuellRueckblick.swift:119` ("..." beim Duell-Bild) | Menu | "In den Chat senden oder in Aufnahmen speichern." | umgesetzt |

## Einstellungen

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Einstellungen/EinstellungenView.swift:67` ("Zwischen Tabs wischen") | Toggle | hat schon einen sichtbaren Footer-Text darunter | übersprungen, schon erklärt |

## Ausgelassen

- Die vier gesperrten Zyklus-Dateien und `Figuren/FigurView.swift`, `GesichterNeuPfade.swift`: nur
  Textvorschläge oben, kein Code geändert.
- Profile-Bereich (`ProfileView.swift`, `ZimmerEditor.swift`, `ZimmerZeichnung.swift` …): keine
  verdeckten Gesten oder Menüs gefunden (keine `contextMenu`, `swipeActions`, `onLongPressGesture`,
  kein "..."-Menü) — nichts zu erklären.
- Kleinere Menüs mit bereits sprechendem Label (z. B. `Health/WorkoutView.swift:650` Pausentimer,
  zeigt den aktuellen Wert direkt im Label) wurden übersprungen, um die App nicht zu überladen.
- Zeilen-Gesten in `ForEach`/`List` (Einkaufsliste wischen, Lebensmittel gedrückt halten): bewusst
  ohne Tip, weil ein `.popoverTip` dort auf jeder Zeile gleichzeitig aufpoppen würde — siehe
  "nicht nerven"-Regel. Ein fester TipView-Header wäre möglich, aber dort schon durch andere
  Tips (Kalender, Satz-Tabelle) gut abgedeckt.
