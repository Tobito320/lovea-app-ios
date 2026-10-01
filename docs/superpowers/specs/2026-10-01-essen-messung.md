# Essen wie YAZIO – Messung (Task 1)

Stand: 01.10.2026. Ergebnis der Klärungen aus dem Design-Dokument, Abschnitt "Im ersten Bauschritt zu klären".

## 1. Größe der DACH-Produkte (Open Food Facts)

Skript: `tools/essen-import/messen.py`, gegen den offiziellen CSV-Export
(`https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz`, gestreamt, kein
Download im Speicher). Erster Versuch lieferte keine Ausgabe – eigener Fehler beim Hintergrund-Start
(Shell-`&` kombiniert mit Ausgabe-Umleitung hat den Prozess sofort beendet), nicht Open Food Facts.
Zweiter Versuch mit korrektem Hintergrund-Aufruf lief sauber durch.

- Zeilen im CSV gesamt: **4.532.767**
- DACH-Produkte mit `energy-kcal_100g` und Name: **309.361**
- Davon mit `unique_scans_n >= 1` (mindestens einmal gescannt): **187.391**
- Geschätzte Rohdatengröße (schlanke Felder, alle 309.361): **ca. 34 MB**
- Geschätzt mit FTS5-Index (Faktor 2,2): **ca. 76 MB**

76 MB liegt weit unter jeder D1-Grenze (siehe unten). **Die `unique_scans_n >= 1`-Filterung aus
Schritt 6 ist für die Größe nicht nötig.** Sie kann trotzdem wegen der Schreib-Tagesgrenze relevant
sein, siehe Abschnitt 3.

## 2. Cloudflare-Plan und D1-Grenzen

`npx wrangler whoami`: eingeloggt als `ahmedhdplay12345@gmail.com`, Account-ID
`30d9c51d2871999816ac7649c9cb536a`.

**Der genaue Workers-Plan (Free oder Paid) ließ sich nicht automatisch bestimmen**: Der OAuth-Token
von `wrangler login` hat keinen Billing-Scope, die Cloudflare-API lehnt `/accounts/{id}/subscriptions`
und `/accounts/{id}/workers/subscription` mit "Authentication error" ab. Vault durchsucht (keine
Notiz nennt den aktuellen Plan), Chrome-Erweiterungs-Tool zweimal probiert (nicht verbunden).
**Ahmed: bitte im Dashboard (dash.cloudflare.com → Workers & Pages → Plans) nachsehen, ob der
Account "Free" oder "Paid" ist** – das ändert die Empfehlung in Abschnitt 3.

D1-Grenzen (developers.cloudflare.com/d1/platform/limits, Stand 21.04.2026):

| Grenze | Free | Workers Paid |
|---|---|---|
| Maximale Datenbankgröße | 500 MB | 10 GB |
| Speicher gesamt pro Account | 5 GB | 1 TB |
| Maximale SQL-Statement-Länge | 100.000 Byte (100 KB), gilt auf beiden Plänen gleich | |
| Zeilen gelesen pro Tag / Monat | 5 Mio. / Tag | 25 Mrd. / Monat inklusive, danach $0,001/Mio. |
| Zeilen geschrieben pro Tag / Monat | 100.000 / Tag | 50 Mio. / Monat inklusive, danach $1/Mio. |

Mit ca. 76 MB Rohdaten liegt `lovea-essen` auf beiden Plänen weit unter der Datenbankgrößen-Grenze.
Die Schreib-Tagesgrenze ist die einzige Grenze, die für die Erstbefüllung relevant wird (Abschnitt 3).

## 3. Schreib-Grenze für die Erstbefüllung

Rechnung nach Brief: Anzahl DACH-Produkte × 3 (Tabelle + FTS-Trigger) = Zeilen für die Erstbefüllung.

- Alle 309.361 Produkte: **928.083 Zeilen**
- Nur `unique_scans_n >= 1` (187.391 Produkte): **562.173 Zeilen**

Beide Werte liegen **über der Free-Tagesgrenze von 100.000 Zeilen** (9,3× bzw. 5,6× so hoch).
Auf Workers Paid liegen beide Werte weit unter der Monatsgrenze von 50 Millionen inklusive – dort
ist die Erstbefüllung an einem Tag problemlos möglich.

**Das ändert das Design von Task 5 (Erstbefüllung), daher hier keine stille Kürzung. Zwei Wege für
Ahmed:**

1. **Erstbefüllung über mehrere Tage verteilen** (bei Free-Plan nötig): z. B. alle 309.361 Produkte
   in ca. 10 Tagesportionen à ~93.000 Zeilen (≈31.000 Produkte/Tag), gesteuert über einen Zähler
   (letzter importierter Datensatz) im Import-Skript. Kostet nichts extra, verzögert aber, bis die
   volle Datenbank befüllt ist.
2. **Workers Paid für 5 US-Dollar im Monat.** Damit läuft die Erstbefüllung an einem Tag durch, und
   die nächtlichen Delta-Updates haben viel Luft (50 Mio. Zeilen/Monat inklusive statt 100.000/Tag
   = 3 Mio./Monat).

