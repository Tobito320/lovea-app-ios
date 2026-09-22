# Lovea iOS – kanonischer Zeichen-Bauplan

Stand: 22.09.2026

Dieser Plan ist die verbindliche Spezifikation für den Zeichen-Bereich der nativen Lovea-iOS-App.
Er führt den bisherigen Lovea-/Wir-App-Plan, den aktuellen SwiftUI-Code und die neuen Entscheidungen zusammen.

Wenn dieser Plan einem älteren Web-/PWA-Plan widerspricht, gilt **dieser Plan**.

---

## 1. Produktgrenze

Lovea ist eine private iPhone-/iPad-App für Ahmed und Annika.

Für die nächste Zeit wird **nur der Bereich Zeichnen** ausgebaut.

Die App behält zunächst genau drei Tabs:

1. Home
2. Zeichnen
3. Profil

Home und Profil dürfen vorerst einfach bleiben. Der Entwicklungsfokus liegt auf Zeichnen.

### Wichtige neue Entscheidung

Das alte permanente **Shared Board auf Home wird komplett verworfen**.

Es gibt kein festes gemeinsames Board mehr.

Stattdessen wird Zusammenarbeit später direkt an **Projekten und einzelnen Zeichnungen** angeboten. Dadurch kann eine Zeichnung privat bleiben, als Bild geschickt, live nur angesehen oder später gemeinsam bearbeitet werden.

---

## 2. Prioritätssystem

Je kleiner die Level-Zahl, desto höher die Priorität.

### LEVEL 1 – Vollwertiges persönliches Zeichnen

Ziel: Annika soll für ihren echten iPad-Zeichenablauf ibisPaint nicht mehr öffnen müssen.

Alles funktioniert zunächst **lokal und für eine Person**.

Keine gemeinsame Bearbeitung. Keine Live-Synchronisation. Kein Shared Board.

### LEVEL 2 – Teilen und live ansehen

Erst wenn Level 1 stabil ist.

Ziel: Projekte und Zeichnungen können mit der anderen Person geteilt werden, ohne dass beide gleichzeitig bearbeiten müssen.

Enthalten:

- Person zu einem Projekt hinzufügen oder später entfernen
- einzelne Zeichnung als unveränderlichen Snapshot senden
- einzelne Zeichnung oder ganzes Projekt lesend freigeben
- Empfänger sieht bei einer Live-Freigabe neue Änderungen, darf aber nicht bearbeiten

### LEVEL 3 – Gemeinsam zeichnen

Erst ganz am Ende.

Ziel: Für eine einzelne Zeichnung kann die andere Person als Bearbeiter eingeladen werden. Dann können beide dieselbe Zeichnung bearbeiten.

Es bleibt trotzdem **kein globales Shared Board**.

---

# 3. Aktueller Stand des nativen iOS-Projekts

Stand: Level 1 gebaut, wartet auf die Abnahme am iPad (`docs/LEVEL1-ABNAHME.md`).

Aktives Repository: `Tobito320/lovea-app-ios`. Das Repo `Tobito320/lovea-onlyus-ios-leer` ist nicht die Arbeitsbasis.

## Engine in 10 Zeilen

1. Eine GPU-Textur pro Ebene in Dokumentgröße (`LayerTextureStore`), Bildebenen als Foto-Textur plus Transform.
2. Striche werden zu Stempeln (`StrokeSampler`: Live-Stabilisator, Druckkurve, Neigung, Abstand).
3. `BrushStamper` malt die neuen Stempel eines Frames mit einem instanzierten Draw in eine Scratch-Textur.
4. Beim Absetzen wird der Strich einmal in die Ebene übernommen (normal, Radierer, Alpha Lock).
5. `Compositor` setzt alle Ebenen auf der GPU zusammen: 8 Mischmodi, Clipping wie ibisPaint, Caches unter und über der aktiven Ebene.
6. Die Leinwand zeichnet nur bei Eingabe oder Änderung, bis 120 Hz.
7. Undo speichert pro Strich nur das betroffene Rechteck; Ebenen-Aktionen sind Dokument-Schritte (256 MiB Budget).
8. Autosave 1 s nach der letzten Änderung: PNG pro geänderter Ebene, dann `document.json`, atomar und im Hintergrund.
9. Füllen, Pipette, Auswahl, Transformieren, Formen, Text und Anpassungen nutzen dieselbe Engine.
10. Alte Zeichnungen (JSON-Striche, PencilKit) werden beim ersten Öffnen einmal gerastert.

