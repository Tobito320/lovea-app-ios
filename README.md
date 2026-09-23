# Lovea

Native SwiftUI-App für Ahmed und Annika. Der aktuelle Entwicklungsfokus liegt auf **Zeichnen**.

## Produktplan

Der verbindliche Bauplan für den Zeichen-Bereich liegt unter [`docs/DRAWING-ROADMAP.md`](docs/DRAWING-ROADMAP.md).

Priorität:

1. Level 1 – vollständiges persönliches Zeichnen auf iPad/iPhone
2. Level 2 – Projekte/Zeichnungen als Bild oder read-only teilen
3. Level 3 – eine konkrete Zeichnung gemeinsam bearbeiten

Das alte permanente Shared Board gehört nicht mehr zum Produktplan.

## Aktueller Zeichen-Stand

Level 1 ist gebaut und wartet auf die Abnahme am iPad: [`docs/LEVEL1-ABNAHME.md`](docs/LEVEL1-ABNAHME.md).

## Zeichen-Engine (Level 1)

1. Jede Ebene ist eine GPU-Textur in Dokumentgröße (`LayerTextureStore`, `rgba8Unorm`, vormultipliziert). Bildebenen behalten ihr Foto als eigene Textur plus `LayerTransform`.
2. Ein Strich wird zu Stempeln (`StrokeSampler`: Live-Stabilisator, Druckkurve, Neigung, Abstand). `BrushStamper` malt alle neuen Stempel eines Frames mit einem instanzierten Draw in eine Scratch-Textur.
3. Die Scratch-Textur wird live über der aktiven Ebene gezeigt und beim Absetzen einmal übernommen (normal, Radierer, Alpha Lock). So baut sich die Deckkraft im Strich nicht auf.
4. `Compositor` setzt die Ebenen auf der GPU zusammen (8 Mischmodi nach W3C, Clipping wie ibisPaint). Alles unter und über der aktiven Ebene liegt als Cache bereit. Ein Frame blendet nur unten + aktiv (+ Strich) + oben.
5. `MTKView` zeichnet nur bei Eingabe, Geste oder Änderung. Im Stillstand gibt es keine Frames.
6. Undo speichert pro Strich nur das betroffene Rechteck (`UndoHistory`, 256 MiB). Ebenen-Aktionen sind Dokument-Schritte.
7. Gespeichert wird 1 s nach der letzten Änderung, im Hintergrund und atomar: erst die geänderten Ebenen als PNG, dann `document.json`.
8. Füllen, Pipette, Auswahl, Transformieren, Formen, Text und Anpassungen laufen über dieselbe Engine. Readbacks sind asynchron, CPU-Arbeit läuft im Hintergrund.
9. Alte Zeichnungen (Schema 2: JSON-Striche und PencilKit) werden beim Öffnen einmal in Texturen gerastert (`LegacyMigration`). Die alten Dateien bekommen die Endung `.migrated`.
10. `CanvasEngine` ist die einzige Schnittstelle für Pixel. `DrawingSession` hält nur Werkzeug, Pinsel, Farben und die aktive Ebene.

Code: `Lovea/Sources/Drawing/Engine` (Pixel), `Studio` (Oberfläche), `Library` (Galerie, Dateien), `Teilen` (Level 2/3, gemeinsames Zeichnen).

## Projekt erzeugen

```sh
brew install xcodegen
xcodegen generate
open Lovea.xcodeproj
```

Bundle ID: `com.onlyus.lovea`

Die lokale Zeichenfunktion benötigt keine Secrets. Die normale CI baut ohne `LOVEA_APP_KEY`/`LOVEA_SERVER`; die App zeigt dann „Server nicht eingerichtet“ statt abzustürzen.

## Server

Backend ist ein Cloudflare-Worker mit genau einem Durable Object `Raum` (Speicher: SQLite). Zwei Worker:

- `lovea-live`: Produktion, verbunden mit der echten App.
- `lovea-test`: zum Prüfen, benutzt von `pruefen.mjs` und für Testläufe des Umzugs.

Ausrollen:

```sh
cd server
npx wrangler deploy --env test
npx wrangler deploy --env live
```

Worker-Secrets (nur die Namen, Werte stehen nie im Repo oder in Notizen):

