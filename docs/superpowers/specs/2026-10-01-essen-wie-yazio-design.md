# Essen wie YAZIO – Design

Stand: 01.10.2026. Ziel: TestFlight (test). Branch `essen-yazio` ab `runde-3`.
Vorbild-Bilder: Vault `19 Bastelprojekte/Lovea-bilder/inspiration-yazio/yazio-01` bis `-10`,
beschrieben in `19 Bastelprojekte/Lovea – Inspiration.md`, Abschnitt "Ernährung: YAZIO".

## Was Ahmed will

- Essen eintragen soll sich anfühlen wie YAZIO. Aufbau eins zu eins, an einzelnen Stellen schöner.
  Die Mengen-Ansicht exakt wie YAZIO, "kein bisschen Unterschied".
- Viel mehr Lebensmittel. Supermarkt-Produkte (Aldi, Lidl, Rewe, Edeka, dm, Rossmann) sollen per
  Barcode gefunden werden. Selbst anlegen nur als letzter Ausweg.
- Die Suche muss extrem schnell sein.
- Keine Produktbilder mehr. Sie passen oft nicht zum Produkt.
- Mahlzeiten und Rezepte gelten für beide. Was Annika anlegt, sieht Ahmed und umgekehrt.
- Die Kamera-Kachel zeigt vorerst nur "KI-Kalorien-Tracking kommt bald".

## Was heute schiefläuft (aus dem Code, `origin/runde-3`)

- Mengen-Rad `MengenRadBlatt` (`Health/Ernaehrung/ErnaehrungPortionen.swift:85`): zwei `.wheel`-Picker,
  kein Zahlenfeld. 500 g heißt 500 Schritte drehen.
- Eingebaute Grunddatenbank: nur 122 Lebensmittel (`lebensmittel-basis.json`).
- Barcode (`ErnaehrungModell.swift:135-175`): jeder Scan fragt live `world.openfoodfacts.org`.
  Kein Cache, keine Wiederholung, HTTP 429 wird als "keine Verbindung" gezeigt, UPC-A/EAN-8 werden
  nicht normalisiert. Open Food Facts war beim Test am 01.10. zweimal nicht erreichbar (429, leere
  Antwort), der getestete Skyr `4311501679715` ist dort aber vorhanden. Hauptursache ist also die
  Zuverlässigkeit, nicht fehlende Daten.
- Suche: Open-Food-Facts-Suche nur bei Enter (Limit 10/min), keine Zusammenführung doppelter Treffer.
- Bilder: `Lebensmittel.bildKlein/bildGross` (`Ernaehrung.swift:100-111`), `offBildPasst` (`:705`),
  angezeigt in `ErnaehrungHinzufuegen.swift:233`, `ErnaehrungMahlzeit.swift:185/219/227`,
  `LebensmittelDetail.swift:122`.
- Teilen: `eigene` und `rezepteStand` sind heute schon nicht nach Person getrennt (`Ernaehrung.swift:365-366`),
  also geteilt. Es fehlt nur, wer etwas angelegt hat, und eine Ansicht dafür.

## Aufbau

Drei Datenquellen, eine Oberfläche.

### 1. BLS in der App (Grundlebensmittel, offline)

- Quelle: Bundeslebensmittelschlüssel 4.0, Max Rubner-Institut, Excel von blsdb.de, Lizenz CC BY 4.0.
  Rund 7.140 Lebensmittel. Namen wie YAZIO ("Hühnerei, Eier, gekocht").
- Ein Skript `tools/bls-import` liest das Excel und schreibt `lebensmittel-basis.json` neu:
  gleiches Format wie heute (`id`, `name`, `fluessig`, `pro100` mit Makros und den Mikro-Werten, die
  die App schon kennt, `portionen`). IDs `bls-<BLS-Code>`.
- Portionen: Die 122 heutigen Einträge behalten ihre Portionen (Zuordnung über den Namen, Rest von Hand).
  Für die übrigen erzeugt das Skript Portionen aus einer kleinen Regel-Tabelle pro Lebensmittelgruppe
  (Obst: Frucht klein/mittel/groß, Brot: Scheibe, Getränke: Glas 200 ml, Tasse 200 ml …).
  Ohne Regel gibt es nur Gramm bzw. ml.