## Vorhanden

- drei Tabs: Home, Zeichnen, Profil; Personenwahl Ahmed/Annika
- Galerie mit Projekten, Zuletzt bearbeitet, Sortierung, Kontextmenü, Export, leerer Zustand
- Neue Zeichnung: Formate, eigene Größe bis 4096, Hintergrund Weiß/Dunkel/Transparent/Farbe
- Foto als Ebene und „Als Schablone“ (unten, 35 %, gesperrt, neue Ebene darüber, ein Undo-Schritt)
- 10 Pinsel (Stift, Tinte, Bleistift, Marker, Airbrush, Aquarell, Kreide, Kalligrafie, Leuchtstift, Pixel)
- Druck → Größe/Deckkraft, Neigung, Stabilisator 0–9, Predicted Touches, Palm Rejection, Pencil-Doppeltippen, Squeeze-Schnellmenü, Hover-Pinselkreis
- Radierer, Füllen (Toleranz, diese Ebene/alle Ebenen, 1-px-Überlappung), Pipette (Werkzeug und langer Druck mit Lupe)
- Farbpanel mit Farbring, Quadrat, Hex, HSB-Reglern, 16 Palettenplätzen und letzten 8 Farben pro Person
- Ebenen: neu, duplizieren, löschen, umbenennen, sperren, verstecken, Reihenfolge per Drag & Drop, Deckkraft, 8 Mischmodi, Clipping, Alpha Lock, nach unten zusammenführen, Rastern, Leeren, Spiegeln, mindestens 32 Ebenen
- Lasso- und Rechteck-Auswahl mit laufenden Ameisen: Aufheben, Umkehren, Löschen, Kopieren, Ausschneiden, Transformieren
- Transformieren für Ebene oder Auswahl: verschieben, skalieren (proportional oder frei), drehen mit Einrasten, spiegeln
- Linie, Rechteck, Ellipse (auch gefüllt, zweiter Finger = Quadrat/Kreis/45°), Text mit 4 Schriften, Spiegelachse
- Ansicht: Zoom, Verschieben, Drehen (Einrasten bei 0°), Ansicht spiegeln, Zurücksetzen per Doppeltippen mit zwei Fingern
- Anpassen: Weichzeichnen, Graustufen, Umkehren, Helligkeit, Sättigung, Farbton (mit Vorschau, respektiert Auswahl)
- Undo/Redo (mindestens 50 Schritte), Gesten mit 2 und 3 Fingern
- Export PNG (mit Transparenz), JPEG, In Fotos sichern, Teilen
- iPad-Layout mit Größe/Deckkraft-Leiste links, Ebenen-Panel rechts, schwebender Werkzeugleiste; iPhone kompakt; Liquid Glass ab iOS 26
- Leistungsanzeige (Profil → Leistungsanzeige), CI mit Muster-Check und Warnungs-Zählung
- TestFlight-Workflow (`docs/TESTFLIGHT.md`), wartet auf Secrets
- Level 2 (Bild senden, live ansehen, Projekt freigeben) eingefroren

## Fehlt noch

- Abnahme auf dem echten iPad mit Apple Pencil (`docs/LEVEL1-ABNAHME.md`)
- Messwerte der Leistungsanzeige auf iPhone 14, iPhone 16 Pro Max und iPad
- TestFlight: App in App Store Connect, Secrets, App-Icon
- Kacheln statt ganzer Texturen, falls der Speicher auf dem iPhone knapp wird
- Level 2 und Level 3

---

# 4. Architektur – Bereiche klar isolieren

Der Zeichenbereich wird in getrennte Module/Verantwortungen aufgeteilt. Ein Agent soll keine Netzwerklogik in den Renderer und keine Zeichenlogik in Home einbauen.

## 4.1 App