Ahmed entscheidet, Task 5 richtet sich danach.

## 4. Geplanter Nachtjob auf dem privaten Repo

Geprüft mit `gh api repos/Tobito320/lovea-app-ios/actions/permissions` (nur lesend):

```json
{"enabled":true,"allowed_actions":"all","sha_pinning_required":false}
```

Das zeigt nur, dass Actions eingeschaltet ist, nicht ob Läufe tatsächlich durchkommen (eine
Billing-Sperre würde Jobs trotzdem sofort abbrechen lassen). Deshalb zusätzlich die echte Lauf-Historie
geprüft, ebenfalls nur lesend: `gh run list -R Tobito320/lovea-app-ios --limit 10`. Ergebnis: die
letzten 10 Läufe (TestFlight, iOS CI) sind durchgelaufen (acht `ok`, zwei `FAIL` – das sind
Job-Ergebnisse, also Code-/Test-Fehler, keine Infrastruktur- oder Abrechnungsfehler). Das ist der
Beleg, dass Jobs auf diesem privaten Repo tatsächlich ausgeführt werden, keine Billing-Sperre.

Der Billing-Endpunkt (`/users/Tobito320/settings/billing/actions`) ist mit dem vorhandenen
`gh`-Token nicht lesbar (braucht den `user`-Scope, den ich nicht angefordert habe, um den
Auth-Status nicht zu verändern) – war wegen der Lauf-Historie auch nicht mehr nötig. Kein
Test-Workflow angelegt, da die vorhandenen Läufe schon die Antwort liefern.

**Ergebnis: Task 5 kann den Nachtjob als GitHub-Action-`schedule` planen, keine Windows-Aufgabe
(`schtasks`) nötig.** Ein Hinweis für Task 5: `schedule`-Workflows laufen nur vom Standard-Branch
(`main`) aus, der Workflow muss also dort liegen.

## 5. BLS-Excel: Spalten und Portionen

Quelle: `https://blsdb.de/download` verlinkt eine Token-URL zu einem ZIP
(`BLS_4_0_2025_DE.zip`, 13,6 MB), keine direkte Excel-Datei. Enthält:
`BLS_4_0_Daten_2025_DE.xlsx` (Daten, 418 Spalten, ein Blatt `BLS_4_0_2025_DE`) und
`BLS_4_0_Components_DE_EN.xlsx` (Spaltenerklärung, zur Referenz behalten, nicht für den Import
gebraucht). Das Daten-Blatt liegt jetzt unter `tools/bls-import/BLS_4_0.xlsx` (gitignored) und in
`.superpowers/sdd/2026-10-01-essen-wie-yazio/BLS_4_0.xlsx` für Task 2.

**Portionen: Das BLS-Excel enthält keine einzige Spalte zu Portionsgrößen oder Verzehrmengen.**
(Suche über alle 418 Spaltennamen nach "Portion"/"Serving": keine Treffer.) Das bestätigt den Plan
aus der Design-Spec: Portionen kommen nur aus der Regel-Tabelle pro Lebensmittelgruppe bzw. den
122 vorhandenen Einträgen.

Jeder Nährwert hat 3 Spalten: Wert, "Datenherkunft", "Referenz". Unten stehen nur die Wert-Spalten.
Feldnamen aus dem echten Code: `struct Naehrwerte` (`Lovea/Sources/Health/Ernaehrung/Ernaehrung.swift:10`,
Felder `kcal`, `protein`, `kohlenhydrate`, `fett`, `zucker`, `ballaststoffe`, `salz`, `gesFett`,
dazu `mikro: [String: Double]`) und `enum Mikro` (`Mikronaehrstoffe.swift`, Schlüssel = `rawValue`).