- Quellenangabe in der App: "Nährwerte: Max Rubner-Institut, BLS 4.0 (CC BY 4.0)" auf der
  Lebensmittel-Seite eines BLS-Eintrags und unter Einstellungen.
- Suche: Trefferreihenfolge Wortanfang vor Teilwort, häufig gegessen vor selten, kurz vor lang.
- Tempo-Sicherungen (Ahmed: "muss blitzschnell sein"):
  - Das Import-Skript schreibt die Suchschlüssel (klein, ohne Umlaute, Wörter) schon ins JSON.
    Das Handy rechnet nichts vor.
  - Laden im Hintergrund, sobald die Ernährung geöffnet wird (nicht beim App-Start, spart Speicher
    und Akku, Ahmed 01.10.). Bis zum ersten Tippen ins Suchfeld ist der Index fertig. Ist er es noch
    nicht, zeigt die Suche zuerst Verlauf und Favoriten.
  - Suche außerhalb des Haupt-Threads, jeder Tastendruck bricht die vorige Suche ab.
  - Erst Verlauf und Favoriten (wenige hundert), dann BLS und eigene.
  - Höchstens 50 Treffer, Liste als `LazyVStack`, nur sichtbare Karten werden gebaut.
  - Test als Wächter: Suche über alle BLS-Einträge muss in der CI unter 16 ms bleiben (ein Bild bei 60 Hz).

### 2. Eigene Produkt-Datenbank auf dem Server (Marken und Barcodes)

- Neue Cloudflare-D1-Datenbank `lovea-essen` (test und live getrennt), nicht im Raum-Durable-Object.
  Tabelle `produkt(code PRIMARY KEY, name, marke, menge, portion_g, portion_name, pro100 JSON, beliebtheit)`
  plus FTS5-Tabelle über `name` und `marke`.
- Inhalt: alle Open-Food-Facts-Produkte mit Land Deutschland, Österreich oder Schweiz und Nährwerten.
  Nur die Felder oben. Erstbefüllung aus dem Open-Food-Facts-Export, danach jede Nacht die
  Delta-Dateien von Open Food Facts (GitHub Action mit Zeitplan).
- Worker-Endpunkte im bestehenden Worker `lovea`, gleiche App-Anmeldung wie die übrigen Routen:
  - `GET /essen/barcode/<code>` gibt ein Produkt oder 404.
  - `GET /essen/suche?q=<text>&n=30` gibt Treffer nach FTS-Rang und Beliebtheit.
- Erster Bauschritt misst die echte Größe und prüft den Cloudflare-Plan (D1-Grenze pro Datenbank).
  Passt es nicht, werden zuerst Produkte ohne Scans weggelassen.

### 3. Barcode-Kette

Der Scan probiert der Reihe nach und hört beim ersten Treffer auf:

1. Normalisieren: nur Ziffern, UPC-A (12) bekommt eine führende 0, EAN-8 und EAN-13 bleiben.
2. Lokal: geteilte eigene Lebensmittel mit diesem Barcode und ein Cache der letzten 500 Scan-Treffer.
3. Unser Server `/essen/barcode`.
4. Open Food Facts live (für Produkte, die neuer sind als die letzte Nacht). Eine Wiederholung nach 1 s,
   429 wird als "gerade überlastet" behandelt und geht zu Schritt 5 weiter statt abzubrechen.
5. Open EAN Database (opengtindb.org) nach dem Produktnamen. Mit dem Namen suchen wir in Server und BLS
   und zeigen "Meintest du …?" mit bis zu 5 Vorschlägen. Ein Tipp übernimmt den Vorschlag und merkt
   sich den Barcode dazu (geteilt).
6. Letzter Ausweg: Nährwert-Tabelle fotografieren. Apple-Texterkennung (Vision, auf dem Gerät, ohne KI-Dienst)
   liest kcal, Fett, Kohlenhydrate, Zucker, Eiweiß, Salz pro 100 g. Ahmed prüft, tippt Namen, speichert.
   Das Produkt wird ein geteiltes eigenes Lebensmittel mit Barcode.

Eine Barcode-Zahl im Suchfeld läuft durch dieselbe Kette.

### 4. Oberfläche, Aufbau wie YAZIO, Farben von Lovea

**Hinzufügen-Seite** (Bilder 02, 03, 05), ersetzt die Segmente in `HinzufuegenBlatt`:
- Kopf: links ein runder Zähler (wie viele Einträge in diesem Durchgang dazugekommen sind), Mitte der
  Mahlzeit-Name ("Frühstück").