Verantwortlich für:

- TabView
- Ahmed/Annika-Auswahl bzw. spätere Identität
- Navigation
- globale App-Abhängigkeiten

Nicht verantwortlich für Zeichenlogik.

## 4.2 Library

Verantwortlich für:

- Galerie
- Projekte
- Zeichnungs-Metadaten
- Vorschau-Bilder
- Erstellen, Umbenennen, Duplizieren, Verschieben, Löschen
- lokales Speichern/Laden

Keine Live-Zusammenarbeit in Level 1.

## 4.3 DrawingCore

Verantwortlich für:

- ArtworkDocument
- Layer-Modell
- Werkzeugzustand
- Undo/Redo
- Aktionen/Commands
- Auswahl
- Transformationen
- Autosave-Snapshots

Keine SwiftUI-Galerie und keine Netzwerklogik.

## 4.4 Renderer

Verantwortlich für:

- MetalKit
- Brush-Rendering
- Apple Pencil
- Druck
- Glättung/Stabilisierung
- Layer-Compositing
- Blend Modes
- Clipping
- Alpha Lock
- Export-Rendering

Keine Projekt- oder Sharing-Logik.

## 4.5 Studio

Verantwortlich für die Zeichenoberfläche:

- Werkzeugleiste
- Farben
- Pinselwahl
- Layer-Panel
- Canvas-Gesten
- Auswahl-/Transformations-UI
- Import eines Fotos

## 4.6 Sharing

**In Level 1 nicht implementieren.**

Später verantwortlich für:

- Snapshot senden
- Read-only-Live-Freigaben
- Projektfreigaben
- Berechtigungen
- Level-3-Collaboration

Der Level-1-Code darf nicht von einem konkreten Backend abhängig sein.

---

# 5. Datenmodell für Level 1

Das aktuelle Modell mit einer einzigen `DrawingDocument.empty`-Zeichnung reicht nicht aus.

Zielmodell:

## Project

- `id`
- `name`
- `createdAt`
- `updatedAt`
- optionales Cover/Vorschau

In Level 1 ist ein Projekt rein lokal und privat.

Es gibt immer auch den Bereich **Ohne Projekt**.

## Artwork

- `id`
- `name`
- `projectID?`
- `canvasWidth`
- `canvasHeight`
- `background`
- `createdAt`
- `updatedAt`
- `previewPath`
- `schemaVersion`
- `layers[]`

## Layer

Gemeinsame Eigenschaften:

- `id`
- `name`
- `kind`: `paint` oder `image`
- `isVisible`
- `isLocked`
- `opacity`
- `blendMode`
- `clipping`
- `alphaLock`
- `transform`

### Paint Layer

Raster-/Texture-basierter Inhalt mit transparentem Hintergrund.

Pinselstriche dürfen während der Sitzung als Operationen/Vektorpunkte geführt werden, aber die Ebene muss als echtes Bild mit Alpha gespeichert werden können. Dadurch funktionieren später Füllen, Import, Filter, Lasso und Transformation sauber.

### Image Layer

Für importierte Fotos/Schablonen.

Speichert:

- lokale Asset-Datei
- Position
- Skalierung
- Drehung

## Lokale Dateistruktur

Pro Zeichnung ein eigener Ordner, zum Beispiel:

`Application Support/Lovea/Artworks/<artwork-id>/`

Darin:

- `document.json`
- `preview.jpg`
- `layers/<layer-id>.png`
- `assets/...`

Speichern muss atomar sein: niemals eine vorhandene Zeichnung halb überschreiben.

---

# 6. LEVEL 1 – persönliches Zeichnen

Level 1 ist fertig, wenn Annika ihren normalen Zeichenablauf auf dem iPad komplett in Lovea erledigen kann.

## 6.1 LEVEL 1A – Galerie und Projekte

Der Tab **Zeichnen** startet nicht direkt in einer einzigen Canvas-Datei, sondern in **Meine Galerie**.

### Startansicht

- Zuletzt bearbeitet
- Knopf `Weiterzeichnen`
- `+ Neue Zeichnung`
- `+ Projekt`
- Sortierung: Neueste / Name / Älteste
- Bereich `Ohne Projekt`
- Projektkarten

