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

- genau drei Tabs: Home, Zeichnen und Profil
- `Meine Galerie` mit mehreren Zeichnungen und Projekten
- lokale Artwork-Ordner mit Dokument, Vorschau und getrennten Layer-Dateien
- PencilKit-Zeichenfläche für iPad/Apple Pencil und iPhone
- zehn kuratierte Brush-Presets
- Pinsel, Radierer, Lasso, Pipette und Farbeimer
- Foto aus der Mediathek als eigene Ebene
- Schnellaktion `Foto als Schablone`
- Paint- und Image-Layer
- Sichtbarkeit, Sperren, Deckkraft, Duplizieren, Reihenfolge und Merge-down
- acht Blend Modes, Clipping und Transparenz schützen
- Formen und Text
- Zoom, Verschieben, Lineal, Undo/Redo und Mehrfinger-Gesten
- lokales Autosave, Galerie-Vorschauen und Bildexport
- Level 2: Snapshot senden, read-only Live-Freigabe und Projektfreigabe über das private Lovea-Backend
- iPhone und iPad ab iOS 18

## Architektur

- `ArtworkLibrary` – Galerie, Projekte und lokale Dateien
- `DrawingSession` – Dokumentzustand und Zeichenaktionen
- `PencilCanvasRepresentable` – PencilKit-Eingabe
- `ArtworkRenderer` – Ebenen-Compositing und Export
- `LoveaSharingService` – Level-2-Freigaben

Die alte Metal-Zeichenbasis liegt noch im Repository, ist aber nicht mehr der Hauptpfad des aktuellen Studios.

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