- Kachel-Reihe, waagerecht scrollbar: Suche (aktiv), Kamera, Barcode, Sprache/Text, Mehr.
  Kamera und Sprache/Text öffnen ein kleines Blatt "Kommt bald". Mehr öffnet das Erstellen-Blatt.
- Suchfeld "Was hattest du zum <Mahlzeit>?".
- Zwei Auswahl-Knöpfe nebeneinander: Typ (Lebensmittel, Mahlzeiten, Rezepte) und Sortierung
  (Häufig, Zuletzt, Favoriten). Sie öffnen ein Menü wie in Bild 02/03.
- Liste: Zeile mit Name, darunter Standardportion ("1 Ei, mittelgroß (60 g)"), rechts kcal und ein
  rundes Plus. Plus trägt die Standardportion sofort ein, der Zähler oben zählt hoch, die Zeile
  bestätigt kurz. Zeile antippen öffnet die Lebensmittel-Seite.
- Unten fester Knopf "Fertig".

**Such-Modus** (Bilder 09, 10), sobald das Suchfeld aktiv ist:
- Kopf: Suchfeld mit Löschen-Kreuz und "Abbrechen".
- Chips: Favoriten, Von mir erstellt, Von Annika (bei Annika: Von Ahmed).
- Ergebnisse als Karten: Name fett, darunter "Marke, Portion", unten links Chip "Lebensmittel" /
  "Mahlzeit" / "Rezept", unten rechts kcal, oben rechts Plus.
- Tempo: Lokale Treffer (Verlauf, Favoriten, eigene, BLS) bei jedem Tastendruck, Ziel unter 50 ms.
  Server-Treffer nach 150 ms ohne Tippen, laufende Anfrage wird beim nächsten Tastendruck abgebrochen.
  Server-Treffer werden unter den lokalen angehängt, Doppelte (gleicher Barcode oder gleiche ID)
  fallen weg, sichtbare Karten verschieben sich nicht.
- Offline: nur lokale Treffer und eine leise Zeile "Markenprodukte gerade nicht erreichbar".

**Lebensmittel-Seite mit Mengen-Blatt** (Bilder 01, 06, 07, 08), ersetzt `MengenRadBlatt`:
- Oben großer Name auf dunkler Fläche, darunter vier Werte: Kalorien, Kohlenhydrate, Eiweiß, Fett.
  Sie rechnen live mit der gewählten Menge. Darunter "Geprüfte Nährwertangaben" (nur BLS) bzw.
  "Zuletzt hinzugefügt", wenn schon einmal gegessen.
- Unten ein festes Blatt mit Griff:
  - Zeile: links Mengenfeld (rechtsbündig, antippen öffnet die Zahlentastatur mit Komma), rechts die
    Einheit mit Pfeil nach unten. Nur das linke Feld nimmt Tastatur an.
  - Großer Knopf "Hinzufügen".
  - Darunter ein Rad mit drei Spalten: Ganzzahl (0 bis 1000), Bruch (–, 1/8, 1/4, 1/3, 1/2, 2/3, 3/4, 7/8),
    Einheit (Portionen des Lebensmittels, zuletzt Gramm bzw. Milliliter).
  - Rad und Feld sind gekoppelt: Tippen ins Feld setzt das Rad auf die nächste Stelle, Drehen schreibt
    die Zahl ins Feld (721 und 7/8 ergibt 721,875).
  - Startwert: die zuletzt gegessene Menge dieses Lebensmittels, sonst 1 Standardportion.
- Die YAZIO-Werbekarte "Lebensmittelbewertung, Alles freischalten" kommt nicht. An ihre Stelle kommt
  unsere vorhandene Bewertung (`ErnaehrungRating.swift`), weiter unten die Nährwerte im Detail.

**Erstellen-Blatt** (Bild 04), über "Mehr":
Schnell hinzufügen, Neues Lebensmittel mit Barcode, Neues Lebensmittel ohne Barcode, Neue Mahlzeit,
Neues Rezept. Die Editoren gibt es schon (`SchnellEintragenBlatt`, `EigenesLebensmittelEditor`,
`RezeptEditor`), sie werden nur neu verbunden. "Mit Barcode" startet den Scanner und dann Schritt 6.

### 5. Mahlzeiten und Rezepte für beide