### Projekt

Ein Projekt ist ein Container für mehrere Zeichnungen.

Level 1:

- erstellen
- umbenennen
- löschen mit Rückfrage
- Zeichnungen hinein verschieben
- Zeichnungen wieder heraus verschieben
- Projektkarte zeigt bis zu vier Vorschauen

Noch **keine Personen** in Level 1.

### Neue Zeichnung

Auswahl:

- Name
- Format
- Hintergrund
- optional Projekt

Formate:

- Quadrat
- 4:3
- 3:4
- 16:9
- 9:16
- A4
- benutzerdefinierte Größe

Startwert: 2048 × 2048.

Initiales Limit: maximal 4096 px pro Seite.

Hintergrund:

- Weiß
- Dunkel
- Transparent
- eigene Hintergrundfarbe

### Zeichnungskarte

Tippen = öffnen.

Kontextmenü / lange drücken:

- Öffnen
- Umbenennen
- Duplizieren
- In Projekt verschieben
- Exportieren
- Löschen

---

## 6.2 LEVEL 1B – Foto als Schablone

Dies ist eine der wichtigsten Funktionen.

Über `Bild importieren` wird mit dem nativen iOS Photo Picker ein Bild gewählt.

Das Bild wird als **eigene Image Layer** eingefügt.

Direkt nach Import:

- verschieben
- skalieren
- drehen
- bestätigen oder abbrechen

### Schnellaktion `Als Schablone`

Ein Knopf erledigt automatisch:

1. Foto importieren
2. Fotoebene an die unterste sinnvolle Stelle verschieben
3. Deckkraft auf ca. 35 % setzen
4. Ebene sperren
5. neue transparente Paint Layer darüber erstellen und aktivieren

Danach kann Annika sofort darüberzeichnen.

Sie kann später:

- Deckkraft ändern
- Ebene entsperren
- Ebene verschieben
- Foto transformieren
- Foto löschen

---

## 6.3 LEVEL 1C – Apple Pencil und Canvas-Gefühl

Priorität: iPad + Apple Pencil zuerst.

Muss:

- Druckstärke lesen
- Druck kann Pinselgröße beeinflussen
- optional Druck kann Deckkraft beeinflussen
- Coalesced Touches für glatte Linien
- Predicted Touches nur für flüssige Vorschau, nicht falsch dauerhaft speichern
- Palm Rejection
- Fingerzeichnen ein-/ausschaltbar
- wenn Fingerzeichnen aus ist: Finger dienen der Navigation
- Apple-Pencil-Hover auf unterstützten iPads zeigt Pinselkreis

Canvas-Gesten:

- 2 Finger: verschieben
- Pinch: zoomen
- 2 Finger drehen: Canvas-Ansicht drehen
- 2 Finger tippen: Undo
- 3 Finger tippen: Redo
- Zoom-Anzeige antippen: Ansicht zurücksetzen
- optional Leinwand horizontal spiegeln zur Kontrolle

Wichtig: Canvas drehen/zoomen verändert nur die Ansicht, nicht versehentlich das Bild.

---

## 6.4 LEVEL 1D – Brushes

Maximal **20 kuratierte Brushes**.

Keine Brush-Programmierung. Keine Brush-Community. Kein QR-Import.

Erste verpflichtende 10:

1. Stift
2. Tinte / G-Pen
3. Bleistift
4. Marker
5. Airbrush
6. Aquarell
7. Kreide
8. Kalligrafie
9. Leuchtstift
10. Pixel

Weitere Brushes dürfen später ergänzt werden, aber die Gesamtzahl soll 20 nicht überschreiten.

Pro Brush:

- Größe
- Deckkraft
- eigener Standardwert
- Druck → Größe an/aus
- Druck → Deckkraft an/aus
- Stabilisator 0–9

UI:

- aktueller Brush sichtbar
- letzte 3 Brushes schnell erreichbar
- Brush-Vorschau
- Größenregler
- Deckkraftregler
- einige Schnellgrößen

Es gibt **keinen freien Brush-Editor**.

---

## 6.5 LEVEL 1E – Farben

