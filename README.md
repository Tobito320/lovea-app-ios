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

Code: `Lovea/Sources/Drawing/Engine` (Pixel), `Studio` (Oberfläche), `Library` (Galerie, Dateien), `Sharing` (Level 2, eingefroren).

## Projekt erzeugen

```sh
brew install xcodegen
xcodegen generate
open Lovea.xcodeproj
```

Bundle ID: `com.onlyus.lovea`

Die lokale Zeichenfunktion benötigt keine Secrets. Level-2-Freigaben benutzen die vorhandene private Lovea-Anmeldung; PIN und privates Datum stehen nicht im Quellcode.

## CI

GitHub Actions erzeugt das Xcode-Projekt mit XcodeGen und testet den Stand auf einem iPhone- und einem iPad-Simulator.
