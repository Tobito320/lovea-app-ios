# Snaps schneller — Fundliste

Auftrag 04.10.2026: Snap-Ablauf (Kamera → Aufnahme/Galerie → Editor → Senden → Ankommen → Ansehen)
smooth und schnell wie Snapchat machen. Code gelesen: `Lovea/Sources/Snaps/`, `Lovea/Sources/Chat/Medien/`,
`Lovea/Sources/Sync/Medien.swift`. Basis `origin/runde-3`. Bekannt und nicht wieder eingebaut: Live-Filter
in der Kamera (fror ein, `c142c44`). Bezug: [[Lovea – Video kommt spaet (Analyse)]] im Vault.

Alle Zeiten sind geschätzt, nicht am Gerät gemessen (kein Mac/Simulator auf diesem PC).

## Schon gebaut, nichts zu tun

- **Kamera-Session warmhalten.** `Snaps/SnapKamera.swift:189-223` (`halten()`/`vorwaermen()`): die
  `AVCaptureSession` wird konfiguriert, sobald der Chat sichtbar ist, nicht erst beim Öffnen der
  Kamera. `SnapKameraSteuerung.geteilt` ist ein geteiltes Singleton, läuft also nicht pro Öffnen neu
  an. Schon optimal, nichts geändert.
- **Foto-Senden ist schon optimistisch.** `Snaps/SnapEditor.swift:540-546`: der Editor schließt
  sofort nach dem Flatten (`SnapExport.foto`, ein schneller Single-Frame-Render), der Upload läuft
  danach im Hintergrund weiter (`ChatMedien.snapFotoSenden`). Die Nachricht geht raus, bevor die
  Datei hochgeladen ist (Platzhalter beim Empfänger übernimmt das Warten).
- **Video-Senden schließt den Editor auch schon vor dem Upload** (`SnapEditor.swift:547-552`):
  wartet nur auf `SnapExport.video` (das Overlay-Brennen), der eigentliche Upload läuft in einer
  eigenen, nicht abgewarteten `Task`. Der Hebel war also nicht die Reihenfolge, sondern wie lange
  `SnapExport.video` selbst braucht (siehe unten).

## Gefunden und behoben (dieser PR)