Muss:

- richtiger Farbwähler
- Farbton/Sättigung/Helligkeit
- Deckkraft
- Pipette
- 16 feste/eigene Schnellfarben
- letzte 8 benutzte Farben

Finger halten auf Canvas darf optional die Pipette öffnen, solange es nicht mit Canvas-Gesten kollidiert.

---

## 6.6 LEVEL 1F – Ebenen

Für Annika zentral.

Muss:

- neue Ebene
- auswählen
- umbenennen
- sichtbar/versteckt
- sperren/entsperren
- Deckkraft
- duplizieren
- Reihenfolge per Drag & Drop ändern
- nach unten zusammenführen
- löschen
- mindestens 32 Ebenen im Dokumentmodell erlauben

Zusätzlich:

- Clipping
- Alpha Lock / Transparenz schützen

Blend Modes – zunächst diese acht:

1. Normal
2. Multiply
3. Screen
4. Overlay
5. Darken
6. Lighten
7. Add
8. Soft Light

Layer-Folder sind **nicht Pflicht für den ersten Level-1-Abschluss**. Nur hinzufügen, wenn Annika sie in ihrem echten Workflow vermisst.

---

## 6.7 LEVEL 1G – Kernwerkzeuge

Verpflichtend:

### Pinsel

Malt auf aktiver Paint Layer.

### Radierer

- Größe
- Deckkraft
- harte/weiche Variante über Brush-Verhalten

### Farbeimer

- Toleranz
- Bezug: aktive Ebene / alle sichtbaren Ebenen
- saubere Kanten ohne sichtbare 1-Pixel-Lücke

### Pipette

Farbe aus dem zusammengesetzten sichtbaren Bild aufnehmen.

### Lasso / Auswahl

Freihand-Auswahl.

Danach möglich:

- verschieben
- skalieren
- drehen
- horizontal/vertikal spiegeln
- als Kopie auf neue Ebene
- löschen
- abbrechen/fertig

### Transformieren

Für ganze Ebene oder aktive Auswahl:

- verschieben
- skalieren
- drehen
- spiegeln

Bildqualität darf bei normalem Transformieren nicht sichtbar unnötig schlechter werden.

---

## 6.8 LEVEL 1H – zusätzliche Zeichenwerkzeuge

Diese Funktionen gehören noch zu Level 1, aber erst **nach** Brush, Foto, Layer, Farben, Auswahl und Transformieren.

- Gerade-Linie/Lineal
- Rechteck
- Ellipse
- gefüllte Form
- Symmetrie
- Leinwand spiegeln
- Weichzeichnen
- einfacher Text mit wenigen gut lesbaren Schriften

Keine riesige Profi-Werkzeugbibliothek.

---

## 6.9 LEVEL 1I – einfache Bildanpassungen

Nur kleine sinnvolle Auswahl:

- Weichzeichnen
- Graustufen
- Farben umkehren
- Helligkeit
- Sättigung
- Farbton

Keine 80+-Filterbibliothek.

---

## 6.10 LEVEL 1J – Undo, Autosave und Wiederherstellung

- mindestens 50 Undo-Schritte während einer Sitzung
- Redo
- Werkzeugaktionen, Layer-Aktionen und Transformationen müssen in Undo/Redo einbezogen sein
- Autosave nach Änderungen, entprellt
- App-Absturz oder normales Schließen darf die letzte bestätigte Arbeit nicht verlieren
- beim erneuten Öffnen müssen Layer, Bildschablonen, Blend Modes und Metadaten erhalten sein

Undo über einen kompletten App-Neustart ist für Level 1 nicht Pflicht.

---

## 6.11 LEVEL 1K – Export

Muss:

- PNG
- PNG mit Transparenz, wenn Hintergrund transparent
- JPEG für normale Bildfreigabe
- in Fotos sichern
- iOS Share Sheet

Export rendert genau den sichtbaren finalen Stand aller sichtbaren Ebenen.

---

## 6.12 LEVEL 1L – adaptive iPhone-/iPad-Oberfläche

### iPad

Primärziel.

