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

## Zyklus

Gesperrt (PR #83, nur Textvorschläge): `ZyklusHeuteView.swift`, `ZyklusEinstellungenBlatt.swift`,
`ZyklusLogik.swift`, `ZyklusVorhersage.swift`. Die Knöpfe "Heute eintragen" und "Periode beginnt
heute" liegen beide in der gesperrten `ZyklusHeuteView.swift`. Wer die Tips dort einbaut: gleiches
Muster wie unten (TipKit, Tip aus `AppErklaerungen.swift`, `.popoverTip` oder `TipView`).

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Zyklus/ZyklusHeuteView.swift:256` ("Heute eintragen") | Button | "Tippe auf einen Tag, um Periode, Stimmung oder Symptome einzutragen." | nur Vorschlag (gesperrt) |
| `Zyklus/ZyklusHeuteView.swift:258` ("Periode beginnt heute") | Button | "Setzt den heutigen Tag als ersten Periodentag und rechnet die Vorhersage neu." | nur Vorschlag (gesperrt) |
| `Zyklus/ZyklusInsightsView.swift:63` (Zahlenkarte: Tage Zyklus/Periode/Streuung) | ZyklusKarte, nicht gesperrt | "Durchschnitt aus deinen eingetragenen Zyklen. Streuung zeigt, wie stark sie sich unterscheiden – je mehr eingetragen ist, desto genauer." | umgesetzt |

`ZyklusInsightsView.swift` und `ZyklusInsightsLogik.swift` sind nicht gesperrt — der Insights-Tip
oben ist echter Code, kein Vorschlag. Die übrigen 21 Zyklus-Dateien (`ZyklusEintragBlatt.swift`,
`ZyklusKalenderView.swift` …) haben keine versteckten Gesten oder Menüs (kein `contextMenu`,
`swipeActions`, `onLongPressGesture`, `Menu {`, `ellipsis`) — nichts dort zu erklären.

## Gym / Training

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Health/WorkoutView.swift:534` (Training beenden) | Button | "Fertige Sätze zählen. Was offen bleibt, steht beim nächsten Mal wieder im Plan." | umgesetzt |
| `Health/WorkoutView.swift:408` (Titel-Menü, Trainingstag wechseln) | Menu (Pfeil am Titel) | "Tippen wechselt zu einem anderen Trainingstag." | umgesetzt |
| `Health/WorkoutView.swift:758` ("..." bei einer Übung) | Menu | "Mehr zu dieser Übung: Animation, Aufwärmsätze, Scheibenrechner, auslassen oder entfernen." | umgesetzt |
| `Health/WorkoutView.swift:527` (Laufband/Stairmaster-Knöpfe) | Button | "Öffnet ein Cardio-Formular für Zeit und Strecke. Zählt nicht als Satz." | umgesetzt |
| `Health/GymNeu/GymStartView.swift:303` ("..." im Gym-Start, Freies Training) | Menu | "Mehr: Plan vom Partner, Verlauf, Messungen, Übungen, Split wechseln oder frei trainieren ohne Plan." | umgesetzt |
| `Health/GymNeu/SplitAnsichten.swift:92` (Chip "Für dich") | Filterchip | "Für dich zeigt nur deine eigenen gespeicherten Splits." | umgesetzt |
| `Health/WorkoutView.swift:206` (Puls-Schalter) | Toggle | bereits mit sichtbarem Text erklärt ("Braucht AirPods Pro 3...") | übersprungen, schon erklärt |
| `Health/WorkoutView.swift:362` (Übung gedrückt halten = auslassen) | onLongPressGesture (indirekt über contextMenu) | bereits als sichtbarer Text da: "Halte eine Übung gedrückt, um sie auszulassen." | übersprungen, schon erklärt |
| `Health/WorkoutView.swift:719` (Satz wischen, TipView bei :603) | swipeActions, TipView über der Tabelle | "Nach links wischen löscht einen Satz." | umgesetzt |
| `Health/TrainingsPlanView.swift:387/392` (Übungszeile wischen, Plan bearbeiten) | swipeActions beidseitig, TipView über der Liste | "Nach links wischen löscht. Nach rechts wischen verdoppelt die Übung." | umgesetzt |
| `Health/GymNeu/SplitEditorView.swift:167` ("..." beim Trainingstag) | Menu | "Tag umbenennen oder löschen." | umgesetzt |

## Health / Ernährung

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Health/Ernaehrung/EinkaufView.swift:112` ("..." in einer Einkaufsliste), Tip bei `:115` | Menu | "Mehr: Erledigte löschen, Liste umbenennen oder löschen." | umgesetzt |
| `Health/Ernaehrung/EinkaufView.swift:22` (Einkaufsliste wischen) | swipeActions (Zeile in `ForEach`) | "Nach links wischen löscht eine Liste oder benennt sie um." | nicht umgesetzt — Zeile liegt in `ForEach`, ein Tip pro Zeile hätte auf jeder Liste gleichzeitig gepoppt, siehe Regel "nicht nerven" |
| `Health/Ernaehrung/ErnaehrungView.swift:115` ("..." Tagesmenü) | Menu | "Auswertung, Nährwerte, Fasten, Einkaufsliste, Tagebuch anpassen oder zum Tag des Partners wechseln." | umgesetzt |
| `Health/Ernaehrung/ErnaehrungMahlzeit.swift:56` ("..." bei einer Mahlzeit) | Menu | "Übernimmt die gestrige Mahlzeit für heute." | umgesetzt |
| `Health/Heute/HeuteView.swift:777/794` (Wasser-/Koffein-/Creatin-Kachel gedrückt halten) | contextMenu | "Tippen zählt eins hoch. Gedrückt halten zeigt Abziehen und den Verlauf des Tages." | umgesetzt — ein Tip auf der Wasser-Kachel, gilt für alle drei (gleiches Muster) |
| `Health/Ernaehrung/HinzufuegenTeile.swift:268/336` (Lebensmittel gedrückt halten) | contextMenu (Zeile in `ForEach`) | "Gedrückt halten bearbeitet oder löscht ein eigenes Lebensmittel." | nicht umgesetzt — Zeile in `ForEach`, gleiche Begründung wie oben |

## Kalender

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Kalender/Neu/TagesListe.swift:29` (TipView), Termin gedrückt halten bei `:96` | contextMenu | "Tippen bearbeitet einen Termin. Lang drücken zeigt mehr: zum iPhone-Kalender, löschen." | umgesetzt |
| `Kalender/TreffenTagView.swift:87` ("Mehr" beim Treffen) | Menu | "Bearbeiten, zum iPhone-Kalender oder absagen." | umgesetzt |

## Chat

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Chat/ChatNachrichtRow.swift` (Nachricht gedrückt halten / doppelt tippen) | simultaneousGesture + onTapGesture(count:2) | "Doppelt tippen sendet ein Herz. Gedrückt halten zeigt Reaktionen und Antworten." | umgesetzt — TipView im festen Kopfbereich `ChatTab.swift` (`oben`), nicht pro Nachrichtenzeile (sonst ein Tip pro Zeile) |
| `Chat/Medien/FotoStapel.swift:146` (Foto im Vollbild gedrückt halten) | contextMenu | "Gedrückt halten speichert das Foto in der Galerie." | umgesetzt — TipView im festen Kopf-Overlay von `MedienGalerie`, nicht pro Seite |

## Zeichnen (Drawing)

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Drawing/Library/DrawingView.swift:334` ("..." Projekt) | Menu | "Mehr: Projekt teilen, umbenennen oder löschen." | umgesetzt |
| `Drawing/Studio/DrawingStudioView.swift:165` ("..." im Zeichenstudio) | Menu | "Mehr: Ansicht spiegeln oder zurücksetzen, und je nach Werkzeug weitere Optionen." | umgesetzt |
| `Drawing/Studio/ToolRail.swift:167` ("..." Werkzeugleiste) | Menu | "Mehr Werkzeuge: als Schablone, als Ebene, Pinsel wählen." | umgesetzt |
| `Drawing/Studio/ArtworkLayersView.swift:26` (TipView), Ebene gedrückt halten/wischen bei `:32` | contextMenu + swipeActions | "Gedrückt halten oder nach links wischen zeigt Ebenen-Optionen, auch Löschen." | umgesetzt |

## Figuren

| Datei:Zeile | Geste/Menü | Hinweistext | Status |
|---|---|---|---|
| `Figuren/FigurGesten.swift` (Figur tippen/gedrückt halten) | onTapGesture + onLongPressGesture | "Tippen öffnet Anstupsen, Kuss und Ausdrücke. Gedrückt halten schickt sofort ein Herz." | umgesetzt |

(`FigurView.swift` und `GesichterNeuPfade.swift` sind gesperrt und nicht angefasst — `FigurGesten.swift` ist das nicht.)

## Rechenlogik

| Datei:Zeile | Was wird berechnet | Hinweistext | Status |
|---|---|---|---|
| `Health/WorkoutView.swift:376` (Volumen) | `WorkoutLogik.volumen`: kg × Wdh, über alle gezählten Sätze | "Kilogramm mal Wiederholungen, über alle gezählten Sätze addiert." | umgesetzt |
| `Health/WorkoutView.swift:699` (Rekord-Marke an einem Satz) | `RekordLogik.neue` gegen frühere Einheiten derselben Übung (Gewicht, e1RM, Satz-Volumen) | — | nicht umgesetzt, Marke erscheint nur an einzelnen Sätzen in `ForEach` (Zeilen-Gesten-Regel) |
| `Health/Heute/HeuteView.swift` (Koffein-Kachel) | ~`KoffeinLogik.mgProTasse` mg je Tasse | im contextMenu-Verlauf schon als Text sichtbar ("~X mg") | übersprungen, schon erklärt |
| `Health/Heute/HeuteView.swift:913` (Creatin-Kachel) | `Habit.creatinGramm` g je Klick | im Kachel-Zusatztext schon sichtbar (g-Anzeige) | übersprungen, schon erklärt |
| `Zyklus/ZyklusInsightsLogik.swift` (Regelmäßigkeit/Streuung) | Abweichung der Zykluslängen in Tagen | siehe Zyklus-Tabelle oben (`ZyklusZahlenTip`) | umgesetzt |

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
