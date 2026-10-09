# Galerie-Sync: ein Profil, alle Geräte

Stand 27.09.2026. Auftrag von Ahmed: Annika nutzt ein Profil auf iPhone und iPad. Was auf einem Gerät
in der Zeichnungs-Galerie passiert, soll auf dem anderen genauso da sein. Kein "rüberschicken", echter Sync.

## Ist-Zustand

- `Drawing/Library/ArtworkLibrary.swift`: Galerie nur lokal in `Application Support/Lovea/`
  (`library.json` = Projekte + Reihenfolge, `Artworks/<id>/` = Dokument-JSON, Ebenen-Dateien, Vorschau).
- `Chat/Medien/StickerErstellung.swift` `EigeneSticker`: Liste eigener Sticker (Medien-IDs), nur lokal.
- Server (seit `b562818`): Ops mit Art `galerie.*` gehen live und beim Nachholen nur an die Geräte des
  Absenders, nie an den Partner.
- `Sync/Medien.swift`: `hochladen(id:original:klein:)`, `holen(_:)`, chunked, fortsetzbar.

## Ops (alle privat, nur eigene Geräte)

| Art | d | Bedeutung |
|---|---|---|
| `galerie.stand` | `{artworkId, dokument, dateien: {dateiname: medienId}}` | ganzer Stand einer Zeichnung |
| `galerie.geloescht` | `{artworkId, zeit}` | Zeichnung gelöscht |
| `galerie.projekte` | `{projekte: [ArtworkProject], reihenfolge: [UUID]}` | Projekte/Ordner, letzter gewinnt |
| `galerie.sticker` | `{medienIds: [String]}` | eigene Sticker, letzter gewinnt |

- `dokument` ist das `ArtworkDocument`-JSON (nur Metadaten der Ebenen, keine Pixel). Klein halten, die Op
  bleibt dauerhaft im OpLog und wird bei jedem Start dekodiert.
- `dateien` deckt jede Datei der Zeichnung ab: `contentFile`, `alphaMaskFile` jeder Ebene, dazu die Vorschau
  unter dem Schlüssel `vorschau.jpg`.
- `medienId = "galerie-<person>-<sha256 hex der Bytes>"`. Inhaltsadressiert: eine unveränderte Ebene wird
  nicht erneut hochgeladen. Das Personen-Präfix verhindert, dass gleiche Bytes (leere Ebene) bei beiden
  Profilen dieselbe ID bekommen; der Server räumt ein Original auf, sobald eine andere Person als der
  Hochlader es abholt (`medienLesen`).

## Senden

- Eine Zeichnung ist "schmutzig", wenn sie lokal gespeichert, umbenannt, verschoben, dupliziert oder neu
  angelegt wurde. Merker in `GalerieSync`, nicht bei jedem Strich hochladen.
- Hochgeladen wird beim Schließen des Studios und beim Wechsel der App in den Hintergrund (Akku), nicht
  nach jedem Speichern. Reihenfolge: erst alle Dateien per `Medien.hochladen` (fehlende Teile), dann die
  Op `galerie.stand`. Scheitert ein Upload, bleibt die Zeichnung schmutzig und wird beim nächsten Anlass
  erneut versucht (Merker persistent, UserDefaults).
- Löschen sendet sofort `galerie.geloescht`. Projektänderungen senden `galerie.projekte`.
- Erststart pro Gerät (UserDefaults-Flag `galerie.sync.backfill`): alle lokalen Zeichnungen als schmutzig
  markieren; hochgeladen wird nacheinander, eine Zeichnung nach der anderen, nicht parallel. Einmal
  `galerie.projekte` und `galerie.sticker`.

## Empfangen

- `GalerieSync` beobachtet `galerie.*` mit `Raum.shared.beobachten`, nur `op.von == Raum.shared.ich`.
- `galerie.stand`: anwenden, wenn lokal keine Zeichnung mit der ID existiert oder
  `dokument.updatedAt > lokal.updatedAt` (streng größer: das eigene Echo wird so übersprungen). Fehlende
  Dateien per `Medien.holen`, dann Ebenen-Dateien, Vorschau und Dokument **roh** schreiben: neue Methode
  in `ArtworkLibrary`, die `updatedAt` des eingehenden Dokuments behält und die Zeichnung NICHT als
  schmutzig markiert (sonst Endlosschleife zwischen den Geräten). Danach
  `NotificationCenter.default.post(name: .artworkLibraryGeaendert)`.
- Ist genau diese Zeichnung gerade im Studio offen, wird der Stand zurückgestellt und nach dem Schließen
  angewendet.
- Fehlt eine Datei (Upload vom anderen Gerät noch nicht fertig): nicht anwenden, später erneut (beim
  nächsten Start wird der OpLog ohnehin wieder an `beobachten` geliefert).
- Duplikate aus dem alten Umzugs-Import (jedes Gerät vergab eigene UUIDs): Eine eingehende Zeichnung,
  deren Menge an Ebenen-Hashes und Name gleich einer lokalen Zeichnung mit anderer ID ist, ersetzt die
  lokale nicht als zweite Kopie. Die lokale wird auf die eingehende ID umgestellt (umbenennen des Ordners
  oder löschen + roh schreiben).
- `galerie.geloescht`: lokal löschen, wenn `zeit >= lokal.updatedAt`.
- `galerie.projekte` / `galerie.sticker`: übernehmen, wenn die Op neuer ist als die zuletzt angewendete
  (seq).

## Konflikte

Pro Zeichnung gewinnt die neueste Änderung (`updatedAt`). Wer auf beiden Geräten offline dieselbe
Zeichnung ändert, verliert die ältere Fassung. Löschen auf einem und späteres Bearbeiten auf dem anderen
Gerät holt die Zeichnung zurück. Bewusst so, zwei Personen, selten.

## Grenzen (ponytail)

- Ältere Fassungen geänderter Ebenen bleiben im SQLite des Durable Object liegen. Upgrade: Server-Job, der
  `galerie-<person>-*`-Medien ohne Verweis im jeweils letzten `galerie.stand` löscht.
- `Medien.hochladen` kopiert jede Datei zusätzlich in den Chat-Medien-Cache (doppelter Platz auf dem
  Gerät).
- Geteilte Zeichnungen (`Drawing/Teilen`, `zeichnung.*`) bleiben wie sie sind.

## Tests

- Rein-logische Teile als `nonisolated static func` mit XCTest: Anwenden-Entscheidung (neuer/älter/gleich,
  offen im Studio), Duplikat-Erkennung über Ebenen-Hashes, Medien-ID-Bildung.
- Pflicht-Test gegen die Schleife: einen entfernten Stand anwenden, danach ist nichts als schmutzig
  markiert und nichts gesendet.