- Apple Pencil steht im Mittelpunkt
- genug Platz für Canvas
- Layer-Panel darf seitlich eingeblendet werden
- Landscape und Portrait
- Bedienelemente mindestens 44 pt

### iPhone

- gleiche Dateien und gleichen Zeichenkern verwenden
- kompakte Toolbars
- Layer und Optionen als Sheet/Panel
- Portrait ist ausreichend für den ersten Stand

Keine getrennte iPhone-Zeichenengine.

---

# 7. LEVEL 1 – Abnahmetest

Level 1 gilt nicht als fertig, nur weil einzelne Buttons existieren.

Dieser komplette Ablauf muss funktionieren:

1. Annika öffnet Zeichnen.
2. Sie erstellt ein Projekt.
3. Sie erstellt darin eine neue Zeichnung.
4. Sie importiert ein echtes Foto aus Fotos.
5. Sie nutzt `Als Schablone`.
6. Das Foto liegt unten, ist transparent und gesperrt.
7. Sie zeichnet mit Apple Pencil auf einer neuen Ebene darüber.
8. Druck verändert den Strich sauber.
9. Sie nutzt einen anderen Brush.
10. Sie nimmt eine Farbe mit der Pipette auf.
11. Sie erstellt mehrere Ebenen.
12. Sie ordnet Ebenen neu.
13. Sie ändert Deckkraft.
14. Sie nutzt Clipping oder Alpha Lock.
15. Sie nutzt mindestens einen Blend Mode.
16. Sie wählt einen Bereich per Lasso.
17. Sie verschiebt, dreht und skaliert ihn.
18. Sie macht Undo und Redo.
19. Sie schließt die Zeichnung.
20. Sie öffnet sie erneut und alles ist noch da.
21. Sie exportiert das fertige Bild als PNG.

Wenn dieser Ablauf auf einem iPad sauber funktioniert, ist der Kern von Level 1 erreicht.

---

# 8. LEVEL 2 – Projekte und Zeichnungen teilen

Erst beginnen, wenn Level 1 abgeschlossen und stabil ist.

## 8.1 Projektfreigabe

Ein Projekt kann jetzt `Privat` oder `Geteilt` sein.

In den Projekteinstellungen:

- `Person hinzufügen`
- `Person entfernen`

Für Lovea gibt es zunächst nur Ahmed und Annika.

### Verhalten

Wird Annika zu Ahmeds Projekt hinzugefügt:

- Annika sieht das Projekt in ihrem Zeichnen-Tab
- sie sieht immer den aktuellen gespeicherten Stand der enthaltenen Zeichnungen
- sie darf sie **nicht bearbeiten**
- neue Zeichnungen in diesem geteilten Projekt sind ebenfalls lesbar

Wird sie entfernt:

- Zugriff auf das Projekt endet
- bereits bewusst als Snapshot gespeicherte Kopien bleiben als eigene Bilder erhalten

Ein Agent darf Projektmitgliedschaft nicht automatisch als Bearbeitungsrecht behandeln.

---

## 8.2 Einzelne Zeichnung als Snapshot senden

Aktion: `Als Bild senden`.

Das System rendert den aktuellen sichtbaren Stand zu einem festen PNG/JPEG.

Dieser Snapshot:

- verändert sich später nicht
- enthält keine editierbaren Layer
- erscheint beim Empfänger unter `Von Ahmed` bzw. `Von Annika`
- kann vom Empfänger als eigene Kopie gespeichert werden

Optional aus dem alten Plan beibehalten:

- Sender kann einen noch nicht dauerhaft gespeicherten Versand zurückrufen

Der Begriff in der Benutzeroberfläche ist **Bild**, nicht `Snapshot`.

---

## 8.3 Einzelne Zeichnung live zum Ansehen freigeben

Aktion: `Live ansehen lassen`.

Der Empfänger bekommt **read-only** Zugriff auf das Artwork.

Wenn der Besitzer weiterzeichnet und speichert:

- der Empfänger erhält den neuen Stand automatisch
- Layer und Canvas dürfen angesehen werden
- Bearbeitung ist gesperrt

Freigabe kann jederzeit beendet werden.

Das ist keine gemeinsame Zeichen-Session.