### 1. Snap-Editor: Video mit Filter/Doodle/Text kodiert zweimal in voller Auflösung mit `HighestQuality`
**Datei:** `Lovea/Sources/Snaps/SnapExport.swift:62-152` (`video`, `gefiltertesVideo`)
**Fund:** Hat ein Snap-Video einen Filter, ein Kritzel, Text oder einen Sticker, brennt `SnapExport`
das erst mit `AVAssetExportPresetHighestQuality` in der vollen Kamera-Auflösung ins Video (Filter-Pass
+ Overlay-Pass). Danach kodiert `ChatMedien.snapVideoSenden` → `MedienKodierung.video` das Ergebnis
**noch einmal** fürs Senden (720p, Schalter „Videos schneller senden"). Macht: zwei bis drei volle
Kodierungen hintereinander, bevor überhaupt etwas hochgeladen wird, und der Editor schließt erst nach
der ersten davon (siehe oben).
**Fix:** `SnapExport.video`/`gefiltertesVideo` nehmen jetzt denselben Schnell-Pfad wie
`MedienKodierung.video`: bei Schalter an (Standard) läuft der Overlay-Pass mit
`AVAssetExportPreset1280x720` und einer auf 1280 Kante gedeckelten `renderSize`/Skalierung statt der
vollen Auflösung — genau die Zielgröße, auf die `MedienKodierung.video` sowieso herunterrechnet.
Sicherheitsnetz wie bei `MedienKodierung.exportiere`: scheitert das 720p-Preset für das Asset, einmal
mit `HighestQuality`. Schalter aus: unverändertes Verhalten (volle Auflösung, `HighestQuality`).
**Wirkung (geschätzt):** Overlay-Pass selbst deutlich schneller (kleineres Bild, niedrigere Bitrate).
Zusätzlich trifft das Ergebnis beim späteren `MedienKodierung.videoPlan` jetzt oft schon den
"unverändert"-Pfad (≤1280 Kante, ≤30 s, ≤5 Mbit/s) — die dritte Kodierung beim Senden entfällt dann
ganz, nicht nur wird sie kleiner. Bei Snaps ohne Filter/Doodle/Text ändert sich nichts (der ganze
Pass wird eh übersprungen, Guard am Anfang von `video`).
**Akku:** spart. Eine Kodierung weniger bzw. kleinere Kodierungen, CPU-Zeit direkt proportional zur
Pixelzahl und Bitrate.
**Risiko:** niedrig. Reine Export-Parameter (Preset, Zielgröße), gleiches Sicherheitsnetz-Muster wie
der bestehende Code in `MedienKodierung.swift`. Nicht am Gerät geprüft (kein Mac hier) — Bild/Video
muss am Telefon scharf und richtig ausgerichtet aussehen (Transform+Skalierung kombiniert).

### 2. Medien-Upload: Teile strikt nacheinander statt parallel
**Datei:** `Lovea/Sources/Sync/Medien.swift:117-168` (`teilHochladen`, neu `teilSenden`, `stapeln`)
**Fund:** Jeder Medien-Upload zerlegt die Datei in 1-MiB-Stücke und lädt sie **eins nach dem
anderen** hoch, jedes mit eigener Anfrage plus Wartezeit (siehe Vault-Analyse: bei einem 19-s-Video
20 bis 35 Anfragen nacheinander — größter Posten der Sendezeit beim Empfänger). Gilt für Fotos UND
Videos, Original und „klein", und genauso für Snaps (dieselbe `Medien.hochladen`-Funktion).
**Fix:** Bis zu 4 Teile gleichzeitig hochladen (`parallelitaet = 4`, `stapeln` gruppiert die
Teile-Indizes in Stapel, `withThrowingTaskGroup` lädt einen Stapel gleichzeitig hoch, dann den
nächsten). Jede parallele Aufgabe öffnet ihren eigenen `FileHandle` statt einen geteilten zu
benutzen (ein gemeinsamer Handle mit `seek`+`read` aus mehreren Tasks wäre ein Rennen).
**Wirkung (geschätzt):** Bei einer Mobilfunk-/WLAN-Verbindung, die mehr als eine Anfrage gleichzeitig
verträgt (praktisch immer), sinkt die Upload-Zeit grob um den Faktor der Parallelität, solange nicht
die reine Bandbreite der Flaschenhals ist — realistisch deutlich unter der Hälfte der bisherigen Zeit
bei einem größeren Video. Trifft Fotos kaum (meist 1-3 Teile), Videos spürbar.
**Akku:** neutral bis leicht besser. Mehr gleichzeitige Anfragen kosten im Moment etwas mehr, aber
das Funkmodul ist insgesamt kürzer aktiv (schneller fertig, schneller wieder im Ruhezustand) als bei
vielen Anfragen nacheinander.
**Risiko:** mittel. Bestehende Wiederaufnahme-Logik (`fehlendeTeile`, Resume nach Abbruch) bleibt
unverändert — sie fragt weiterhin vor dem Upload, was fehlt, das ändert sich durch Parallelität
nicht. Pures Gruppieren (`stapeln`) mit XCTest geprüft (`SyncTests.swift`). Nicht am Gerät geprüft:
ob der Server (`server/raum.js`) mit gleichzeitigen PUTs für denselben Medien-Eintrag klarkommt, ist
aus dem Client-Code nicht zu sehen — die Teile sind aber unabhängige, eigene Anfragen mit eigenem
Index, kein gemeinsamer Zustand pro Anfrage, Konflikt ist unwahrscheinlich.

### 3. Snap-Viewer fragt alle 2 s statt alle 1 s nach, ob das Medium da ist
**Datei:** `Lovea/Sources/Snaps/SnapViewer.swift:69-76` (`laden`)
**Fund:** PR #14 hat denselben Takt im Chat-Bild (`MedienDatei.url`, `MedienBildView.swift`) schon
von 5 s auf 1 s gesenkt, mit der Begründung "die Nachricht kommt an, bevor der Upload fertig ist,
5 s hier hieß das Foto zeigte sich bis zu 5 s später als nötig". Der Snap-Viewer hat diesen Fix nie
bekommen und fragt weiterhin alle 2 s.
**Fix:** Takt auf 1 s gesenkt, wie im Chat.
**Wirkung (geschätzt):** bis zu 1 s weniger Wartezeit, nachdem die Datei eigentlich schon da ist.
Klein, aber im Sinne von "smooth wie Snapchat" eine spürbare Lücke weniger.
**Akku:** vernachlässigbar (eine zusätzliche Anfrage pro Sekunde Warten, nur während der Viewer
offen ist und das Medium noch fehlt — kein Dauerbetrieb).
**Risiko:** sehr niedrig, eine Zahl.

## Geprüft, bewusst nicht angefasst

- **Galerie-Video-Import kopiert die ganze Datei** (`Chat/Medien/VideoVorab.swift:10-22`,
  `VideoDatei.transferRepresentation`, auch von `Snaps/SnapKamera.swift:730-752`s Galerie-Knopf
  benutzt): `PhotosPickerItem.loadTransferable` für `.movie` braucht laut Apple-API eine lokale Datei,
  der Kopiervorgang ist also nicht zu umgehen, ohne die Picker-API zu wechseln (zu riskant für diesen
  Auftrag). Läuft schon async mit eigenem Lade-Indikator (`galerieLaedt`), blockiert nicht den
  Hauptthread.
- **`VideoVorab` (Vorab-Kodierung/-Upload beim Auswählen) nicht auf Snaps übertragen.** Der Schalter
  existiert nur für den Chat-Anhang-Streifen. Für Snaps "vorab" zu bauen hieße: Kodierung schon in
  der Kamera-/Galerie-Phase starten, bevor der Editor überhaupt feststeht, was am Ende gesendet wird
  (Filter/Doodle kommen ja erst im Editor dazu) — das Vorab-Ergebnis wäre für Snaps mit Bearbeitung
  meist für die Katz. Passt nicht zum Snap-Ablauf, anders als beim Chat-Anhang (dort wird nicht mehr
  bearbeitet). Nicht gebaut.
- **Nachricht vor der Kodierung senden** (Vorschlag aus der Video-Analyse, "vorab hochladen"-Idee
  weitergedacht): hieße, die `nachricht.neu`-Op schon mit nur den Metadaten (Breite/Höhe/Dauer) zu
  schicken, bevor die Kodierung überhaupt bestätigt fertig ist. Bewusst nicht gemacht: scheitert die
  Kodierung danach (passiert, z. B. bei seltenen Codecs), hat der Empfänger eine Nachricht, deren
  Medium nie ankommt — ein Dauer-Ladekreis ohne Ausweg. Der bestehende Code sendet nie eine Op, bevor
  die Kodierung sicher geklappt hat (auch `VideoVorab` im Chat hält sich strikt daran), das wollte ich
  nicht aufweichen.
- **Live-Filter in der Kamera-Vorschau:** laut Auftrag nicht wieder einbauen (fror ein, `c142c44`).
- **`Zyklus/`, `Figuren/FigurView.swift`:** nicht angefasst (Auftrag).