| BLS-Spalte (Kürzel) | Bedeutung | Einheit | → Feld |
|---|---|---|---|
| BLS Code | ID | – | `id` (`bls-<code>`) |
| Lebensmittelbezeichnung | Name | – | `name` |
| ENERCC | Energie, Kilokalorien | kcal/100g | `pro100.kcal` |
| PROT625 | Protein (Nx6,25) | g/100g | `pro100.protein` |
| FAT | Fett | g/100g | `pro100.fett` |
| CHO | Kohlenhydrate, verfügbar | g/100g | `pro100.kohlenhydrate` |
| SUGAR | Zucker (Mono-/Disaccharide) | g/100g | `pro100.zucker` |
| FIBT | Ballaststoffe, gesamt | g/100g | `pro100.ballaststoffe` |
| NACL | Salz (Natriumchlorid) | g/100g | `pro100.salz` |
| FASAT | Fettsäuren, gesättigt, gesamt | g/100g | `pro100.gesFett` |
| WATER | Wasser | g/100g | `pro100.mikro["wasser"]` |
| ALC | Alkohol (Ethanol) | g/100g | `pro100.mikro["alkohol"]` |
| CHORL | Cholesterin | mg/100g | `pro100.mikro["cholesterin"]` |
| FAMS | Fettsäure, einfach ungesättigt, gesamt | g/100g | `pro100.mikro["einfachUngesaettigt"]` |
| FAPU | Fettsäuren, mehrfach ungesättigt, gesamt | g/100g | `pro100.mikro["mehrfachUngesaettigt"]` |
| VITA | Vitamin A, Retinol-Äquivalent | µg/100g | `pro100.mikro["vitaminA"]` |
| VITD | Vitamin D | µg/100g | `pro100.mikro["vitaminD"]` |
| VITE | Vitamin E (Alpha-Tocopherol) | mg/100g | `pro100.mikro["vitaminE"]` |
| VITK | Vitamin K | µg/100g | `pro100.mikro["vitaminK"]` |
| VITC | Vitamin C | mg/100g | `pro100.mikro["vitaminC"]` |
| THIA | Vitamin B1 (Thiamin) | mg/100g | `pro100.mikro["vitaminB1"]` |
| RIBF | Vitamin B2 (Riboflavin) | mg/100g | `pro100.mikro["vitaminB2"]` |
| NIA | Niacin | mg/100g | `pro100.mikro["niacin"]` |
| PANTAC | Pantothensäure | mg/100g | `pro100.mikro["pantothensaeure"]` |
| VITB6 | Vitamin B6 | **µg**/100g | `pro100.mikro["vitaminB6"]` (Mikro.einheit ist "mg" → BLS-Wert ÷1000) |
| FOL | Folat-Äquivalent | µg/100g | `pro100.mikro["folat"]` |
| VITB12 | Vitamin B12 (Cobalamine) | µg/100g | `pro100.mikro["vitaminB12"]` |
| K | Kalium | mg/100g | `pro100.mikro["kalium"]` |
| CA | Calcium | mg/100g | `pro100.mikro["calcium"]` |
| MG | Magnesium | mg/100g | `pro100.mikro["magnesium"]` |
| P | Phosphor | mg/100g | `pro100.mikro["phosphor"]` |
| FE | Eisen | mg/100g | `pro100.mikro["eisen"]` |
| ZN | Zink | mg/100g | `pro100.mikro["zink"]` |
| CU | Kupfer | **µg**/100g | `pro100.mikro["kupfer"]` (Mikro.einheit ist "mg" → BLS-Wert ÷1000) |
| MN | Mangan | **µg**/100g | `pro100.mikro["mangan"]` (Mikro.einheit ist "mg" → BLS-Wert ÷1000) |
| NA | Natrium | mg/100g | `pro100.mikro["natrium"]` |
| ID | Iodid | µg/100g | `pro100.mikro["jod"]` |

**Fehlen in BLS 4.0 (keine Spalte gefunden, Suche über alle 418 Spaltennamen):** `Mikro.selen` und
`Mikro.koffein` sind gültige Fälle in `enum Mikro`, aber keine BLS-Spalte liefert dafür einen Wert.
Task 2 lässt `mikro["selen"]` und `mikro["koffein"]` bei BLS-Einträgen einfach weg (wie bei jedem
Produkt ohne diesen Wert schon heute, `mikro` ist ein optionales Dictionary).

## 6. opengtindb: Nutzer-ID

`https://opengtindb.org/api.php`: Abfrage per `GET /?ean=<ean>&cmd=query&queryid=<userid>`.
**Ja, eine `queryid` ist zwingend.** Zwei Wege laut `userid.php`/FAQ:

- **Öffentliche Test-ID `400000000`**: frei nutzbar, aber von allen geteilt – laut FAQ schnell
  ausgeschöpft, liefert dann nur noch Fehlercode 5 ("Tageslimit erreicht"). Nur zum Ausprobieren
  der Schnittstelle geeignet, nicht für den Live-Betrieb.
- **Private ID für Privatanwender**: maximal 500 Abfragen/Tag mit Abfrageverzögerung. Ablauf laut
  `userid.php`: (1) einmalige Spende von mindestens 35 Euro an "Küste gegen Plastik" (in Deutschland
  steuerlich absetzbar, Überweisungsbeleg genügt als Spendennachweis), (2) den Zahlungsbeleg per
  Mail an den Betreiber schicken, (3) die UserID kommt dann typischerweise innerhalb einer Woche
  per Mail. Achtung: wird die ID länger nicht genutzt, wird sie wieder gelöscht.

**Das ist eine Geld-Entscheidung, die Ahmed treffen muss** (35 € Spende für eine private ID, oder
die Kette in Schritt 5 der Barcode-Kette (`opengtindb.org`) vorerst mit der öffentlichen Test-ID
bauen und akzeptieren, dass sie an belasteten Tagen ausfällt und Schritt 6 – Foto der
Nährwert-Tabelle – übernimmt). Nicht in diesem Task entschieden, an Ahmed weitergegeben.

## Offene Punkte für Ahmed

1. Cloudflare-Plan bestätigen (Free oder Workers Paid) – ändert, ob die Erstbefüllung an einem Tag
   oder über mehrere Tage läuft (Abschnitt 3).
2. opengtindb: 35 € für eine private `queryid` spenden, oder mit der geteilten Test-ID `400000000`
   leben (Abschnitt 6).
