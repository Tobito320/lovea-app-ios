# Gym wie Hevy

Stand: 01.10.2026. Entschieden mit Ahmed im Gespräch. Er hat danach gesagt: "Programmier mal, Feinschliff später."
Diese Datei hält die Entscheidungen fest. Sie ist kein Entwurf zur Freigabe mehr.

## Ziel

Der Gym-Bereich von Lovea soll sich wie die App Hevy bedienen lassen. Bisher konnte man nur ganze Übungen abhaken.
Ahmed: "Dieses Gym-Fenster ist eine Katastrophe, ich kann es kaum nutzen."

Vorlagen: 14 Bilder aus Hevy im Vault unter `19 Bastelprojekte/Lovea-bilder/inspiration-hevy/`, beschrieben in
`Lovea – Inspiration.md`, Abschnitt Health. Das Aussehen folgt diesen Bildern: Blau für Aktionen, Grün für fertige Sätze.

## Vier Teile

Hevy ist zu groß für einen Plan. Reihenfolge:

1. **Training loggen** (diese Spec, gebaut am 01.10.)
2. Routinen und Übungen: Ordner, Bibliothek mit Filtern nach Muskel und Gerät, eigene Übungen, "So geht's"-Texte
3. Verlauf und Fortschritt: Rekorde, Diagramme pro Übung, Kalender, Serien, Messungen (Gewicht gibt es schon in Health, keine zweite Datenquelle)
4. Puls und Kalorien über AirPods Pro 3 (braucht ein Apple-Workout auf dem iPhone, kostet Akku, nur auf Wunsch pro Training; Annika hat normale AirPods und damit keinen Puls)

Teil 2 bis 4 bekommen je eine eigene Spec.

## Teil 1: Entscheidungen

| Nr. | Thema | Entscheidung |
|---|---|---|
| 1 | Start | Ein Knopf. "Training starten" checkt ein und öffnet das Training. "Beenden" checkt aus. Ein leeres Training ohne Plantag geht auch. |
| 2 | Satztypen | Normal, W (Aufwärmen), D (Drop), F (bis zum Versagen). W zählt nicht für Volumen, Rekorde und "Sätze diese Woche". |
| 2b | Zeit messen | Großer Knopf unten: "Übung starten" / "Satz fertig" / "Nächster Satz". Er misst Satzdauer und Pause. Oder einfach nur den Haken tippen. Die Pause wird nie abgehakt. Nach dem letzten Satz bietet der Knopf die nächste Übung an. |
| 3 | Pause | Zählt rückwärts, Zeit pro Übung einstellbar (Standard 2:00, auch "aus"). Am Ende nur Vibration, kein Ton. Danach zählt sie rot weiter hoch. Die echte Länge wird gespeichert. |
| 4 | Supersätze | Später. Die Daten sind so gebaut, dass sie ohne Umbau dazu passen. |
| 5 | Plan | "Vorher" und die vorausgefüllten Werte kommen aus dem letzten Training. Der Plan ändert sich nur, wenn man beim Beenden "Plan aktualisieren" bestätigt. Gefragt wird nur, wenn sich der Aufbau geändert hat (Übungen, Zahl oder Typ der Sätze). |
| 6 | Zu zweit | Jeder kann das Training des anderen lesen, ändern nur das eigene. Eine Mitteilung beim Beenden, gebündelt ("58 min im Gym, 2 Rekorde"). |
| 7 | Extras | Notiz pro Übung (bleibt im Plan), RPE-Spalte (ausblendbar), Scheibenrechner, Aufwärm-Rechner. RPE, Satzzeiten und Pausen werden gespeichert, damit eine spätere KI sie auswerten kann. |
| 8 | Sperrbildschirm | Live-Aktivität zeigt Übung, "Satz 2 von 3", "32 kg × 12" und die laufende Zeit. Ein Knopf für den nächsten Schritt. |
| 10 | Aufbau | Erst die Übersicht aller Übungen mit Stand ("2/3", fertig grün, die aktuelle hervorgehoben). Ein Tipp öffnet nur diese eine Übung. Zurückwischen zeigt wieder alle. |

## Daten

Alles bleibt in den vorhandenen `gym.*`-Ops, kein neuer Op-Typ, kein Server-Umbau.

- `PlanSatz` bekommt optional `typ` ("w", "d"), `rpe`, `ok`, `sek` (Satzdauer), `pause` (Pause danach). `failure` bleibt für "F", damit ältere Builds es lesen.
- `PlanUebung` bekommt optional `notiz` und `pause` (Sekunden).
- `gym.uebung` bekommt zwei neue Werte für `status`:
  - `"satz"`: der ganze Stand der Satzzeilen einer Übung, neuester gilt. Gesendet bei Haken, Satzstart und Löschen, nicht bei jedem Tastendruck.
  - `"weg"`: nimmt eine im Training dazugekommene Übung wieder heraus.
- `UebungsLauf.saetze` enthält weiter nur gezählte Sätze (abgehakt, ohne Aufwärmen). Körper, Verlauf und Hinweise rechnen damit unverändert. Der volle Stand liegt in `UebungsLauf.stand`.
- Alle neuen Felder sind optional. Alte Ops und Pläne bleiben lesbar (Test `testOldSetAndPlanJsonStillDecode`).
- Ein älterer Build ignoriert `"satz"` und `"weg"` (`default: break`). Beide Handys sollten trotzdem denselben Build haben.

Was gerade läuft (Satz oder Pause, seit wann) liegt nur auf dem Gerät in `WorkoutUhr`, nicht in einem Op.

## Dateien

- `Health/Training.swift`: Datenfelder, Faltung der neuen Status.
- `Health/Workout.swift`: `WorkoutLogik` (Zeilen, Vorher, was dran ist, Volumen, Plan-Frage, Rechner), `WorkoutUhr`, `WorkoutAktion`.
- `Health/WorkoutView.swift`: `GymSessionView` (Übersicht), `WorkoutUebungView` (eine Übung), `WorkoutSatzZeile`, `WorkoutLeiste`, `ScheibenBlatt`.
- `Health/GymLive.swift`, `LoveaWidgets/…/GymLiveWidget.swift`, `GymAktivitaet.swift`: Live-Aktivität.
- `Health/stille.wav`: stiller Ton, damit die Pausen-Mitteilung nur vibriert.

## Akku

- Uhren zeichnet iOS selbst aus Zeitpunkten. Es läuft kein eigener Timer, auch nicht im Hintergrund.
- Netz: ein kleiner Op pro Haken und pro Satzstart. Keine Abfragen.
- Das Pausenende im Hintergrund ist eine einmal vorab geplante lokale Mitteilung.
- Die alte 30-Sekunden-Uhr um den ganzen Bildschirm ist weg.

## Noch offen in Teil 1

- Knopf in der Live-Aktivität (Satz vom Sperrbildschirm abhaken). Die Anzeige ist gebaut, der Knopf noch nicht.
- Training des Partners ansehen und die gebündelte Mitteilung beim Beenden. Die Mitteilung braucht `server/`, das die Sitzung "Essen wie YAZIO" gesperrt hat.
- Einchecken von Hand mit Uhrzeit nachtragen.
- Aussehen am Gerät nachschärfen. Beim Bauen gilt der Skill `impeccable` mit den iOS-Regeln.
- Ob die Vibration bei gesperrtem Handy wirklich ohne Ton kommt, muss am Gerät geprüft werden.
