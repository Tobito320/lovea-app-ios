# Lovea

Native SwiftUI-App für Ahmed und Annika. Die erste Version konzentriert sich auf Zeichnen.

## Produktplan

Der verbindliche Bauplan für den Zeichen-Bereich liegt unter [`docs/DRAWING-ROADMAP.md`](docs/DRAWING-ROADMAP.md).

Priorität:

1. Level 1 – vollständiges persönliches Zeichnen auf iPad/iPhone
2. Level 2 – Projekte/Zeichnungen als Bild oder read-only teilen
3. Level 3 – eine konkrete Zeichnung gemeinsam bearbeiten

Das alte permanente Shared Board gehört nicht mehr zum Produktplan.

## Enthalten

- Personenauswahl bei jedem App-Start: Ahmed oder Annika
- genau drei Tabs: Home, Zeichnen und Profil
- MetalKit-Zeichenfläche mit Apple-Pencil- und Touch-Eingabe
- Pinsel, Radierer, Farben und Strichstärke
- Zwei-Finger-Zoom und Verschieben
- Ebenen, Undo, Redo, lokales Autosave und Bildexport
- iPhone und iPad ab iOS 18

## Projekt erzeugen

```sh
brew install xcodegen
xcodegen generate
open Lovea.xcodeproj
```

Bundle ID: `com.onlyus.lovea`

Es werden keine Secrets benötigt. Die erzeugte Xcode-Projektdatei wird nicht eingecheckt.