- `Rezept` bekommt `art` (`mahlzeit` oder `rezept`), `anleitung` (nur Rezept, optional) und
  `von: Person`. Eigene Lebensmittel bekommen ebenfalls `von`. Alte Einträge ohne `von` zählen als
  "von mir" für beide.
- Mahlzeit = mehrere Lebensmittel mit Mengen, als ein Eintrag gespeichert. Rezept = dasselbe plus
  Anleitung und Anzahl Portionen.
- Chip "Von Annika" zeigt alles mit `von == Partner`. Jede Karte hat im Menü: "Zu mir kopieren"
  (neue ID, `von` = ich, danach frei änderbar) und "Favorit" (bleibt ihres, ändert sich mit).
- Ops bleiben `lebensmittel.setzen` und `rezept.setzen`, nur mit den neuen Feldern. Keine Server-Änderung
  am Raum nötig. Der Plan prüft, dass alte App-Versionen Einträge mit den neuen Feldern noch lesen.

### 6. Bilder raus

`bildKlein`, `bildGross`, `offBildPasst`, `ohneFuehrendeNullen`, `LebensmittelBild` und alle vier
Anzeigeorte werden gelöscht. Die Felder `images`/`image_*` fallen aus `ErnaehrungLogik.offFelder`.

## Akku

Lovea soll so akkuschonend wie möglich sein (Ahmed, 01.10.).
- Schwere Arbeit liegt nicht auf dem Handy: BLS-Aufbereitung im Import-Skript, Produkt-Import und
  nächtliche Aktualisierung auf GitHub/Cloudflare.
- BLS-Index erst beim Öffnen der Ernährung, wird nach Verlassen der Ernährung wieder freigegeben.
- Server-Suche erst nach 150 ms Tipp-Pause, alte Anfragen werden abgebrochen, keine Anfrage pro Buchstabe.
- Gemerkte Barcodes laufen nur beim nächsten Öffnen der Ernährung nach, nie im Hintergrund.
- Kamera (Scanner, Nährwert-Foto) läuft nur, solange das Blatt offen ist.
- Keine Bilder mehr: weniger Downloads.

## Fehlerfälle

- Server nicht erreichbar: Suche nur lokal, Barcode springt direkt zu Schritt 4.
- Alles fehlgeschlagen und kein Netz: "Kein Netz. Barcode gemerkt, wir suchen, sobald du online bist."
  Beim nächsten Öffnen läuft die Kette für gemerkte Barcodes still nach.
- Texterkennung findet keine Zahlen: Felder bleiben leer, Hinweis "Bitte näher und gerade fotografieren".
- Menge 0 oder leer: "Hinzufügen" ist aus.

## Tests

- Unit (Swift): Barcode-Normalisierung, Reihenfolge der Barcode-Kette mit Fakes, Mengen-Rechnung
  (Ganzzahl + Bruch × Portion), Such-Rangfolge, Zusammenführen ohne Doppelte, BLS-JSON lädt und hat
  über 7.000 Einträge, Nährwert-Parser für Texterkennung mit 5 echten Tabellen-Texten.
- Server (`node --test`): Barcode- und Suche-Route gegen eine kleine D1-Testdatenbank, Import-Skript
  mit 10 Beispielzeilen.
- Render-Tafeln in `RenderGalerieErnaehrungTests.swift`: Hinzufügen-Seite, Such-Modus mit Karten,
  Lebensmittel-Seite mit Mengen-Blatt (1 Frucht und 721 7/8), Erstellen-Blatt. Vergleich mit den
  YAZIO-Bildern von Hand.
- Messung: Suche nach "ei" über den ganzen lokalen Index unter 50 ms auf dem Gerät (Log in Debug).

## Nicht in diesem Plan

KI-Kamera, Sprache/Text-Eintrag, FatSecret, Gym/Hevy (eigener Plan), Zeichnen (eigener Plan).

## Im ersten Bauschritt zu klären

- Echte Größe der DACH-Produkte aus Open Food Facts mit den schlanken Feldern.
- Cloudflare-Plan und D1-Grenze. Die Cloudflare-Anmeldung ist in der Plan-Sitzung nicht verbunden.
- Ob das BLS-Excel Portionsangaben enthält.
- Ob opengtindb eine eigene Nutzer-ID braucht (laut Doku ja, kostenlos).