---

## 8.4 Level-2-Galerie

Zusätzliche Bereiche:

- Von Ahmed / Von Annika
- Geschickt
- Bekommen
- Mit mir geteilt

Geteilte Inhalte werden optisch klar von eigenen bearbeitbaren Zeichnungen getrennt.

---

# 9. LEVEL 3 – gemeinsames Zeichnen

Erst nach Level 2.

Eine einzelne Zeichnung bekommt die Aktion:

`Zum Zeichnen einladen`.

Dann besitzt diese Zeichnung mindestens zwei Rollen:

- Besitzer
- Bearbeiter

Beide dürfen auf derselben Zeichnung arbeiten.

## 9.1 Regeln

- kein separates Shared Board
- Zusammenarbeit gehört immer zu einem normalen Artwork
- Einladung kann widerrufen werden
- Bearbeiter kann später wieder auf `nur ansehen` gesetzt werden
- beide sehen neue Striche zeitnah
- beide sehen Layer-Änderungen zeitnah
- Netzwerkfehler dürfen nicht das gesamte Dokument überschreiben

## 9.2 Synchronisationsprinzip

Nicht das komplette Dokument bei jeder Änderung nach dem Prinzip `last write wins` ersetzen.

Stattdessen Änderungen als Operationen synchronisieren, zum Beispiel:

- Stroke hinzugefügt
- Stroke/Selection gelöscht
- Layer erstellt
- Layer verschoben
- Layer-Eigenschaft geändert
- Transformation angewandt

Jede Operation hat:

- eindeutige ID
- Artwork-ID
- Nutzer-ID
- Zeit/Reihenfolge
- Basis-Version

Server ordnet dokumentweite Änderungen zuverlässig.

Für gleichzeitige neue Striche dürfen beide Nutzer unabhängig arbeiten.

Undo im gemeinsamen Modus macht standardmäßig nur die **eigenen** letzten Aktionen rückgängig und darf nicht überraschend Annikas/Ahmeds Strich löschen.

Kurze Verbindungsabbrüche dürfen lokale Operationen puffern und danach synchronisieren.

---

# 10. Explizit NICHT bauen

Diese Dinge gehören nicht zu Lovea und sollen nicht aus ibisPaint kopiert werden:

- keine öffentliche Community
- kein Social Feed
- keine öffentliche Galerie
- keine Follower
- keine Likes als öffentliches Netzwerk
- keine Werbung
- keine Coins
- kein Brush-Shop
- keine Abos für Zeichenfunktionen
- keine Manga-Werkzeuge
- keine Manga-Panels
- keine Screentones
- keine Anime-Materialbibliothek
- keine Material-/Sticker-Massenbibliothek
- keine AI-Kunst
- keine Bildgenerierung
- keine Animation mit Frames
- keine Timeline
- kein Audio für Animationen
- kein 3D
- keine 3D-Posen
- kein 3D-Layer-System
- kein Brush-Programmiereditor
- kein Brush-QR-Import/Export
- maximal 20 kuratierte Brushes
- kein professioneller Druck-/CMYK-Workflow
- kein PSD-/Clip-Studio-/Photoshop-Workflow als Ziel
- kein öffentliches Cloud-Kunstprofil
- keine Zeichen-Tutorial-Community
- kein Zeitraffer-/Playback-System als Kernfunktion
- keine riesige Filterbibliothek
- kein Browser/PWA als Zielplattform
- kein Android im aktuellen Plan
- kein permanentes Shared Board auf Home
- kein Board-Status-System
- kein altes Polling-Modell des Web-Boards
- keine alte Browser-Grenze von 8 Ebenen / 1000 px übernehmen

---

# 11. Was aus dem alten Web-Plan übernommen wird

Behalten:

- Galerie + Studio als Grundidee
- Projekte/Ordner für mehrere Zeichnungen
- iPad/Pencil zuerst
- große Tippflächen
- Bildimport als Ebene
- Layer-Funktionen
- Undo/Redo
- Brush-Auswahl
- Pipette
- Farbeimer
- Lasso
- Transformation
- Formen
- Text in einfacher Form
- Clipping
- Alpha Lock
- Blend Modes
- Autosave
- PNG-Export
- Empfangen/Geschickt in Level 2