- `LOVEA_APP_KEY`
- `APNS_KEY_P8`
- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `KLIPY_KEY`

Tests:

```sh
cd server
node --test
```

`server/pruefen.mjs` verbindet gegen einen laufenden Worker (meist `lovea-test`), schickt eine Op, prüft das Echo mit `seq`, verbindet neu und holt sie über `seit=0` nach, lädt dann ein zweiteiliges Medium hoch und wieder runter:

```sh
node server/pruefen.mjs https://lovea-test.<konto>.workers.dev
```

`server/umzug.mjs` liest einmalig die alten Daten der Web-App aus Supabase und schreibt sie als Ops in den neuen Raum (Kalender, Pünktlich, Fragen, Themen, Liste, Ideen, gesendete Zeichnungen, Galerie, Aufkleber). Erst ein Probelauf gegen `lovea-test`, dann gegen `live`:

```sh
node --env-file=C:\Users\ahmed\code\lovea-app\.env server/umzug.mjs --ziel test --trocken
```

## Architektur

Alles Dauerhafte läuft als Operation (`Op`): Ein Gerät erzeugt eine Op mit eigener `id`, schickt sie über die eine WebSocket-Verbindung zum Raum. Der Server vergibt eine laufende Nummer `seq`, speichert die Op und schickt sie an beide Geräte. Offline sammelt eine Warteschlange die Ops und sendet sie nach, sobald wieder Netz da ist. Doppelte `id`s verwirft der Server. Beim Verbinden holt jedes Gerät alles ab seiner letzten `seq` nach.

Flüchtige Nachrichten (`fl`) werden nie gespeichert: Tippt-Status, Figuren-Zustand, Live-Strichpunkte beim gemeinsamen Zeichnen, Live-Standort. Ausnahme: den letzten Standort-Punkt schreibt der Server gedrosselt (höchstens einmal pro Minute) weg.

Medien (Fotos, Videos, Sprachnachrichten) gehen in Stücken von höchstens 1 MiB per HTTP-PUT zum Server und liegen dort als SQLite-BLOB im Raum. Sobald der Partner das Original abgeholt hat und die kleine Reserve-Version bereits hochgeladen ist, löscht der Server das Original.

Push geht direkt an Apple (APNs, HTTP/2, Token per WebCrypto, keine Bibliothek), für Geräte, die gerade nicht verbunden sind. Zeitgesteuertes läuft über Durable-Object-Alarme: Vorabend-Erinnerung, Erinnerung eine Stunde vorher, Pünktlich-Karte, Frage des Tages, Streak-Warnung, Ablauf angehefteter Nachrichten und verfallende Spiel-Einladungen.

App-Ordner unter `Lovea/Sources`:

- `App`: Einstieg, erster Start, Personen-Auswahl, Schlüsselbund, Farben.
- `Sync`: `Op`, Raum-Verbindung, Warteschlange, `OpLog`, Medien-Up-/Download.
- `Figuren`: Aussehen, Editor, Zustand und Gesten der Bitmoji-Figuren.
- `Anwesenheit`: Live-Status des Partners, In-App-Banner.
- `Chat`: Verlauf, Eingabe, Kopfzeile, Medien (GIFs, Sprachnachrichten, Sticker).
- `Snaps`: Kamera, Editor, Betrachter, Streak.
- `Karte`: Kartenansicht, Orte, Standort, Info-Karte.
- `Home`: Startseite mit ihren Karten (nächstes Treffen, Stimmung, Frage des Tages …).
- `Kalender`: Monats-/Tagesansicht, Wochenplan-Editor, Logik (Feiertage, Ferien, Pünktlich).
- `Wir`: Frage des Tages, Pünktlich-Karte, gemeinsame Liste und Würfel.
- `Spiele`: Duell, Memory, XO und die anderen Chat-Spiele.
- `Profile`, `Einstellungen`: eigenes Profil und Einstellungsliste.
- `Drawing`: Zeichen-Engine (`Engine`), Oberfläche (`Studio`), Galerie (`Library`), gemeinsames Zeichnen (`Teilen`, Level 2/3).

## CI

GitHub Actions erzeugt das Xcode-Projekt mit XcodeGen und testet den Stand auf einem iPhone- und einem iPad-Simulator.