Ersetzt oder gestrichen:

- `Shared Board` auf Home → komplett weg
- sechs alte Web-Tabs → native App bleibt zunächst bei drei Tabs
- Web Canvas 2D als Architektur → native MetalKit-Engine
- PWA/Safari-Haptik → native iOS-Haptik
- Browser-Polling → später echte Sharing-/Realtime-Schicht
- 1000-px-Leinwandlimit → native Zielgrößen bis 4096 px
- 8-Layer-Limit → mindestens 32 Layer im Modell

---

# 12. Konkrete Implementierungsreihenfolge ab aktuellem Stand

Der Agent soll **nicht** sofort Sharing bauen.

## Schritt 1 – Library- und Artwork-Modell

Als Nächstes:

- `Project`
- `Artwork`
- neue lokale Dateistruktur
- Galerie
- mehrere Zeichnungen
- Migration der jetzigen einzelnen Zeichnung als erstes Artwork

Grund: Ohne mehrere echte Artwork-Dateien kann später weder Projektverwaltung noch Sharing sauber gebaut werden.

## Schritt 2 – gemischte Layer

Das bisherige reine Stroke-Layer-Modell erweitern/ersetzen, sodass Paint Layers und Image Layers existieren.

## Schritt 3 – Fotoimport + `Als Schablone`

Dies ist der erste große Nutzergewinn für Annika.

## Schritt 4 – vollständige Layer-Basis

- reorder
- duplicate
- merge
- lock
- opacity
- clipping
- alpha lock
- blend modes

## Schritt 5 – Pencil-/Brush-Engine verbessern

- 10 Brushes
- pressure mapping
- stabilizer
- coalesced touches
- hover preview
- Palm Rejection prüfen

## Schritt 6 – Farben + Pipette + Füllen

## Schritt 7 – Lasso + Transformieren

## Schritt 8 – Formen/Text/Symmetrie/kleine Filter

## Schritt 9 – Autosave/Recovery/Export/Performance härten

## Schritt 10 – kompletten Level-1-Abnahmetest auf iPad durchführen

Erst danach Level 2 planen/implementieren.

---

# 13. Technische Qualitätsregeln

- Swift 6 / SwiftUI
- iOS 18+
- iPhone + iPad aus derselben Codebasis
- Rendering performant genug für Apple Pencil
- UI darf den Main Thread beim Zeichnen nicht blockieren
- keine Netzwerkabhängigkeit in Level 1
- persistente Daten haben `schemaVersion`
- Migrationen statt stiller Datenlöschung
- destructive actions mit Bestätigung
- Autosave darf Undo/Redo nicht zerstören
- Tests für Datenmodell, Persistenz, Layer-Operationen und Transformationen
- CI muss mindestens iPhone-Simulator bauen und testen
- zusätzlich iPad-Buildziel in CI ergänzen
- reale Pencil-Qualität muss später auf echtem iPad geprüft werden; Simulator reicht dafür nicht

---

# 14. Definition of Done pro Feature

Ein Feature ist erst fertig, wenn:

1. Funktion implementiert ist.
2. Zustand gespeichert und wieder geladen werden kann, falls relevant.
3. Undo/Redo funktioniert, falls die Aktion den Inhalt verändert.
4. iPhone-UI nicht kaputt ist.
5. iPad-UI nicht kaputt ist.
6. passende Unit-Tests vorhanden sind, soweit sinnvoll.
7. bestehende Tests grün bleiben.
8. es keinen versteckten Rückfall auf Shared-Board-/Web-Architektur gibt.

---

# 15. Produkt-Ziel in einem Satz

**Level 1:** Lovea soll für Annikas echten iPad-Zeichenworkflow die relevanten ibisPaint-Funktionen ersetzen.

**Level 2:** Jede Zeichnung und jedes Projekt kann gezielt als Bild oder read-only geteilt werden.

**Level 3:** Eine konkrete Zeichnung kann bewusst für gemeinsames Live-Zeichnen geöffnet werden – ohne ein permanentes Shared Board.