# Essen wie YAZIO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Essen eintragen wie YAZIO: 7.140 BLS-Lebensmittel offline, eigene Produkt-Datenbank mit Barcodes auf dem Server, eine Barcode-Kette, die fast immer etwas findet, und die Hinzufügen-, Such- und Mengen-Ansicht eins zu eins nach YAZIO.

**Architecture:** Grundlebensmittel (BLS) liegen als vorbereitetes JSON in der App und werden beim Öffnen der Ernährung im Hintergrund in einen Suchindex geladen. Markenprodukte (Open Food Facts, nur DACH) liegen in einer Cloudflare-D1-Datenbank hinter neuen Routen `/essen/*` im bestehenden Worker `lovea`. Die App fragt der Reihe nach: lokal, eigener Server, Open Food Facts live, Open EAN Database (Name) mit Vorschlägen, zuletzt Nährwert-Foto mit Apple-Texterkennung.

**Tech Stack:** Swift 6 / SwiftUI (iOS 26), XCTest, Vision; Cloudflare Workers + D1 (FTS5), Node 22 `node --test` mit `node:sqlite`; Python 3.12 für die Import-Skripte (`openpyxl`, Standardbibliothek); GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-01-essen-wie-yazio-design.md`

## Global Constraints

- Ziel: TestFlight (test). Branch `essen-yazio` ab `runde-3`, Worktree `C:/Users/ahmed/code/lovea-essen`. Nur dieser Branch wird gepusht; Merge nach `runde-3` erst nach grüner CI und Ahmeds Ja.
- Kein Compiler auf dem Windows-PC. Jede Swift-Zeile gegen den vorhandenen Code greppen (Typen, Initialisierer, Namen). Die CI (`ios-ci.yml`, macOS) ist die einzige harte Prüfung.
- Build-Regel (Auftragsbrett): `lovea-app-ios` ist privat. Vor jedem CI-Lauf `gh repo edit Tobito320/lovea-app-ios --visibility public --accept-visibility-change-consequences`, nach dem Lauf wieder `--visibility private`.
- Akku-Regel (Auftragsbrett): nichts beim App-Start laden, keine Hintergrund-Timer, Netz nur bei Bedarf und gebündelt, Kamera nur solange ein Blatt offen ist. Jeder Task-Bericht nennt in einem Satz, was die Änderung am Akku kostet.
- Aufbau wie YAZIO, Farben von Lovea (`Color.accentColor`, `Feder.weich`, `Haptik`, `.fontDesign(.rounded)` wie im übrigen Ernährungscode).
- Deutsch in allen Texten. Keine Emojis. Kommentare nur, wo das Warum nicht offensichtlich ist (Stil der vorhandenen Dateien).
- BLS-Quellenangabe wörtlich: "Nährwerte: Max Rubner-Institut, BLS 4.0 (CC BY 4.0)".
- Suche: erste lokale Treffer unter 16 ms über den ganzen BLS-Index auf dem Gerät. Der CI-Test startet mit 50 ms Grenze (laute Simulatoren) und druckt `LEBENSMITTEL_SUCHE_MS`; nach dem ersten Lauf auf gemessen x 3 senken. Höchstens 50 Treffer, Server-Suche erst nach 150 ms Tipp-Pause.
- Subagenten nur Sonnet (`model: "sonnet"`), nie Haiku.

## Review Focus

- Barcodes mit führenden Nullen, UPC-A (12 Ziffern) und EAN-8 (Lidl-Eigenmarken) müssen denselben Datensatz finden wie das 13-stellige Gegenstück. Test in Task 6 (`BarcodeLogikTests`) und Task 4 (Server normalisiert gleich).
- Mengenfeld: "0,5", "500", "1.5", leeres Feld, "abc", "99999". Erwartet: Komma und Punkt gehen, leer/Text deaktiviert "Hinzufügen", große Zahlen bleiben im Feld stehen, das Rad klemmt am Rand. Test in Task 11 (`MengenRadLogikTests`).
- Suche mit Umlauten und ß: "käse", "kase", "Käse", "griess", "Grieß" finden dieselben Einträge. Test in Task 3 (`LebensmittelIndexTests`).
- Langsamer oder abbrechender Server beim Tippen: ältere Antworten dürfen neuere nicht überschreiben, sichtbare Karten springen nicht. Test in Task 10 (`SuchZusammenfuehrungTests`, Antwort mit alter Anfrage-Nummer wird verworfen).
- Annika ändert ein geteiltes Rezept, das Ahmed als Favorit hat: Ahmed sieht die neue Fassung; eine Kopie bleibt unverändert. Test in Task 9 (`ErnaehrungTeilenTests`).

---

## Reihenfolge und Parallelität

| Welle | Tasks (parallel) | Braucht |
|---|---|---|
| 1 | T1 Messen + D1 anlegen, T2 BLS-Import, T7 Nährwert-Foto-Parser, T8 Bilder raus, T9 Teilen, T11 Mengen-Blatt | – |
| 2 | T3 Lokaler Suchindex, T4 Server-Routen, T5 Produkt-Import + Nacht-Job | T2 (T3), T1 (T4, T5) |
| 3 | T6 Barcode-Kette | T3, T4 |
| 4 | T10 Hinzufügen- und Such-Ansicht | T3, T6, T7, T8, T9 |
| 5 | T12 CI, Deploy test/live, TestFlight | alle |

Ausführung:
- T8 zuerst allein im Haupt-Worktree `lovea-essen` (klein, mechanisch, fasst `Ernaehrung.swift` und `LebensmittelDetail.swift` an).
- Danach bekommt jeder parallele Task einen eigenen Worktree ab `essen-yazio`: `git -C C:/Users/ahmed/code/lovea-app-ios worktree add -b essen-t<N> C:/Users/ahmed/code/lovea-essen-t<N> essen-yazio`. Nie zwei Agenten im selben Ordner.
- Zurückführen nacheinander in `essen-yazio` (Merge, nicht Rebase): T2, T9, T11, T7, T1, dann Welle 2 usw.
- Nach Welle 1 den Draft-PR `essen-yazio` -> `runde-3` öffnen (die CI läuft nur auf PRs). Nach jeder Welle CI mit Öffentlich/Privat-Schalter.
- Überschneidungen: `Ernaehrung.swift` (T2 `Lebensmittel`-Felder, T9 `Rezept`/Faltung), `LebensmittelDetail.swift` (T11), `ErnaehrungModell.swift` (T6, T9, T10). Konflikte klein, beim Zurückführen lösen.

---

### Task 1: Messen, Cloudflare prüfen, D1 anlegen

Klärt die offenen Punkte der Spec, bevor Code gegen Annahmen gebaut wird.

**Files:**
- Create: `tools/essen-import/messen.py`
- Modify: `server/wrangler.toml` (D1-Bindings)
- Create: `docs/superpowers/specs/2026-10-01-essen-messung.md` (Ergebnis)

**Interfaces:**
- Produces: D1-Datenbanken `lovea-essen-test` und `lovea-essen-live`, Binding-Name `ESSEN` in allen drei Umgebungen von `wrangler.toml`. Ergebnis-Datei mit: Anzahl DACH-Produkte, geschätzte Größe in MB, Cloudflare-Plan, D1-Grenze pro Datenbank, ob BLS Portionen enthält, ob opengtindb eine Nutzer-ID verlangt.

- [ ] **Step 1: Mess-Skript schreiben**

`tools/essen-import/messen.py` liest den Open-Food-Facts-CSV-Export gestreamt (kein ganzer Download im Speicher) und zählt DACH-Produkte mit kcal.

```python
"""Zaehlt DACH-Produkte mit Naehrwerten im Open-Food-Facts-CSV und schaetzt die D1-Groesse.
Aufruf: python messen.py [pfad-oder-url]  (Standard: offizieller CSV-Export)"""
import csv, gzip, io, sys, urllib.request

URL = "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
LAENDER = {"en:germany", "en:austria", "en:switzerland"}
FELDER = ["code", "product_name", "brands", "quantity", "serving_size", "serving_quantity",
          "energy-kcal_100g", "proteins_100g", "carbohydrates_100g", "fat_100g", "sugars_100g",
          "fiber_100g", "salt_100g", "saturated-fat_100g", "unique_scans_n"]

def zeilen(quelle):
    roh = urllib.request.urlopen(quelle) if quelle.startswith("http") else open(quelle, "rb")
    csv.field_size_limit(2**31 - 1)  # sys.maxsize laeuft unter Windows ueber
    return csv.DictReader(io.TextIOWrapper(gzip.GzipFile(fileobj=roh), encoding="utf-8"), delimiter="\t")

def main():
    quelle = sys.argv[1] if len(sys.argv) > 1 else URL
    anzahl, bytes_ = 0, 0
    for z in zeilen(quelle):
        if not LAENDER & set((z.get("countries_tags") or "").split(",")):
            continue
        if not z.get("energy-kcal_100g") or not z.get("product_name"):
            continue
        anzahl += 1
        bytes_ += sum(len(z.get(f) or "") for f in FELDER) + 40
    print(f"DACH mit kcal: {anzahl}")
    print(f"Rohdaten ca. {bytes_ / 1e6:.0f} MB, mit FTS-Index ca. {bytes_ * 2.2 / 1e6:.0f} MB")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Messen**

Run: `python tools/essen-import/messen.py` (dauert je nach Leitung 10 bis 30 Minuten, mit `run_in_background` starten)
Expected: zwei Zeilen "DACH mit kcal: …" und "Rohdaten ca. … MB".

- [ ] **Step 3: Cloudflare-Plan und D1-Grenze prüfen**

Run: `cd server && npm install && npx wrangler whoami`
Expected: Konto-Name. Ist wrangler nicht angemeldet: Ahmed in einem Satz bitten, `npx wrangler login` in `C:\Users\ahmed\code\lovea-essen\server` auszuführen, dann weiter.
Dann in der Cloudflare-Doku (developers.cloudflare.com/d1/platform/limits) die Grenze "maximum database size" für den Plan des Kontos nachlesen und notieren.

- [ ] **Step 4: D1 anlegen und binden**

Run: `npx wrangler d1 create lovea-essen-test` und `npx wrangler d1 create lovea-essen-live`
Die ausgegebenen `database_id` in `server/wrangler.toml` eintragen:

```toml
[[d1_databases]]
binding = "ESSEN"
database_name = "lovea-essen-test"
database_id = "<id aus create test>"

[[env.test.d1_databases]]
binding = "ESSEN"
database_name = "lovea-essen-test"
database_id = "<id aus create test>"

[[env.live.d1_databases]]
binding = "ESSEN"
database_name = "lovea-essen-live"
database_id = "<id aus create live>"
```

Die Top-Level-Umgebung zeigt absichtlich auf die Test-Datenbank.

- [ ] **Step 4b: Schreib-Grenze und Nacht-Job prüfen (können das Design ändern)**

- D1-Limits für den Plan des Kontos nachlesen: "rows written per day" und "maximum SQL statement length". Rechnung: Anzahl DACH-Produkte x 3 (Tabelle + FTS-Trigger) = Zeilen für die Erstbefüllung. Liegt das über der Tagesgrenze: nicht still kürzen, sondern Ahmed zwei Wege nennen (Erstbefüllung über mehrere Tage verteilen, oder Workers Paid für 5 US-Dollar im Monat) und auf seine Wahl warten. Task 5 danach richten.
- Prüfen, ob ein geplanter Linux-Job auf dem privaten Repo überhaupt läuft: `gh api repos/Tobito320/lovea-app-ios/actions/permissions` und `gh api /users/Tobito320/settings/billing/actions` (falls erlaubt), sonst einen Test-Workflow mit `workflow_dispatch` im Branch anlegen, bei privatem Repo starten, Ergebnis ansehen, Workflow wieder löschen. Läuft er nicht (Billing-Sperre): Nacht-Job stattdessen als Windows-Aufgabe auf Ahmeds PC planen (Task 5 Step 6 dann `schtasks`-Befehl statt Workflow) und das Ahmed sagen.
- Beides in die Ergebnis-Datei schreiben.

- [ ] **Step 5: BLS und opengtindb prüfen**

BLS-Excel von https://blsdb.de/download laden (nach `tools/bls-import/BLS_4_0.xlsx`, Datei nicht committen, in `.gitignore`). Mit `python -c "import openpyxl; wb=openpyxl.load_workbook('tools/bls-import/BLS_4_0.xlsx', read_only=True); [print(ws.title, [c.value for c in next(ws.iter_rows(max_row=1))][:60]) for ws in wb]"` die Blätter und Spalten auflisten. Notieren: Spalte für BLS-Code, Name, kcal, Eiweiß, Fett, Kohlenhydrate, Zucker, Ballaststoffe, Salz/Natrium, gesättigte Fettsäuren, jede Mikro-Spalte, die zu `Mikro` passt (`Lovea/Sources/Health/Ernaehrung/Mikronaehrstoffe.swift`), und ob es Portionsangaben gibt.
opengtindb: https://opengtindb.org/api.php lesen, notieren wie man eine `queryid` bekommt.

- [ ] **Step 6: Ergebnis schreiben und committen**

`docs/superpowers/specs/2026-10-01-essen-messung.md` mit allen Zahlen aus Step 2 bis 5 und der BLS-Spaltenzuordnung als Tabelle (`BLS-Spalte -> Feld`). Liegt die geschätzte Größe über der D1-Grenze: Import in Task 5 nimmt nur Produkte mit `unique_scans_n >= 1`, das Ergebnis nennt die neue Anzahl.

```bash
git add tools/essen-import/messen.py server/wrangler.toml docs/superpowers/specs/2026-10-01-essen-messung.md .gitignore
git commit -m "chore(essen): Groesse gemessen, D1 lovea-essen angelegt"
```

---

### Task 2: BLS-Import

**Files:**
- Create: `tools/bls-import/bls_import.py`, `tools/bls-import/portionen.json`, `tools/bls-import/test_bls_import.py`
- Modify: `Lovea/Sources/Health/Ernaehrung/lebensmittel-basis.json` (neu erzeugt)
- Modify: `Lovea/Sources/Health/Ernaehrung/Ernaehrung.swift:74-96` (`Lebensmittel` bekommt `suche` und `quelle`)
- Test: `Lovea/Tests/ErnaehrungTests.swift`

**Interfaces:**
- Consumes: BLS-Spaltenzuordnung aus `docs/superpowers/specs/2026-10-01-essen-messung.md` (Task 1, Step 5). Läuft Task 2 vor Task 1 fertig: Step 5 von Task 1 selbst ausführen.
- Produces: `lebensmittel-basis.json` mit über 7.000 Einträgen, jeder mit `id` = `bls-<Code>`, `name`, `fluessig`, `pro100`, `portionen`, `suche` (String: klein, ohne Umlaute, Wörter mit einem Leerzeichen getrennt, ß -> ss), `quelle` = `"bls"`.
  Swift: `Lebensmittel.suche: String?`, `Lebensmittel.quelle: String?` (beide optional, alte Einträge bleiben lesbar), dazu im `init` am Ende `suche: String? = nil, quelle: String? = nil`.

- [ ] **Step 1: Python-Test für die Normalisierung und Portionsregeln**

`tools/bls-import/test_bls_import.py`:

```python
from bls_import import suchschluessel, portionen_fuer

def test_suchschluessel():
    assert suchschluessel("Hühnerei, Eier, gekocht") == "huhnerei eier gekocht"
    assert suchschluessel("Grieß (Weizen)") == "griess weizen"
    assert suchschluessel("Käse,  Gouda 45%") == "kase gouda 45"

def test_portionen_regel_und_alt():
    alt = {"banane (ohne schale) frisch": [{"name": "Frucht, mittelgroß", "gramm": 150}]}
    regeln = [{"muster": "apfel", "portionen": [{"name": "Frucht, mittelgroß", "gramm": 130}]}]
    assert portionen_fuer("Banane (ohne Schale), frisch", alt, regeln)[0]["gramm"] == 150
    assert portionen_fuer("Apfel, roh", alt, regeln)[0]["gramm"] == 130
    assert portionen_fuer("Zimt, gemahlen", alt, regeln) == []

if __name__ == "__main__":
    test_suchschluessel(); test_portionen_regel_und_alt(); print("ok")
```

- [ ] **Step 2: Test laufen lassen**

Run: `cd tools/bls-import && python test_bls_import.py`
Expected: FAIL mit `ModuleNotFoundError: No module named 'bls_import'`.

- [ ] **Step 3: Import-Skript schreiben**

`tools/bls-import/bls_import.py`. Die Spaltennamen in `SPALTEN` und `MIKRO` kommen aus der Tabelle in `2026-10-01-essen-messung.md`; die Werte unten sind die Feld-Namen der App und bleiben so.

```python
"""Erzeugt Lovea/Sources/Health/Ernaehrung/lebensmittel-basis.json aus dem BLS 4.0 (Max Rubner-Institut, CC BY 4.0).
Aufruf: python bls_import.py BLS_4_0.xlsx
Alte Portionen aus der bisherigen JSON bleiben erhalten (Zuordnung ueber den Suchschluessel),
sonst Regeln aus portionen.json (erste passende Regel gewinnt), sonst keine Portionen."""
import json, re, sys, unicodedata
from pathlib import Path

ZIEL = Path(__file__).resolve().parents[2] / "Lovea/Sources/Health/Ernaehrung/lebensmittel-basis.json"
REGELN = Path(__file__).with_name("portionen.json")

# App-Feld -> BLS-Spaltenname (aus 2026-10-01-essen-messung.md eintragen)
SPALTEN = {"code": "", "name": "", "kcal": "", "protein": "", "kohlenhydrate": "", "fett": "",
           "zucker": "", "ballaststoffe": "", "natrium_mg": "", "gesFett": "", "wasser_g": ""}
# Mikro.rawValue -> BLS-Spaltenname; nur Werte, die es im BLS gibt
MIKRO: dict[str, str] = {}
# BLS-Codes, die mit diesen Buchstaben beginnen, sind Getraenke (BLS-Hauptgruppe N)
FLUESSIG_PRAEFIX = ("N",)

def suchschluessel(name: str) -> str:
    t = name.lower().replace("ß", "ss")
    t = unicodedata.normalize("NFKD", t)
    t = "".join(c for c in t if not unicodedata.combining(c))
    return " ".join(re.findall(r"[a-z0-9]+", t))

def portionen_fuer(name: str, alt: dict, regeln: list) -> list:
    s = suchschluessel(name)
    if s in alt:
        return alt[s]
    for r in regeln:
        if re.search(r["muster"], s):
            return r["portionen"]
    return []

def zahl(x):
    try:
        return round(float(str(x).replace(",", ".")), 3)
    except (TypeError, ValueError):
        return None

def main():
    import openpyxl
    wb = openpyxl.load_workbook(sys.argv[1], read_only=True)
    ws = wb.worksheets[0]
    zeilen = ws.iter_rows(values_only=True)
    kopf = list(next(zeilen))
    idx = {feld: kopf.index(spalte) for feld, spalte in SPALTEN.items()}
    midx = {m: kopf.index(s) for m, s in MIKRO.items()}
    alt = {suchschluessel(e["name"]): e["portionen"] for e in json.loads(ZIEL.read_text("utf-8")) if e.get("portionen")}
    regeln = json.loads(REGELN.read_text("utf-8"))
    liste = []
    for z in zeilen:
        code, name, kcal = z[idx["code"]], z[idx["name"]], zahl(z[idx["kcal"]])
        if not code or not name or kcal is None:
            continue
        natrium = zahl(z[idx["natrium_mg"]])
        mikro = {m: v for m, i in midx.items() if (v := zahl(z[i])) is not None}
        liste.append({
            "id": f"bls-{code}", "name": str(name).strip(), "quelle": "bls",
            "fluessig": str(code).startswith(FLUESSIG_PRAEFIX),
            "suche": suchschluessel(str(name)),
            "pro100": {k: v for k, v in {
                "kcal": kcal, "protein": zahl(z[idx["protein"]]) or 0,
                "kohlenhydrate": zahl(z[idx["kohlenhydrate"]]) or 0, "fett": zahl(z[idx["fett"]]) or 0,
                "zucker": zahl(z[idx["zucker"]]), "ballaststoffe": zahl(z[idx["ballaststoffe"]]),
                "salz": round(natrium * 2.5 / 1000, 3) if natrium is not None else None,
                "gesFett": zahl(z[idx["gesFett"]]), "mikro": mikro or None}.items() if v is not None},
            "portionen": portionen_fuer(str(name), alt, regeln),
        })
    ZIEL.write_text(json.dumps(liste, ensure_ascii=False, separators=(",", ":")), "utf-8")
    print(f"{len(liste)} Lebensmittel geschrieben")

if __name__ == "__main__":
    main()
```

`tools/bls-import/portionen.json` mit Regeln für die häufigsten Gruppen (Reihenfolge = Priorität, `muster` ist ein Regex auf den Suchschlüssel):

```json
[
  {"muster": "^ei |^huhnerei", "portionen": [{"name": "Ei, mittelgroß", "gramm": 60}, {"name": "Ei, groß", "gramm": 70}]},
  {"muster": "^banane", "portionen": [{"name": "Frucht, mittelgroß", "gramm": 150}, {"name": "Frucht, klein", "gramm": 75}, {"name": "Frucht, groß", "gramm": 200}]},
  {"muster": "^apfel", "portionen": [{"name": "Frucht, mittelgroß", "gramm": 130}, {"name": "Frucht, klein", "gramm": 100}, {"name": "Frucht, groß", "gramm": 180}]},
  {"muster": "^(birne|orange|pfirsich|nektarine|kiwi|mandarine)", "portionen": [{"name": "Frucht, mittelgroß", "gramm": 120}]},
  {"muster": "brotchen|semmel", "portionen": [{"name": "Brötchen, ganz", "gramm": 60}]},
  {"muster": "^brot|toast", "portionen": [{"name": "Scheibe", "gramm": 40}]},
  {"muster": "^butter|margarine", "portionen": [{"name": "Aufstrich", "gramm": 10}]},
  {"muster": "haferflocken|musli|cornflakes", "portionen": [{"name": "Portion", "gramm": 40}]},
  {"muster": "^milch|kuhmilch|joghurt|kefir|buttermilch", "portionen": [{"name": "Glas", "gramm": 200}]},
  {"muster": "quark|skyr", "portionen": [{"name": "Becher", "gramm": 250}, {"name": "Esslöffel", "gramm": 30}]},
  {"muster": "kaffee|tee ", "portionen": [{"name": "Tasse, mittelgroß", "gramm": 200}, {"name": "Tasse, groß", "gramm": 300}]},
  {"muster": "saft|limonade|cola|wasser", "portionen": [{"name": "Glas", "gramm": 200}]},
  {"muster": "kase|gouda|emmentaler", "portionen": [{"name": "Scheibe", "gramm": 25}]},
  {"muster": "reis|nudeln|spaghetti|kartoffel", "portionen": [{"name": "Portion, gekocht", "gramm": 200}]},
  {"muster": "zucker|honig|marmelade|konfiture", "portionen": [{"name": "Teelöffel", "gramm": 7}, {"name": "Esslöffel", "gramm": 20}]},
  {"muster": "ol |ol$|rapsol|olivenol", "portionen": [{"name": "Esslöffel", "gramm": 10}]}
]
```

- [ ] **Step 4: Test und Import laufen lassen**

Run: `cd tools/bls-import && pip install openpyxl && python test_bls_import.py && python bls_import.py BLS_4_0.xlsx`
Expected: `ok`, dann `7xxx Lebensmittel geschrieben` (über 7.000). Stichprobe: `python -c "import json;d=json.load(open('../../Lovea/Sources/Health/Ernaehrung/lebensmittel-basis.json',encoding='utf-8'));print(len(d));print([e for e in d if e['suche'].startswith('banane')][:1])"` zeigt eine Banane mit Portionen und plausiblen Werten (rund 90 bis 95 kcal pro 100 g).

- [ ] **Step 5: Swift-Felder und Test**

In `Lebensmittel` (`Ernaehrung.swift`) zwei optionale Felder ergänzen, im `init` mit Standard `nil`:

```swift
    /// Vorberechneter Suchschlüssel aus dem Import (klein, ohne Umlaute), nur bei BLS-Einträgen.
    var suche: String?
    /// "bls" für Einträge aus dem Bundeslebensmittelschlüssel (Quellenangabe auf der Lebensmittel-Seite).
    var quelle: String?
```

Test in `ErnaehrungTests.swift`:

```swift
    func testBLSGrunddatenbank() {
        let alle = LebensmittelBasis.laden(Bundle(for: ErnaehrungTests.self)).isEmpty
            ? LebensmittelBasis.laden(.main) : LebensmittelBasis.laden(Bundle(for: ErnaehrungTests.self))
        XCTAssertGreaterThan(alle.count, 7000)
        XCTAssertTrue(alle.allSatisfy { $0.id.hasPrefix("bls-") && $0.quelle == "bls" && $0.suche?.isEmpty == false })
        let banane = alle.first { $0.suche?.hasPrefix("banane") == true }
        XCTAssertNotNil(banane?.portionen?.first)
    }
```

Die bisherigen Tests, die IDs wie `basis-tomaten` erwarten, auf die neuen `bls-…`-IDs umstellen (grep `basis-` in `Lovea/Tests`).

- [ ] **Step 6: Commit**

```bash
git add tools/bls-import Lovea/Sources/Health/Ernaehrung/lebensmittel-basis.json Lovea/Sources/Health/Ernaehrung/Ernaehrung.swift Lovea/Tests/ErnaehrungTests.swift
git commit -m "feat(essen): BLS 4.0 als Grunddatenbank (7.140 Lebensmittel)"
```

---

### Task 3: Lokaler Suchindex

**Files:**
- Modify: `Lovea/Sources/Health/Ernaehrung/LebensmittelBasis.swift` (wird zum Index)
- Test: `Lovea/Tests/LebensmittelIndexTests.swift`

**Interfaces:**
- Consumes: `Lebensmittel.suche` (Task 2).
- Produces:
  - `LebensmittelBasis.normal(_ text: String) -> String` (klein, ohne Umlaute, ß -> ss, Wörter mit einem Leerzeichen) – gleiche Regel wie `suchschluessel` in Python.
  - `final class LebensmittelIndex: @unchecked Sendable` mit `static let shared`, `func laden()` (einmal, im Hintergrund, idempotent), `var bereit: Bool`, `func freigeben()`, `func suchen(_ text: String, vorne: [Lebensmittel], anzahl: Int = 50) -> [Lebensmittel]` (synchron, reine Funktion über die geladenen Daten; `vorne` = Verlauf/Favoriten/eigene, die zuerst durchsucht werden).
  - `LebensmittelBasis.treffer(_:_:anzahl:)` bleibt als reine Funktion für Tests und nutzt vorberechnete Schlüssel, falls vorhanden.

- [ ] **Step 1: Tests schreiben**

```swift
import XCTest
@testable import Lovea

final class LebensmittelIndexTests: XCTestCase {
    private func l(_ id: String, _ name: String) -> Lebensmittel {
        Lebensmittel(id: id, name: name, pro100: Naehrwerte(kcal: 100, protein: 1, kohlenhydrate: 1, fett: 1),
                     suche: LebensmittelBasis.normal(name))
    }

    func testNormalUmlauteUndEszett() {
        XCTAssertEqual(LebensmittelBasis.normal("Käse, Gouda"), "kase gouda")
        XCTAssertEqual(LebensmittelBasis.normal("Grieß"), "griess")
    }

    func testUmlautSucheFindetGleiches() {
        let liste = [l("1", "Käse, Gouda"), l("2", "Grießbrei"), l("3", "Kakao")]
        for q in ["käse", "kase", "Käse"] { XCTAssertEqual(LebensmittelBasis.treffer(liste, q).first?.id, "1", q) }
        for q in ["griess", "Grieß"] { XCTAssertEqual(LebensmittelBasis.treffer(liste, q).first?.id, "2", q) }
    }

    func testVorneKommtZuerstUndOhneDoppelte() {
        let ei = l("bls-1", "Hühnerei, gekocht")
        let index = LebensmittelIndex(testDaten: [ei, l("bls-2", "Eierlikör")])
        let verlauf = [l("off-9", "Bio-Eier (L)"), ei]
        let t = index.suchen("ei", vorne: verlauf)
        XCTAssertEqual(t.first?.id, "off-9")
        XCTAssertEqual(t.filter { $0.id == "bls-1" }.count, 1)
        XCTAssertLessThanOrEqual(index.suchen("e", vorne: []).count, 50)
    }

    func testTempoUeberGanzenIndex() {
        let alle = LebensmittelBasis.laden(.main).isEmpty ? LebensmittelBasis.laden(Bundle(for: Self.self)) : LebensmittelBasis.laden(.main)
        let index = LebensmittelIndex(testDaten: alle)
        _ = index.suchen("ei", vorne: [])
        let start = Date()
        for q in ["ei", "banane", "kase gouda", "mager"] { _ = index.suchen(q, vorne: []) }
        let proSuche = Date().timeIntervalSince(start) / 4
        print("LEBENSMITTEL_SUCHE_MS \(Int(proSuche * 1000))")
        // ponytail: Grenze mit Luft für laute CI-Simulatoren; nach dem ersten CI-Lauf auf gemessen x 3 setzen.
        XCTAssertLessThan(proSuche, 0.050, "Suche \(Int(proSuche * 1000)) ms")
    }
}
```

- [ ] **Step 2: Tests laufen lassen (CI)**

Kein Compiler lokal. Erwartet beim nächsten CI-Lauf: FAIL, `LebensmittelIndex` und `normal` fehlen. Weiter mit Step 3, CI am Ende von Welle 2 gemeinsam.

- [ ] **Step 3: Implementierung**

`LebensmittelBasis.swift` komplett ersetzen:

```swift
import Foundation

/// Eingebaute Grund-Datenbank (BLS 4.0) aus `lebensmittel-basis.json`, läuft offline.
enum LebensmittelBasis {
    static func laden(_ bundle: Bundle) -> [Lebensmittel] {
        guard let url = bundle.url(forResource: "lebensmittel-basis", withExtension: "json")
                ?? bundle.url(forResource: "lebensmittel-basis", withExtension: "json", subdirectory: "Health/Ernaehrung"),
              let daten = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([Lebensmittel].self, from: daten) else { return [] }
        return liste
    }

    /// Gleiche Regel wie `suchschluessel` in `tools/bls-import/bls_import.py`.
    static func normal(_ text: String) -> String {
        let t = text.lowercased().replacingOccurrences(of: "ß", with: "ss")
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "de_DE"))
        return t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }

    static func schluessel(_ l: Lebensmittel) -> String { l.suche ?? normal(l.name + " " + (l.marke ?? "")) }

    /// Jedes Wort im Suchtext muss als Wortanfang vorkommen. Name beginnt mit dem Suchtext zuerst, dann kürzere Namen.
    static func treffer(_ liste: [Lebensmittel], _ text: String, anzahl: Int = 50) -> [Lebensmittel] {
        let t = normal(text)
        guard !t.isEmpty else { return [] }
        let woerter = t.split(separator: " ")
        var vorn: [Lebensmittel] = [], sonst: [Lebensmittel] = []
        for l in liste {
            let s = schluessel(l)
            guard woerter.allSatisfy({ w in s.hasPrefix(w) || s.contains(" " + w) }) else { continue }
            if s.hasPrefix(t) { vorn.append(l) } else { sonst.append(l) }
        }
        // String.count ist O(n); Länge einmal pro Treffer rechnen statt bei jedem Vergleich.
        func kurzZuerst(_ liste: [Lebensmittel]) -> [Lebensmittel] {
            liste.map { ($0, $0.name.utf8.count) }.sorted { $0.1 < $1.1 }.map(\.0)
        }
        return Array((kurzZuerst(vorn) + kurzZuerst(sonst)).prefix(anzahl))
    }
}

/// BLS-Index im Speicher. Lädt erst, wenn die Ernährung geöffnet wird, und gibt beim Verlassen frei (Akku, Speicher).
final class LebensmittelIndex: @unchecked Sendable {
    static let shared = LebensmittelIndex()
    private let sperre = NSLock()
    private var daten: [Lebensmittel] = []
    private var laedt = false

    init() {}
    init(testDaten: [Lebensmittel]) { daten = testDaten }

    var bereit: Bool { sperre.withLock { !daten.isEmpty } }

    func laden() {
        let starten = sperre.withLock { () -> Bool in
            guard daten.isEmpty, !laedt else { return false }
            laedt = true
            return true
        }
        guard starten else { return }
        Task.detached(priority: .utility) { [weak self] in
            let liste = LebensmittelBasis.laden(.main)
            self?.sperre.withLock { self?.daten = liste; self?.laedt = false }
        }
    }

    func freigeben() { sperre.withLock { daten = [] } }

    /// `vorne` (Verlauf, Favoriten, eigene) zuerst, dann BLS, ohne doppelte IDs, höchstens `anzahl`.
    func suchen(_ text: String, vorne: [Lebensmittel], anzahl: Int = 50) -> [Lebensmittel] {
        let basis = sperre.withLock { daten }
        var gesehen: Set<String> = []
        let a = LebensmittelBasis.treffer(vorne, text, anzahl: anzahl).filter { gesehen.insert($0.id).inserted }
        let b = LebensmittelBasis.treffer(basis, text, anzahl: anzahl).filter { gesehen.insert($0.id).inserted }
        return Array((a + b).prefix(anzahl))
    }
}
```

Hinweis: Den `Lebensmittel`-Initialisierer im Test (`suche:`-Parameter) gibt es nur, wenn Task 2 ihn im `init` ergänzt hat (Parameter `suche: String? = nil, quelle: String? = nil` am Ende). Vor dem Commit greppen.

Alle bisherigen Aufrufer von `LebensmittelBasis.suchen` und `LebensmittelBasis.alle` finden (`grep -rn "LebensmittelBasis\." Lovea/Sources`) und auf `LebensmittelIndex.shared.suchen(_:vorne:)` umstellen. `LebensmittelIndex.shared.laden()` in `.onAppear` der Ernährungs-Ansicht (`ErnaehrungView.swift`, äußerste View) und `freigeben()` in `.onDisappear` derselben View.

- [ ] **Step 4: Commit**

```bash
git add Lovea/Sources/Health/Ernaehrung/LebensmittelBasis.swift Lovea/Sources/Health/Ernaehrung/ErnaehrungView.swift Lovea/Tests/LebensmittelIndexTests.swift
git commit -m "feat(essen): schneller lokaler Suchindex, laedt erst in der Ernaehrung"
```

---

### Task 4: Server-Routen `/essen/*`

**Files:**
- Create: `server/essen.js`, `server/essen.test.js`, `server/essen-schema.sql`, `server/fake-d1.js`
- Modify: `server/index.js` (Weiche vor dem Raum)

**Interfaces:**
- Consumes: Binding `env.ESSEN` (Task 1).
- Produces (HTTP, gleiche Anmeldung `X-Lovea-Key`/`X-Lovea-Person`):
  - `GET /essen/barcode/<ziffern>` -> 200 `{"produkt": Produkt}` oder 404 `{"produkt": null}`
  - `GET /essen/suche?q=<text>&n=<1..50>` -> 200 `{"treffer": [Produkt]}`
  - `GET /essen/name/<ziffern>` -> 200 `{"name": String, "marke": String|null}`, 404 wenn unbekannt, 503 wenn `env.OPENGTINDB_ID` fehlt
  - `Produkt` = `{"code", "name", "marke", "menge", "portion_g", "portion_name", "pro100": {"kcal","protein","kohlenhydrate","fett","zucker","ballaststoffe","salz","gesFett"}}`
  - Normalisierung (gleich wie Swift in Task 6): nur Ziffern; 12 Ziffern -> "0" + Code; 8 und 13 bleiben; andere Längen unverändert.

- [ ] **Step 1: Schema**

`server/essen-schema.sql`:

```sql
CREATE TABLE IF NOT EXISTS produkt (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  marke TEXT,
  menge TEXT,
  portion_g REAL,
  portion_name TEXT,
  pro100 TEXT NOT NULL,
  beliebtheit INTEGER NOT NULL DEFAULT 0
);
CREATE VIRTUAL TABLE IF NOT EXISTS produkt_fts USING fts5(name, marke, content='produkt', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2');
CREATE TRIGGER IF NOT EXISTS produkt_ai AFTER INSERT ON produkt BEGIN
  INSERT INTO produkt_fts(rowid, name, marke) VALUES (new.rowid, new.name, new.marke);
END;
CREATE TRIGGER IF NOT EXISTS produkt_ad AFTER DELETE ON produkt BEGIN
  INSERT INTO produkt_fts(produkt_fts, rowid, name, marke) VALUES ('delete', old.rowid, old.name, old.marke);
END;
CREATE TRIGGER IF NOT EXISTS produkt_au AFTER UPDATE ON produkt BEGIN
  INSERT INTO produkt_fts(produkt_fts, rowid, name, marke) VALUES ('delete', old.rowid, old.name, old.marke);
  INSERT INTO produkt_fts(rowid, name, marke) VALUES (new.rowid, new.name, new.marke);
END;
```

- [ ] **Step 2: Fake-D1 für Tests**

`server/fake-d1.js` (D1-API-Teilmenge: `prepare().bind().first()/all()`, `exec`):

```js
// Stand-in für Cloudflare D1 in Node-Tests, auf node:sqlite (inkl. FTS5).
import { DatabaseSync } from "node:sqlite";

export function fakeD1(schema) {
  const db = new DatabaseSync(":memory:");
  if (schema) db.exec(schema);
  const stmt = (sql, werte = []) => ({
    bind: (...w) => stmt(sql, w),
    first: async () => db.prepare(sql).get(...werte) ?? null,
    all: async () => ({ results: db.prepare(sql).all(...werte) }),
    run: async () => { db.prepare(sql).run(...werte); return { success: true }; },
  });
  return { prepare: (sql) => stmt(sql), exec: async (sql) => db.exec(sql), roh: db };
}
```

- [ ] **Step 3: Tests schreiben**

`server/essen.test.js`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { handleEssen, normalisiere, opengtindbParsen } from "./essen.js";
import { fakeD1 } from "./fake-d1.js";

const schema = readFileSync(new URL("./essen-schema.sql", import.meta.url), "utf8");
function env() {
  const ESSEN = fakeD1(schema);
  const add = (code, name, marke, kcal, bel = 0) => ESSEN.roh.prepare(
    "INSERT INTO produkt (code,name,marke,pro100,beliebtheit) VALUES (?,?,?,?,?)")
    .run(code, name, marke, JSON.stringify({ kcal, protein: 11, kohlenhydrate: 4, fett: 0.2 }), bel);
  add("4311501679715", "Skyr Natur", "Gut & Günstig", 65, 50);
  add("20123456", "Magerquark", "Milbona", 67, 10);
  add("0012345678905", "Peanut Butter", "Brand", 590, 1);
  add("4000000000001", "Käse Gouda", "Milram", 356, 5);
  return { ESSEN };
}
const hol = (pfad, e = env()) => handleEssen(new URL("https://x" + pfad), e);

test("normalisiere", () => {
  assert.equal(normalisiere(" 4311501679715 "), "4311501679715");
  assert.equal(normalisiere("012345678905"), "0012345678905");
  assert.equal(normalisiere("20123456"), "20123456");
});

test("barcode gefunden, UPC-A und EAN-8", async () => {
  const e = env();
  assert.equal((await (await hol("/essen/barcode/4311501679715", e)).json()).produkt.name, "Skyr Natur");
  assert.equal((await (await hol("/essen/barcode/012345678905", e)).json()).produkt.code, "0012345678905");
  assert.equal((await (await hol("/essen/barcode/20123456", e)).json()).produkt.marke, "Milbona");
});

test("barcode unbekannt -> 404", async () => {
  const r = await hol("/essen/barcode/1111111111111");
  assert.equal(r.status, 404);
});

test("suche: Wortanfang, Umlaute, Beliebtheit, Grenze", async () => {
  const e = env();
  const t = (await (await hol("/essen/suche?q=sky", e)).json()).treffer;
  assert.equal(t[0].code, "4311501679715");
  assert.equal(t[0].pro100.kcal, 65);
  const k = (await (await hol("/essen/suche?q=kase", e)).json()).treffer;
  assert.equal(k[0].name, "Käse Gouda");
  const leer = (await (await hol("/essen/suche?q=", e)).json()).treffer;
  assert.deepEqual(leer, []);
  const sonder = await hol('/essen/suche?q=%22%29%28*', e);
  assert.equal(sonder.status, 200);
});

test("zweimal importiert -> einmal gefunden (FTS ohne Leichen)", async () => {
  const e = env();
  const upsert = "INSERT INTO produkt (code,name,marke,pro100,beliebtheit) VALUES (?,?,?,?,?) " +
    "ON CONFLICT(code) DO UPDATE SET name=excluded.name, marke=excluded.marke, pro100=excluded.pro100";
  e.ESSEN.roh.prepare(upsert).run("4311501679715", "Skyr Natur neu", "Gut & Günstig", JSON.stringify({ kcal: 64 }), 50);
  const t = (await (await hol("/essen/suche?q=skyr", e)).json()).treffer;
  assert.equal(t.length, 1);
  assert.equal(t[0].name, "Skyr Natur neu");
  const alt = (await (await hol("/essen/suche?q=natur", e)).json()).treffer;
  assert.equal(alt.length, 1);
});

test("opengtindb Antwort parsen", () => {
  const text = "error=0\n---\nname=Skyr Natur\ndetailname=\nvendor=Gut & Günstig\n---\n";
  assert.deepEqual(opengtindbParsen(text), { name: "Skyr Natur", marke: "Gut & Günstig" });
  assert.equal(opengtindbParsen("error=1\n"), null);
});

test("name ohne ID -> 503", async () => {
  const r = await hol("/essen/name/4311501679715");
  assert.equal(r.status, 503);
});
```

- [ ] **Step 4: Test laufen lassen**

Run: `cd server && node --test essen.test.js`
Expected: FAIL, `Cannot find module './essen.js'`.

- [ ] **Step 5: Implementierung**

`server/essen.js`:

```js
// Essen-Datenbank (Open Food Facts DACH in D1) und Name-Nachschlag bei der Open EAN Database.
export function normalisiere(roh) {
  const z = String(roh ?? "").replace(/\D/g, "");
  return z.length === 12 ? "0" + z : z;
}

function produkt(zeile) {
  if (!zeile) return null;
  return {
    code: zeile.code, name: zeile.name, marke: zeile.marke ?? null, menge: zeile.menge ?? null,
    portion_g: zeile.portion_g ?? null, portion_name: zeile.portion_name ?? null,
    pro100: JSON.parse(zeile.pro100),
  };
}

// FTS5-Anfrage aus freiem Text: nur Buchstaben/Ziffern, jedes Wort als Präfix.
function ftsAnfrage(q) {
  const woerter = String(q ?? "").toLowerCase().match(/[\p{L}\p{N}]+/gu) ?? [];
  return woerter.slice(0, 6).map((w) => `"${w}"*`).join(" ");
}

export function opengtindbParsen(text) {
  const felder = Object.fromEntries(
    text.split("\n").filter((z) => z.includes("=")).map((z) => [z.slice(0, z.indexOf("=")), z.slice(z.indexOf("=") + 1).trim()]));
  if (felder.error !== "0" || !felder.name) return null;
  return { name: felder.name, marke: felder.vendor || null };
}

async function nameNachschlagen(code, env) {
  if (!env.OPENGTINDB_ID) return Response.json({ fehler: "nicht eingerichtet" }, { status: 503 });
  const r = await fetch(`https://opengtindb.org/?ean=${code}&cmd=query&queryid=${env.OPENGTINDB_ID}`);
  const text = new TextDecoder("iso-8859-1").decode(await r.arrayBuffer());
  const treffer = opengtindbParsen(text);
  return treffer ? Response.json(treffer) : Response.json({ name: null }, { status: 404 });
}

export async function handleEssen(url, env) {
  const teile = url.pathname.split("/").filter(Boolean); // ["essen", art, wert?]
  const art = teile[1];
  if (art === "barcode") {
    const code = normalisiere(teile[2]);
    const zeile = await env.ESSEN.prepare("SELECT * FROM produkt WHERE code = ?").bind(code).first();
    return Response.json({ produkt: produkt(zeile) }, { status: zeile ? 200 : 404, headers: { "Cache-Control": "private, max-age=86400" } });
  }
  if (art === "suche") {
    const anfrage = ftsAnfrage(url.searchParams.get("q"));
    const n = Math.min(Math.max(parseInt(url.searchParams.get("n") ?? "30", 10) || 30, 1), 50);
    if (!anfrage) return Response.json({ treffer: [] });
    const { results } = await env.ESSEN.prepare(
      `SELECT p.* FROM produkt_fts f JOIN produkt p ON p.rowid = f.rowid
       WHERE produkt_fts MATCH ? ORDER BY bm25(produkt_fts) - p.beliebtheit * 0.01 LIMIT ?`).bind(anfrage, n).all();
    return Response.json({ treffer: results.map(produkt) });
  }
  if (art === "name") return nameNachschlagen(normalisiere(teile[2]), env);
  return new Response("not found", { status: 404 });
}
```

`server/index.js`, nach `if (url.pathname === "/gif") …`:

```js
  if (url.pathname.startsWith("/essen/")) return handleEssen(url, env);
```

und oben `import { handleEssen } from "./essen.js";`.

- [ ] **Step 6: Tests laufen lassen**

Run: `cd server && node --test`
Expected: alle Tests PASS (auch die bisherigen).

- [ ] **Step 7: Schema auf D1 anwenden und committen**

Run: `cd server && npx wrangler d1 execute lovea-essen-test --remote --file essen-schema.sql && npx wrangler d1 execute lovea-essen-live --remote --file essen-schema.sql`
Expected: "Executed … commands".

```bash
git add server/essen.js server/essen.test.js server/essen-schema.sql server/fake-d1.js server/index.js
git commit -m "feat(server): /essen Barcode, Suche und Name aus D1"
```

---

### Task 5: Produkt-Import und Nacht-Job

**Files:**
- Create: `tools/essen-import/importieren.py`, `tools/essen-import/test_importieren.py`
- Create: `.github/workflows/essen-nacht.yml`

**Interfaces:**
- Consumes: Tabelle `produkt` (Task 4), Messergebnis (Task 1).
- Produces: `python importieren.py voll <csv.gz|url> --db lovea-essen-test` und `python importieren.py delta --db <name>`; schreibt SQL-Stapel mit höchstens 500 Zeilen nach `tools/essen-import/out/` und führt sie mit `npx wrangler d1 execute <db> --remote --file` aus.

- [ ] **Step 1: Test für die Zeilen-Umwandlung**

`tools/essen-import/test_importieren.py`:

```python
from importieren import zeile_zu_produkt, sql_stapel

def test_zeile():
    z = {"code": "012345678905", "product_name": "Peanut Butter", "brands": "A, B", "countries_tags": "en:germany",
         "energy-kcal_100g": "590", "proteins_100g": "25", "carbohydrates_100g": "20", "fat_100g": "50",
         "serving_quantity": "32", "serving_size": "2 EL (32 g)", "unique_scans_n": "7", "quantity": "350 g"}
    p = zeile_zu_produkt(z)
    assert p["code"] == "0012345678905" and p["marke"] == "A" and p["beliebtheit"] == 7
    assert p["pro100"]["kcal"] == 590 and p["portion_g"] == 32

def test_filter():
    assert zeile_zu_produkt({"code": "1", "product_name": "X", "countries_tags": "en:france", "energy-kcal_100g": "1"}) is None
    assert zeile_zu_produkt({"code": "1", "product_name": "", "countries_tags": "en:germany", "energy-kcal_100g": "1"}) is None

def test_kj_statt_kcal():
    p = zeile_zu_produkt({"code": "40000", "product_name": "Y", "countries_tags": "en:austria", "energy_100g": "418.4"})
    assert round(p["pro100"]["kcal"]) == 100

def test_sql_escape():
    s = sql_stapel([{"code": "1", "name": "Mama's", "marke": None, "menge": None, "portion_g": None,
                     "portion_name": None, "pro100": {"kcal": 1}, "beliebtheit": 0}])
    assert "Mama''s" in s and "ON CONFLICT(code) DO UPDATE" in s and "OR REPLACE" not in s
    viele = [{"code": str(i), "name": "n", "marke": None, "menge": None, "portion_g": None,
              "portion_name": None, "pro100": {"kcal": 1}, "beliebtheit": 0} for i in range(120)]
    assert sql_stapel(viele).count("INSERT INTO produkt") == 3

if __name__ == "__main__":
    test_zeile(); test_filter(); test_kj_statt_kcal(); test_sql_escape(); print("ok")
```

- [ ] **Step 2: Test laufen lassen**

Run: `cd tools/essen-import && python test_importieren.py`
Expected: FAIL, `No module named 'importieren'`.

- [ ] **Step 3: Implementierung**

`tools/essen-import/importieren.py`:

```python
"""Open Food Facts (DACH) -> D1-Tabelle produkt.
  voll:  python importieren.py voll [csv.gz-pfad-oder-url] --db lovea-essen-test
  delta: python importieren.py delta --db lovea-essen-live   (Delta-Dateien der letzten 2 Tage)"""
import argparse, csv, gzip, io, json, subprocess, sys, urllib.request
from pathlib import Path

CSV_URL = "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
DELTA = "https://static.openfoodfacts.org/data/delta/"
LAENDER = {"en:germany", "en:austria", "en:switzerland"}
OUT = Path(__file__).with_name("out")
AGENT = {"User-Agent": "Lovea-Import/1.0 (privat)"}
NAEHR = {"protein": "proteins_100g", "kohlenhydrate": "carbohydrates_100g", "fett": "fat_100g",
         "zucker": "sugars_100g", "ballaststoffe": "fiber_100g", "salz": "salt_100g", "gesFett": "saturated-fat_100g"}

def zahl(x):
    try:
        v = float(str(x).replace(",", "."))
        return v if v >= 0 else None
    except (TypeError, ValueError):
        return None

def normalisiere(code):
    z = "".join(c for c in str(code or "") if c.isdigit())
    return "0" + z if len(z) == 12 else z

def zeile_zu_produkt(z):
    laender = z.get("countries_tags") or ""
    laender = set(laender if isinstance(laender, list) else laender.split(","))
    name = (z.get("product_name_de") or z.get("product_name") or "").strip()
    kj = zahl(z.get("energy-kj_100g")) or zahl(z.get("energy_100g"))
    kcal = zahl(z.get("energy-kcal_100g")) or (kj / 4.184 if kj else None)
    code = normalisiere(z.get("code"))
    if not (LAENDER & laender) or not name or kcal is None or not code:
        return None
    pro100 = {"kcal": round(kcal, 1)}
    for feld, spalte in NAEHR.items():
        v = zahl(z.get(spalte))
        if v is not None:
            pro100[feld] = round(v, 2)
    for f in ("protein", "kohlenhydrate", "fett"):
        pro100.setdefault(f, 0)
    marken = z.get("brands") or ""
    marke = (marken[0] if isinstance(marken, list) and marken else str(marken).split(",")[0]).strip() or None
    return {"code": code, "name": name[:200], "marke": marke, "menge": (z.get("quantity") or None),
            "portion_g": zahl(z.get("serving_quantity")) or None, "portion_name": (z.get("serving_size") or None),
            "pro100": pro100, "beliebtheit": int(zahl(z.get("unique_scans_n")) or 0)}

def q(v):
    if v is None:
        return "NULL"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"

# ON CONFLICT statt INSERT OR REPLACE: REPLACE loescht ohne AFTER-DELETE-Trigger, der FTS-Index bekaeme Leichen.
# 50 Zeilen pro Anweisung (D1-Grenze fuer die Laenge einer Anweisung), viele Anweisungen pro Datei.
def sql_stapel(produkte, pro_anweisung=50):
    teile = []
    for i in range(0, len(produkte), pro_anweisung):
        werte = ",\n".join("(" + ",".join([q(p["code"]), q(p["name"]), q(p["marke"]), q(p["menge"]), q(p["portion_g"]),
                                            q(p["portion_name"]), q(json.dumps(p["pro100"], separators=(",", ":"))),
                                            q(p["beliebtheit"])]) + ")" for p in produkte[i:i + pro_anweisung])
        teile.append("INSERT INTO produkt (code,name,marke,menge,portion_g,portion_name,pro100,beliebtheit) VALUES\n"
                     + werte + "\nON CONFLICT(code) DO UPDATE SET name=excluded.name, marke=excluded.marke, menge=excluded.menge,"
                     " portion_g=excluded.portion_g, portion_name=excluded.portion_name, pro100=excluded.pro100,"
                     " beliebtheit=excluded.beliebtheit;\n")
    return "".join(teile)

def hochladen(db, produkte):
    OUT.mkdir(exist_ok=True)
    for i in range(0, len(produkte), 20000):
        datei = OUT / f"stapel-{i // 20000:05d}.sql"
        datei.write_text(sql_stapel(produkte[i:i + 20000]), "utf-8")
        subprocess.run(["npx", "wrangler", "d1", "execute", db, "--remote", "--file", str(datei), "--yes"],
                       cwd=Path(__file__).resolve().parents[2] / "server", check=True, shell=sys.platform == "win32")
        datei.unlink()

def csv_zeilen(quelle):
    roh = urllib.request.urlopen(urllib.request.Request(quelle, headers=AGENT)) if quelle.startswith("http") else open(quelle, "rb")
    csv.field_size_limit(2**31 - 1)  # sys.maxsize laeuft unter Windows ueber
    return csv.DictReader(io.TextIOWrapper(gzip.GzipFile(fileobj=roh), encoding="utf-8"), delimiter="\t")

def voll(quelle, db):
    puffer, gesamt = [], 0
    for z in csv_zeilen(quelle):
        p = zeile_zu_produkt(z)
        if p:
            puffer.append(p)
        if len(puffer) >= 20000:
            hochladen(db, puffer); gesamt += len(puffer); puffer = []; print(gesamt, flush=True)
    hochladen(db, puffer); print("fertig", gesamt + len(puffer))

def delta(db):
    index = urllib.request.urlopen(urllib.request.Request(DELTA + "index.txt", headers=AGENT)).read().decode().split()
    produkte = []
    for datei in index[-2:]:
        roh = urllib.request.urlopen(urllib.request.Request(DELTA + datei, headers=AGENT))
        for zeile in io.TextIOWrapper(gzip.GzipFile(fileobj=roh), encoding="utf-8"):
            p = zeile_zu_produkt(json.loads(zeile))
            if p:
                produkte.append(p)
    hochladen(db, produkte); print("delta", len(produkte))

if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("modus", choices=["voll", "delta"])
    a.add_argument("quelle", nargs="?", default=CSV_URL)
    a.add_argument("--db", required=True)
    args = a.parse_args()
    voll(args.quelle, args.db) if args.modus == "voll" else delta(args.db)
```

Hinweis: In den Delta-JSONL-Dateien ist `nutriments` ein Unterobjekt. `zeile_zu_produkt` liest dort die Nährwerte, wenn man es vorher flach macht. Deshalb in `delta` vor dem Aufruf: `j = json.loads(zeile); j.update(j.get("nutriments") or {})`. Den Test `test_kj_statt_kcal` dafür um eine JSON-Variante ergänzen:

```python
def test_delta_json():
    j = {"code": "4311501679715", "product_name": "Skyr", "countries_tags": ["en:germany"], "brands": "Gut & Günstig",
         "nutriments": {"energy-kcal_100g": 65, "proteins_100g": 11}}
    j.update(j["nutriments"])
    assert zeile_zu_produkt(j)["pro100"]["protein"] == 11
```

- [ ] **Step 4: Tests laufen lassen**

Run: `cd tools/essen-import && python test_importieren.py`
Expected: `ok`.

- [ ] **Step 5: Erstbefüllung test und live**

Run (im Hintergrund, dauert lange): `python tools/essen-import/importieren.py voll --db lovea-essen-test`
Danach Stichprobe: `cd server && npx wrangler d1 execute lovea-essen-test --remote --command "SELECT count(*), (SELECT name FROM produkt WHERE code='4311501679715') FROM produkt"`
Expected: Anzahl ungefähr wie in Task 1 gemessen, Name "Skyr Natur" (oder ähnlich).
Dann dasselbe mit `--db lovea-essen-live`.

- [ ] **Step 6: Nacht-Job**

`.github/workflows/essen-nacht.yml`:

```yaml
name: Essen Nacht-Import

on:
  schedule:
    - cron: "30 2 * * *"
  workflow_dispatch:

jobs:
  delta:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Wrangler
        run: cd server && npm ci
      - name: Delta live
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        run: python tools/essen-import/importieren.py delta --db lovea-essen-live
      - name: Delta test
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        run: python tools/essen-import/importieren.py delta --db lovea-essen-test
```

Ahmed muss einmal zwei Repo-Secrets setzen. Im Bericht genau sagen: Cloudflare-Dashboard, My Profile, API Tokens, Token mit Recht "D1 Edit" anlegen; dann
`gh secret set CLOUDFLARE_API_TOKEN -R Tobito320/lovea-app-ios` und `gh secret set CLOUDFLARE_ACCOUNT_ID -R Tobito320/lovea-app-ios` (Account-ID aus `npx wrangler whoami`).
Akku: kostet am Handy nichts, läuft auf GitHub (Linux-Minuten, rund 3 Minuten pro Nacht).

- [ ] **Step 7: Commit**

```bash
git add tools/essen-import .github/workflows/essen-nacht.yml
git commit -m "feat(essen): Open-Food-Facts-Import DACH und Nacht-Job"
```

---

### Task 6: Barcode-Kette in der App

**Files:**
- Create: `Lovea/Sources/Health/Ernaehrung/BarcodeKette.swift`, `Lovea/Sources/Health/Ernaehrung/EssenServer.swift`
- Modify: `Lovea/Sources/Health/Ernaehrung/ErnaehrungModell.swift` (OFFClient: Wiederholung, 429)
- Test: `Lovea/Tests/BarcodeLogikTests.swift`

**Interfaces:**
- Consumes: `/essen/barcode`, `/essen/suche`, `/essen/name` (Task 4), `LebensmittelIndex.shared.suchen` (Task 3), `ErnaehrungModell.offline(barcode:)`.
- Produces:
  - `enum BarcodeLogik { static func normal(_ roh: String) -> String }` (gleiche Regel wie `normalisiere` im Server).
  - `enum BarcodeErgebnis: Equatable { case gefunden(Lebensmittel); case vorschlaege(name: String, [Lebensmittel]); case unbekannt(String); case offline(String) }`
  - `struct BarcodeQuellen: Sendable` mit Closures `lokal`, `server`, `offLive`, `name`, `namensSuche` (für Tests austauschbar); `static var echt: BarcodeQuellen`.
  - `enum BarcodeKette { static func suchen(_ roh: String, _ q: BarcodeQuellen) async -> BarcodeErgebnis }`
  - `enum EssenServer { static func barcode(_ code: String) async throws -> Lebensmittel?; static func suchen(_ text: String) async throws -> [Lebensmittel]; static func name(_ code: String) async throws -> (name: String, marke: String?)? }`
  - `enum EssenServer.Fehler: Error { case nichtEingerichtet, netz }`
  - Gemerkte Barcodes: `ErnaehrungModell.offeneBarcodes: [String]` (UserDefaults-Schlüssel `essen.offeneBarcodes`), `merken(_:)`, `nachholen() async -> [Lebensmittel]`.

- [ ] **Step 1: Tests**

```swift
import XCTest
@testable import Lovea

final class BarcodeLogikTests: XCTestCase {
    private let skyr = Lebensmittel(id: "off-4311501679715", name: "Skyr", barcode: "4311501679715",
                                    pro100: Naehrwerte(kcal: 65, protein: 11, kohlenhydrate: 4, fett: 0.2))

    func testNormal() {
        XCTAssertEqual(BarcodeLogik.normal(" 4311501679715\n"), "4311501679715")
        XCTAssertEqual(BarcodeLogik.normal("012345678905"), "0012345678905")
        XCTAssertEqual(BarcodeLogik.normal("20123456"), "20123456")
    }

    private func quellen(lokal: Lebensmittel? = nil, server: Result<Lebensmittel?, Error> = .success(nil),
                         off: Result<Lebensmittel?, Error> = .success(nil), name: (String, String?)? = nil,
                         aufrufe: Protokoll = Protokoll()) -> BarcodeQuellen {
        BarcodeQuellen(
            lokal: { _ in aufrufe.add("lokal"); return lokal },
            server: { _ in aufrufe.add("server"); return try server.get() },
            offLive: { _ in aufrufe.add("off"); return try off.get() },
            name: { _ in aufrufe.add("name"); return name.map { (name: $0.0, marke: $0.1) } },
            namensSuche: { text in aufrufe.add("suche:\(text)"); return [self.skyr] })
    }

    func testReihenfolgeUndStopp() async {
        let p = Protokoll()
        let r = await BarcodeKette.suchen("4311501679715", quellen(server: .success(skyr), aufrufe: p))
        XCTAssertEqual(r, .gefunden(skyr))
        XCTAssertEqual(p.liste, ["lokal", "server"])
    }

    func testServerAusDannOFF() async {
        let p = Protokoll()
        let r = await BarcodeKette.suchen("4311501679715", quellen(server: .failure(EssenServer.Fehler.netz), off: .success(skyr), aufrufe: p))
        XCTAssertEqual(r, .gefunden(skyr))
        XCTAssertEqual(p.liste, ["lokal", "server", "off"])
    }

    func testNameGibtVorschlaege() async {
        let r = await BarcodeKette.suchen("4311501679715", quellen(name: ("Skyr Natur", "Gut & Günstig")))
        XCTAssertEqual(r, .vorschlaege(name: "Skyr Natur", [skyr]))
    }

    func testNichtsGefunden() async {
        XCTAssertEqual(await BarcodeKette.suchen("4311501679715", quellen()), .unbekannt("4311501679715"))
    }

    func testAllesOffline() async {
        let r = await BarcodeKette.suchen("4311501679715", quellen(server: .failure(URLError(.notConnectedToInternet)),
                                                                   off: .failure(URLError(.notConnectedToInternet))))
        XCTAssertEqual(r, .offline("4311501679715"))
    }
}

final class Protokoll: @unchecked Sendable {
    private let sperre = NSLock()
    private(set) var liste: [String] = []
    func add(_ s: String) { sperre.withLock { liste.append(s) } }
}
```

- [ ] **Step 2: CI rot erwartet (Typen fehlen). Weiter.**

- [ ] **Step 3: Implementierung**

`EssenServer.swift` (Muster wie `KlipyClient`):

```swift
import Foundation

/// Eigene Produkt-Datenbank auf dem Lovea-Server (`server/essen.js`).
enum EssenServer {
    enum Fehler: Error { case nichtEingerichtet, netz }

    private struct Produkt: Decodable {
        let code: String
        let name: String
        let marke: String?
        let portion_g: Double?
        let portion_name: String?
        let pro100: Naehrwerte
    }
    private struct BarcodeAntwort: Decodable { let produkt: Produkt? }
    private struct SucheAntwort: Decodable { let treffer: [Produkt] }
    private struct NameAntwort: Decodable { let name: String?; let marke: String? }

    private static func lebensmittel(_ p: Produkt) -> Lebensmittel {
        Lebensmittel(id: "off-\(p.code)", name: p.name, marke: p.marke, barcode: p.code, pro100: p.pro100,
                     portionMenge: p.portion_g, portionName: p.portion_g == nil ? nil : p.portion_name.flatMap(ErnaehrungLogik.portionsName))
    }

    private static func laden(_ pfad: String, _ query: [URLQueryItem] = []) async throws -> (Data, Int) {
        guard let konfig = await Raum.shared.httpKonfiguration() else { throw Fehler.nichtEingerichtet }
        var comps = URLComponents(url: konfig.basis.appendingPathComponent(pfad), resolvingAgainstBaseURL: false)
        if !query.isEmpty { comps?.queryItems = query }
        guard let url = comps?.url else { throw Fehler.netz }
        var anfrage = URLRequest(url: url)
        anfrage.timeoutInterval = 6
        for (feld, wert) in konfig.headers { anfrage.setValue(wert, forHTTPHeaderField: feld) }
        let (data, antwort) = try await URLSession.shared.data(for: anfrage)
        return (data, (antwort as? HTTPURLResponse)?.statusCode ?? 0)
    }

    static func barcode(_ code: String) async throws -> Lebensmittel? {
        let (data, status) = try await laden("essen/barcode/\(code)")
        if status == 404 { return nil }
        guard (200..<300).contains(status) else { throw Fehler.netz }
        return try JSONDecoder().decode(BarcodeAntwort.self, from: data).produkt.map(lebensmittel)
    }

    static func suchen(_ text: String) async throws -> [Lebensmittel] {
        let (data, status) = try await laden("essen/suche", [URLQueryItem(name: "q", value: text), URLQueryItem(name: "n", value: "30")])
        guard (200..<300).contains(status) else { throw Fehler.netz }
        return try JSONDecoder().decode(SucheAntwort.self, from: data).treffer.map(lebensmittel)
    }

    static func name(_ code: String) async throws -> (name: String, marke: String?)? {
        let (data, status) = try await laden("essen/name/\(code)")
        guard (200..<300).contains(status), let a = try? JSONDecoder().decode(NameAntwort.self, from: data), let n = a.name else { return nil }
        return (n, a.marke)
    }
}
```

Vor dem Commit prüfen: `Naehrwerte` ist `Codable` mit Standardwerten, aber `Decodable` braucht alle nicht-optionalen Schlüssel (`kcal`, `protein`, `kohlenhydrate`, `fett`). Der Server liefert sie immer (Task 5 setzt 0). Passt.

`BarcodeKette.swift`:

```swift
import Foundation

enum BarcodeLogik {
    /// Nur Ziffern; UPC-A (12) bekommt eine führende 0. Gleiche Regel wie `normalisiere` in `server/essen.js`.
    static func normal(_ roh: String) -> String {
        let z = roh.filter(\.isNumber)
        return z.count == 12 ? "0" + z : z
    }
}

enum BarcodeErgebnis: Equatable {
    case gefunden(Lebensmittel)
    case vorschlaege(name: String, [Lebensmittel])
    case unbekannt(String)
    case offline(String)
}

struct BarcodeQuellen: Sendable {
    var lokal: @Sendable (String) async -> Lebensmittel?
    var server: @Sendable (String) async throws -> Lebensmittel?
    var offLive: @Sendable (String) async throws -> Lebensmittel?
    var name: @Sendable (String) async throws -> (name: String, marke: String?)?
    var namensSuche: @Sendable (String) async -> [Lebensmittel]

    static var echt: BarcodeQuellen {
        BarcodeQuellen(
            lokal: { code in await MainActor.run { ErnaehrungModell.shared.offline(barcode: code) } },
            server: { try await EssenServer.barcode($0) },
            offLive: { try await OFFClient.produkt($0) },
            name: { try await EssenServer.name($0) },
            namensSuche: { text in
                let lokal = LebensmittelIndex.shared.suchen(text, vorne: [], anzahl: 3)
                let server = (try? await EssenServer.suchen(text)) ?? []
                return Array((server + lokal).prefix(5))
            })
    }
}

/// Lokal -> eigener Server -> Open Food Facts live -> Name (Open EAN Database) mit Vorschlägen.
enum BarcodeKette {
    static func suchen(_ roh: String, _ q: BarcodeQuellen) async -> BarcodeErgebnis {
        let code = BarcodeLogik.normal(roh)
        if let l = await q.lokal(code) { return .gefunden(l) }
        var netzFehler = 0
        do { if let l = try await q.server(code) { return .gefunden(l) } } catch { netzFehler += 1 }
        do { if let l = try await q.offLive(code) { return .gefunden(l) } } catch { netzFehler += 1 }
        if netzFehler == 2 { return .offline(code) }
        if let n = try? await q.name(code) {
            let text = [n.marke, n.name].compactMap { $0 }.joined(separator: " ")
            let vorschlaege = await q.namensSuche(text)
            if !vorschlaege.isEmpty { return .vorschlaege(name: n.name, vorschlaege) }
        }
        return .unbekannt(code)
    }
}
```

`OFFClient.produkt` in `ErnaehrungModell.swift`: `timeoutInterval` auf 8 s; bei Status 429 oder 5xx einmal nach 1 s wiederholen, danach `throw Fehler.netz`. Den Kommentar über dem `enum OFFClient` anpassen ("Fallback hinter dem eigenen Server").

```swift
    static func produkt(_ barcode: String) async throws -> Lebensmittel? {
        let ziffern = BarcodeLogik.normal(barcode)
        guard !ziffern.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(ziffern).json?fields=\(ErnaehrungLogik.offFelder)")
        else { return nil }
        for versuch in 0..<2 {
            let (data, status) = try await laden(url)
            if status == 404 { return nil }
            if (200..<300).contains(status) { return ErnaehrungLogik.offProdukt(data) }
            if versuch == 0, status == 429 || status >= 500 { try await Task.sleep(for: .seconds(1)); continue }
            throw Fehler.netz
        }
        throw Fehler.netz
    }
```

Gemerkte Barcodes in `ErnaehrungModell`:

```swift
    // MARK: - Offene Barcodes (offline gescannt, laufen beim nächsten Öffnen der Ernährung nach, nie im Hintergrund)

    private static let offeneSchluessel = "essen.offeneBarcodes"
    var offeneBarcodes: [String] { UserDefaults.standard.stringArray(forKey: Self.offeneSchluessel) ?? [] }
    func merken(_ code: String) {
        UserDefaults.standard.set(Array(Set(offeneBarcodes + [code])), forKey: Self.offeneSchluessel)
    }
    /// Gefundene Produkte zurück; die Barcodes verschwinden aus der Liste, sobald die Kette etwas anderes als `.offline` liefert.
    func nachholen() async -> [Lebensmittel] {
        var gefunden: [Lebensmittel] = []
        var bleiben: [String] = []
        for code in offeneBarcodes {
            switch await BarcodeKette.suchen(code, .echt) {
            case .gefunden(let l): gefunden.append(l)
            case .offline: bleiben.append(code)
            default: break
            }
        }
        UserDefaults.standard.set(bleiben, forKey: Self.offeneSchluessel)
        return gefunden
    }
```

- [ ] **Step 4: Commit**

```bash
git add Lovea/Sources/Health/Ernaehrung/BarcodeKette.swift Lovea/Sources/Health/Ernaehrung/EssenServer.swift Lovea/Sources/Health/Ernaehrung/ErnaehrungModell.swift Lovea/Tests/BarcodeLogikTests.swift
git commit -m "feat(essen): Barcode-Kette lokal, Server, OFF, Name mit Vorschlaegen"
```

---

### Task 7: Nährwert-Tabelle fotografieren

**Files:**
- Create: `Lovea/Sources/Health/Ernaehrung/NaehrwertFoto.swift`
- Test: `Lovea/Tests/NaehrwertFotoTests.swift`

**Interfaces:**
- Produces:
  - `enum NaehrwertLeser { static func parsen(_ zeilen: [String]) -> Naehrwerte? }` (reine Funktion, nil wenn weder kcal noch kJ erkannt)
  - `enum NaehrwertLeser { static func erkennen(_ bild: CGImage) async -> [String] }` (Vision `VNRecognizeTextRequest`, `recognitionLanguages = ["de-DE"]`, `.accurate`)
  - `struct NaehrwertFotoBlatt: View` mit `init(barcode: String, fertig: @escaping (Lebensmittel) -> Void)`: Kamera-Aufnahme (`UIImagePickerController` mit `.camera`, wie es im Projekt schon verwendet wird, greppen: `grep -rn "UIImagePickerController" Lovea/Sources`), dann Formular mit erkannten Werten (Name leer, Werte editierbar), Knopf "Speichern" legt über `ErnaehrungModell.shared.eigenesSichern` ein Lebensmittel `eigen-<uuid>` mit `barcode` an und ruft `fertig`.

- [ ] **Step 1: Tests mit echten Tabellen-Texten**

```swift
import XCTest
@testable import Lovea

final class NaehrwertFotoTests: XCTestCase {
    func testTypischeTabelle() {
        let z = ["Nährwerte pro 100 g", "Energie 1570 kJ / 375 kcal", "Fett 17 g", "davon gesättigte Fettsäuren 2,1 g",
                 "Kohlenhydrate 45 g", "davon Zucker 22 g", "Ballaststoffe 6,0 g", "Eiweiß 8,5 g", "Salz 0,45 g"]
        let n = NaehrwertLeser.parsen(z)
        XCTAssertEqual(n?.kcal, 375)
        XCTAssertEqual(n?.fett, 17)
        XCTAssertEqual(n?.gesFett, 2.1)
        XCTAssertEqual(n?.kohlenhydrate, 45)
        XCTAssertEqual(n?.zucker, 22)
        XCTAssertEqual(n?.protein, 8.5)
        XCTAssertEqual(n?.salz, 0.45)
    }

    func testNurKJ() {
        XCTAssertEqual(NaehrwertLeser.parsen(["Brennwert 418 kJ", "Eiweiß 3 g"])?.kcal ?? 0, 99.9, accuracy: 0.2)
    }

    func testZahlInNaechsterZeile() {
        let n = NaehrwertLeser.parsen(["Energie", "65 kcal", "Eiweiß", "11 g", "Fett", "0,2 g", "Kohlenhydrate", "4,4 g"])
        XCTAssertEqual(n?.kcal, 65)
        XCTAssertEqual(n?.protein, 11)
    }

    func testProPortionSpalteIgnoriert() {
        let n = NaehrwertLeser.parsen(["Energie 250 kcal 500 kcal", "Fett 10 g 20 g"])
        XCTAssertEqual(n?.kcal, 250)
        XCTAssertEqual(n?.fett, 10)
    }

    func testKeineZahlen() {
        XCTAssertNil(NaehrwertLeser.parsen(["Zutaten: Milch, Salz"]))
    }
}
```

- [ ] **Step 2: Implementierung Parser**

```swift
import SwiftUI
import Vision

/// Liest eine Nährwert-Tabelle vom Foto (Vision auf dem Gerät, kein KI-Dienst). Erste Zahl je Zeile = pro 100 g.
enum NaehrwertLeser {
    static func parsen(_ zeilen: [String]) -> Naehrwerte? {
        func zahl(_ s: Substring) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }
        func ersteZahl(_ s: String, vor einheit: String? = nil) -> Double? {
            let re = einheit.map { "([0-9]+(?:[.,][0-9]+)?)\\s*\($0)" } ?? "([0-9]+(?:[.,][0-9]+)?)"
            guard let r = s.range(of: re, options: [.regularExpression, .caseInsensitive]) else { return nil }
            let treffer = s[r]
            guard let zr = treffer.range(of: "[0-9]+(?:[.,][0-9]+)?", options: .regularExpression) else { return nil }
            return zahl(treffer[zr])
        }
        let klein = zeilen.map { $0.lowercased() }
        func wert(_ woerter: [String], ohne: [String] = []) -> Double? {
            for (i, z) in klein.enumerated() where woerter.contains(where: z.contains) && !ohne.contains(where: z.contains) {
                if let x = ersteZahl(z, vor: "g") ?? ersteZahl(z) { return x }
                if i + 1 < klein.count, let x = ersteZahl(klein[i + 1]) { return x }
            }
            return nil
        }
        var kcal: Double?
        for (i, z) in klein.enumerated() {
            if let x = ersteZahl(z, vor: "kcal") { kcal = x; break }
            if i + 1 < klein.count, z.contains("energie") || z.contains("brennwert"), let x = ersteZahl(klein[i + 1], vor: "kcal") { kcal = x; break }
        }
        if kcal == nil, let kj = klein.lazy.compactMap({ ersteZahl($0, vor: "kj") }).first { kcal = kj / 4.184 }
        guard let kcal else { return nil }
        return Naehrwerte(kcal: kcal,
                          protein: wert(["eiweiß", "eiweiss", "protein"]) ?? 0,
                          kohlenhydrate: wert(["kohlenhydrat"]) ?? 0,
                          fett: wert(["fett"], ohne: ["gesättigt", "gesaettigt", "fettsäuren"]) ?? 0,
                          zucker: wert(["zucker"]),
                          ballaststoffe: wert(["ballaststoff"]),
                          salz: wert(["salz"]),
                          gesFett: wert(["gesättigt", "gesaettigt"]))
    }

    static func erkennen(_ bild: CGImage) async -> [String] {
        await withCheckedContinuation { fortsetzung in
            let anfrage = VNRecognizeTextRequest { req, _ in
                let zeilen = (req.results as? [VNRecognizedTextObservation] ?? []).compactMap { $0.topCandidates(1).first?.string }
                fortsetzung.resume(returning: zeilen)
            }
            anfrage.recognitionLevel = .accurate
            anfrage.recognitionLanguages = ["de-DE"]
            anfrage.usesLanguageCorrection = false
            do { try VNImageRequestHandler(cgImage: bild).perform([anfrage]) } catch { fortsetzung.resume(returning: []) }
        }
    }
}
```

Vision-Zeilen kommen von oben nach unten; bei zweispaltigen Tabellen liefert Vision oft "Fett 10 g 20 g" in einer Zeile, deshalb erste Zahl.

- [ ] **Step 3: Blatt**

`NaehrwertFotoBlatt` im selben File: Zustand `bild: UIImage?`, `werte: Naehrwerte?`, `name: String`, `fehler: Bool`. Ablauf: beim Erscheinen Kamera-Picker; nach der Aufnahme `Task { let z = await NaehrwertLeser.erkennen(cg); werte = NaehrwertLeser.parsen(z); fehler = werte == nil }`. Formular: Name (TextField, Pflicht), kcal, Eiweiß, Kohlenhydrate, Fett, Zucker, Salz als Zahlenfelder mit `ErnaehrungLogik.eingabe`. Hinweis bei `fehler`: "Bitte näher und gerade fotografieren" plus Knopf "Nochmal". Speichern:

```swift
let l = Lebensmittel(id: "eigen-\(UUID().uuidString)", name: name.trimmingCharacters(in: .whitespaces), barcode: barcode, pro100: w)
ErnaehrungModell.shared.eigenesSichern(l)
fertig(l)
```

Kamera läuft nur, solange das Blatt offen ist (Akku).

- [ ] **Step 4: Commit**

```bash
git add Lovea/Sources/Health/Ernaehrung/NaehrwertFoto.swift Lovea/Tests/NaehrwertFotoTests.swift
git commit -m "feat(essen): Naehrwert-Tabelle fotografieren und lesen"
```

---

### Task 8: Produktbilder entfernen

**Files:**
- Modify: `Lovea/Sources/Health/Ernaehrung/Ernaehrung.swift` (`bildKlein`, `bildGross`, `offBildPasst`, `ohneFuehrendeNullen`, `image_front_small_url` in `offFelder`, `bild:` in `lebensmittel(offProdukt:)`)
- Modify: `Lovea/Sources/Health/Ernaehrung/ErnaehrungHinzufuegen.swift:233`, `ErnaehrungMahlzeit.swift:185, 219-256` (`LebensmittelBild`), `LebensmittelDetail.swift:122-125`
- Modify: `Lovea/Tests/ErnaehrungTests.swift` (Tests zu `offBildPasst` löschen)

**Interfaces:**
- Produces: `Lebensmittel.bild` bleibt als Feld (alte gespeicherte Einträge dekodieren weiter), wird aber nirgends mehr gelesen oder gesetzt.

- [ ] **Step 1: Alle Stellen finden**

Run: `grep -rn "bildKlein\|bildGross\|offBildPasst\|LebensmittelBild\|image_front" Lovea/`
Expected: die oben genannten Stellen plus Tests.

- [ ] **Step 2: Löschen**

Jede Stelle entfernen. In `lebensmittel(offProdukt:)` den Parameter `bild: p["image_front_small_url"] as? String` streichen. In `offFelder` `,image_front_small_url` streichen. In `ErnaehrungMahlzeit.swift` die Zeile mit dem Bild so umbauen, dass der Text links bündig bleibt (kein leerer Platzhalter). `struct LebensmittelBild` löschen.

- [ ] **Step 3: Prüfen**

Run: `grep -rn "bildKlein\|bildGross\|offBildPasst\|LebensmittelBild\|image_front" Lovea/`
Expected: keine Ausgabe.

- [ ] **Step 4: Commit**

```bash
git add -A Lovea/Sources/Health/Ernaehrung Lovea/Tests/ErnaehrungTests.swift
git commit -m "refactor(essen): Produktbilder raus"
```

---

### Task 9: Mahlzeiten und Rezepte für beide

Abweichung von der Spec, bewusst: Wer etwas angelegt hat, kommt nicht aus einem neuen Feld `von`, sondern aus `op.von` der ersten Op dieser ID in der Faltung. So stimmt es auch für alle alten Einträge. Ahmed hat das Ergebnis bestätigt ("Von Annika"), der Weg ist ein Detail.

**Files:**
- Modify: `Lovea/Sources/Health/Ernaehrung/Ernaehrung.swift` (`Rezept`, `ErnaehrungFaltung`)
- Modify: `Lovea/Sources/Health/Ernaehrung/ErnaehrungModell.swift` (Lesen und Kopieren)
- Test: `Lovea/Tests/ErnaehrungTeilenTests.swift`

**Interfaces:**
- Produces:
  - `enum RezeptArt: String, Codable, Sendable { case mahlzeit, rezept }`
  - `Rezept.art: RezeptArt?` (nil = `.rezept`), `Rezept.anleitung: String?`, `var istMahlzeit: Bool { art == .mahlzeit }`
  - `ErnaehrungFaltung.ersteller(lebensmittel id: String) -> Person?`, `ersteller(rezept id: String) -> Person?`
  - `ErnaehrungModell.eigene(von: Person) -> [Lebensmittel]`, `rezepte(von: Person, art: RezeptArt?) -> [Rezept]`, `kopieren(_ r: Rezept)`, `kopieren(_ l: Lebensmittel)`
  - Favorit auf ein Rezept = Favorit auf `ErnaehrungLogik.alsLebensmittel(r)` (ID `rezept-<id>`), das Tagebuch liest bei Rezept-Favoriten die aktuelle Fassung über `rezeptAktuell(id:)`.
  - `ErnaehrungModell.rezeptAktuell(_ lebensmittelId: String) -> Lebensmittel?` (für `rezept-…`-IDs die neueste Fassung aus `rezepte`, sonst nil)

- [ ] **Step 1: Tests**

```swift
import XCTest
@testable import Lovea

final class ErnaehrungTeilenTests: XCTestCase {
    private func op(_ art: String, _ von: Person, _ wert: some Encodable, _ sek: Double) -> Op {
        Op.test(art: art, von: von, zeit: Date(timeIntervalSince1970: sek), daten: wert)
    }
    private let quark = Lebensmittel(id: "eigen-q", name: "Quark", pro100: Naehrwerte(kcal: 67, protein: 12, kohlenhydrate: 4, fett: 0.3))

    func testErstellerBleibtBeimAendern() {
        var f = ErnaehrungFaltung()
        f.anwenden(op("rezept.setzen", .annika, Rezept(id: "r1", name: "Bowl", portionen: 1, zutaten: [], art: .mahlzeit), 1))
        f.anwenden(op("rezept.setzen", .ahmed, Rezept(id: "r1", name: "Bowl groß", portionen: 1, zutaten: [], art: .mahlzeit), 2))
        XCTAssertEqual(f.ersteller(rezept: "r1"), .annika)
        XCTAssertEqual(f.rezepte.first?.name, "Bowl groß")
        XCTAssertEqual(f.rezepte.first?.istMahlzeit, true)
    }

    func testAltesRezeptOhneArtIstRezept() throws {
        let json = #"{"id":"r2","name":"Suppe","portionen":2,"zutaten":[]}"#
        let r = try JSONDecoder().decode(Rezept.self, from: Data(json.utf8))
        XCTAssertFalse(r.istMahlzeit)
        XCTAssertNil(r.anleitung)
    }

    func testFavoritSiehtNeueFassungKopieNicht() {
        var f = ErnaehrungFaltung()
        let alt = Rezept(id: "r3", name: "Porridge", portionen: 1, zutaten: [Zutat(id: "z", lebensmittel: quark, menge: 100, einheit: .g)])
        f.anwenden(op("rezept.setzen", .annika, alt, 1))
        var kopie = alt; kopie.id = "r3-kopie"
        f.anwenden(op("rezept.setzen", .ahmed, kopie, 2))
        var neu = alt; neu.zutaten[0].menge = 200
        f.anwenden(op("rezept.setzen", .annika, neu, 3))
        XCTAssertEqual(f.rezepte.first { $0.id == "r3" }?.zutaten[0].menge, 200)
        XCTAssertEqual(f.rezepte.first { $0.id == "r3-kopie" }?.zutaten[0].menge, 100)
        XCTAssertEqual(f.ersteller(rezept: "r3-kopie"), .ahmed)
    }

    func testEigenesLebensmittelErsteller() {
        var f = ErnaehrungFaltung()
        f.anwenden(op("lebensmittel.setzen", .annika, LebensmittelD(lebensmittel: quark, geloescht: nil), 1))
        XCTAssertEqual(f.ersteller(lebensmittel: "eigen-q"), .annika)
    }
}
```

Vor dem Schreiben prüfen, wie Tests heute Ops bauen: `grep -rn "Op(" Lovea/Tests | head` und die `Op`-Definition in `Lovea/Sources/Sync/`. Gibt es kein `Op.test`, den Helfer im Test mit dem vorhandenen `Op`-Initialisierer schreiben (Daten als JSON kodiert, wie in `ErnaehrungTests.swift` bei den Faltungs-Tests).

- [ ] **Step 2: Implementierung**

`Rezept` erweitern (Standardwerte im memberwise init über explizite Parameter mit `= nil`):

```swift
enum RezeptArt: String, Codable, Sendable { case mahlzeit, rezept }

struct Rezept: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var portionen: Int
    var zutaten: [Zutat]
    var geloescht: Bool?
    /// nil = altes Rezept, zählt als `.rezept`.
    var art: RezeptArt?
    var anleitung: String?

    init(id: String, name: String, portionen: Int, zutaten: [Zutat], geloescht: Bool? = nil, art: RezeptArt? = nil, anleitung: String? = nil) {
        self.id = id; self.name = name; self.portionen = portionen; self.zutaten = zutaten
        self.geloescht = geloescht; self.art = art; self.anleitung = anleitung
    }

    var istMahlzeit: Bool { art == .mahlzeit }
}
```

Achtung: Ein eigener `init` entfernt den memberwise init. Alle Aufrufer greppen (`grep -rn "Rezept(" Lovea/`) und prüfen, dass sie mit den Labels oben weiter kompilieren (die Reihenfolge `id, name, portionen, zutaten, geloescht` bleibt gleich).

In `ErnaehrungFaltung` zwei Wörterbücher und die Pflege in `anwenden`:

```swift
    private var erstellerLebensmittel: [String: Person] = [:]
    private var erstellerRezept: [String: Person] = [:]
```

In `case "lebensmittel.setzen":` nach dem `guard`: `if erstellerLebensmittel[d.lebensmittel.id] == nil { erstellerLebensmittel[d.lebensmittel.id] = op.von }`. Analog in `case "rezept.setzen":` mit `r.id`. Achtung Reihenfolge: Ops kommen beim Nachladen nicht immer zeitlich sortiert. Deshalb zusätzlich die Zeit merken und den früheren gewinnen lassen:

```swift
    private var erstellerZeit: [String: Date] = [:]
    private mutating func ersteller(merken id: String, _ von: Person, _ zeit: Date, rezept: Bool) {
        guard zeit < (erstellerZeit[id] ?? .distantFuture) else { return }
        erstellerZeit[id] = zeit
        if rezept { erstellerRezept[id] = von } else { erstellerLebensmittel[id] = von }
    }
    func ersteller(lebensmittel id: String) -> Person? { erstellerLebensmittel[id] }
    func ersteller(rezept id: String) -> Person? { erstellerRezept[id] }
```

Den Aufruf `ersteller(merken:…)` vor den bestehenden `guard … <= op.zeit` setzen, damit auch ältere Ops den Ersteller festlegen können.

`ErnaehrungModell`:

```swift
    func ersteller(_ l: Lebensmittel) -> Person? { faltung.ersteller(lebensmittel: l.id) }
    func ersteller(_ r: Rezept) -> Person? { faltung.ersteller(rezept: r.id) }
    func eigene(von p: Person) -> [Lebensmittel] { eigene.filter { (ersteller($0) ?? p) == p } }
    func rezepte(von p: Person, art: RezeptArt?) -> [Rezept] {
        rezepte.filter { (ersteller($0) ?? p) == p && (art == nil || ($0.art ?? .rezept) == art) }
    }
    func kopieren(_ r: Rezept) {
        var neu = r
        neu.id = UUID().uuidString
        rezeptSichern(neu)
    }
    func kopieren(_ l: Lebensmittel) {
        var neu = l
        neu.id = "eigen-\(UUID().uuidString)"
        eigenesSichern(neu)
    }
    func rezeptAktuell(_ lebensmittelId: String) -> Lebensmittel? {
        guard lebensmittelId.hasPrefix("rezept-") else { return nil }
        let id = String(lebensmittelId.dropFirst("rezept-".count))
        return rezepte.first { $0.id == id }.map(ErnaehrungLogik.alsLebensmittel)
    }
```

In `favoriten(_:)`: Rezept-Favoriten durch `rezeptAktuell` ersetzen, gelöschte Rezepte fallen weg:

```swift
    func favoriten(_ p: Person) -> [Lebensmittel] {
        faltung.favoritenListe(p).compactMap { l in l.istRezept ? rezeptAktuell(l.id) : l }
    }
```

`RezeptEditor` (`ErnaehrungEigene.swift`): Parameter `art: RezeptArt = .rezept`; bei `.mahlzeit` keine Anleitung und Portionen fest 1, Titel "Neue Mahlzeit"; bei `.rezept` ein mehrzeiliges Feld "Anleitung (optional)". Speichern setzt `art` und `anleitung`.

- [ ] **Step 3: Commit**

```bash
git add Lovea/Sources/Health/Ernaehrung/Ernaehrung.swift Lovea/Sources/Health/Ernaehrung/ErnaehrungModell.swift Lovea/Sources/Health/Ernaehrung/ErnaehrungEigene.swift Lovea/Tests/ErnaehrungTeilenTests.swift
git commit -m "feat(essen): Mahlzeiten und Rezepte geteilt, Ersteller, Kopieren"
```

---

### Task 10: Hinzufügen-Seite und Such-Modus wie YAZIO

**Files:**
- Modify: `Lovea/Sources/Health/Ernaehrung/ErnaehrungHinzufuegen.swift` (Umbau `HinzufuegenBlatt`)
- Create: `Lovea/Sources/Health/Ernaehrung/HinzufuegenTeile.swift` (Kachel-Reihe, Filter-Knöpfe, Zeile, Karte, Erstellen-Blatt, "Kommt bald"-Blatt, Vorschläge-Blatt)
- Create: `Lovea/Sources/Health/Ernaehrung/SuchZusammenfuehrung.swift`
- Test: `Lovea/Tests/SuchZusammenfuehrungTests.swift`, `Lovea/Tests/RenderGalerieErnaehrungTests.swift` (neue Tafeln)

**Interfaces:**
- Consumes: `LebensmittelIndex.shared` (T3), `BarcodeKette`/`BarcodeErgebnis`/`EssenServer` (T6), `NaehrwertFotoBlatt` (T7), `ersteller`, `rezepte(von:art:)`, `kopieren` (T9), `LebensmittelDetailView` (T11 baut sie um, Signatur bleibt).
- Produces:
  - `struct SuchStand: Equatable { var nummer: Int; var lokal: [Lebensmittel]; var server: [Lebensmittel]; var sichtbar: [Lebensmittel] }`
  - `enum SuchZusammenfuehrung { static func server(_ s: SuchStand, antwort: [Lebensmittel], nummer: Int) -> SuchStand }`: verwirft Antworten mit `nummer != s.nummer`, hängt nur neue IDs/Barcodes hinten an, verändert die Reihenfolge schon sichtbarer Einträge nie.
  - `enum HinzuTyp: String, CaseIterable { case lebensmittel = "Lebensmittel", mahlzeiten = "Mahlzeiten", rezepte = "Rezepte" }`
  - `enum HinzuSortierung: String, CaseIterable { case haeufig = "Häufig", zuletzt = "Zuletzt", favoriten = "Favoriten" }`
  - `ErnaehrungFaltung.haeufig(_ p: Person, anzahl: Int = 40) -> [Lebensmittel]` (nach Anzahl Einträge der letzten 90 Tage, dann zuletzt)
  - `ErnaehrungModell.haeufig(_ p: Person) -> [Lebensmittel] { faltung.haeufig(p) }`
  - `@State private var serverFehlt = false` in `HinzufuegenBlatt`

- [ ] **Step 1: Tests Zusammenführung und Häufig**

```swift
import XCTest
@testable import Lovea

final class SuchZusammenfuehrungTests: XCTestCase {
    private func l(_ id: String, barcode: String? = nil) -> Lebensmittel {
        Lebensmittel(id: id, name: id, barcode: barcode, pro100: Naehrwerte(kcal: 1, protein: 0, kohlenhydrate: 0, fett: 0))
    }

    func testAlteAntwortWirdVerworfen() {
        let s = SuchStand(nummer: 5, lokal: [l("a")], server: [], sichtbar: [l("a")])
        XCTAssertEqual(SuchZusammenfuehrung.server(s, antwort: [l("x")], nummer: 4), s)
    }

    func testAnhaengenOhneDoppelteUndOhneSpringen() {
        let s = SuchStand(nummer: 1, lokal: [l("bls-1"), l("off-2", barcode: "2")], server: [], sichtbar: [l("bls-1"), l("off-2", barcode: "2")])
        let neu = SuchZusammenfuehrung.server(s, antwort: [l("off-2", barcode: "2"), l("off-3", barcode: "3")], nummer: 1)
        XCTAssertEqual(neu.sichtbar.map(\.id), ["bls-1", "off-2", "off-3"])
    }

    func testHaeufigZaehlt() {
        var f = ErnaehrungFaltung()
        let kaffee = l("bls-k"), ei = l("bls-e")
        let heute = Datum.heute
        for (i, x) in [kaffee, ei, kaffee, kaffee].enumerated() {
            let e = EssenEintrag(id: "e\(i)", datum: heute, mahlzeit: .fruehstueck, menge: 1, einheit: .g, lebensmittel: x, geloescht: nil)
            f.anwenden(Op.test(art: "essen.setzen", von: .ahmed, zeit: Date(timeIntervalSince1970: Double(i)), daten: e))
        }
        XCTAssertEqual(f.haeufig(.ahmed).map(\.id), ["bls-k", "bls-e"])
    }
}
```

(`Datum.heute` und `Op.test` greppen; Namen an das Vorhandene anpassen, siehe Task 9 Step 1.)

- [ ] **Step 2: Implementierung Logik**

`SuchZusammenfuehrung.swift`:

```swift
import Foundation

struct SuchStand: Equatable {
    var nummer: Int = 0
    var lokal: [Lebensmittel] = []
    var server: [Lebensmittel] = []
    var sichtbar: [Lebensmittel] = []
}

/// Server-Treffer kommen später als lokale. Sie werden nur hinten angehängt, damit nichts springt,
/// und eine Antwort zu einer älteren Eingabe wird verworfen.
enum SuchZusammenfuehrung {
    static func server(_ s: SuchStand, antwort: [Lebensmittel], nummer: Int) -> SuchStand {
        guard nummer == s.nummer else { return s }
        var neu = s
        var ids = Set(s.sichtbar.map(\.id))
        var codes = Set(s.sichtbar.compactMap(\.barcode))
        let dazu = antwort.filter { l in
            guard !ids.contains(l.id), l.barcode.map({ !codes.contains($0) }) ?? true else { return false }
            ids.insert(l.id)
            if let c = l.barcode { codes.insert(c) }
            return true
        }
        neu.server = antwort
        neu.sichtbar = Array((s.sichtbar + dazu).prefix(80))
        return neu
    }
}
```

`ErnaehrungFaltung.haeufig`:

```swift
    /// Am häufigsten gegessen in den letzten 90 Tagen, bei Gleichstand das zuletzt gegessene zuerst.
    func haeufig(_ p: Person, anzahl: Int = 40) -> [Lebensmittel] {
        let grenze = Datum.tag(Date().addingTimeInterval(-90 * 86400))
        var zahl: [String: (n: Int, zeit: Date, l: Lebensmittel)] = [:]
        for s in (essen[p] ?? [:]).values where s.wert.geloescht != true && s.wert.datum >= grenze && !s.wert.lebensmittel.id.hasPrefix("schnell-") {
            let alt = zahl[s.wert.lebensmittel.id]
            zahl[s.wert.lebensmittel.id] = ((alt?.n ?? 0) + 1, max(alt?.zeit ?? .distantPast, s.zeit), s.wert.lebensmittel)
        }
        return zahl.values.sorted { $0.n != $1.n ? $0.n > $1.n : $0.zeit > $1.zeit }.prefix(anzahl).map(\.l)
    }
```

(`Datum.tag(_:)` greppen: `grep -n "static func" Lovea/Sources/**/Datum*.swift`. Heißt die Funktion anders, den vorhandenen Namen nehmen.) Im Test `testHaeufigZaehlt` liegen alle Einträge heute, also innerhalb der 90 Tage.

- [ ] **Step 3: Oberfläche Hinzufügen-Seite**

`HinzufuegenBlatt` bekommt diesen Aufbau (Bilder yazio-02, -03, -05). Die bestehenden Sheets (`BarcodeScannerBlatt`, `SchnellEintragenBlatt`, `EigenesLebensmittelEditor`, `RezeptEditor`) und `zeigeHinweis`/`direktEintragen` bleiben.

```swift
    @State private var typ: HinzuTyp = .lebensmittel
    @State private var sortierung: HinzuSortierung = .haeufig
    @State private var zaehler = 0
    @State private var suche = SuchStand()
    @State private var suchAufgabe: Task<Void, Never>?
    @State private var suchModus = false
    @State private var chip: SuchChip?          // .favoriten, .vonMir, .vonPartner
    @State private var erstellenOffen = false
    @State private var kommtBald: String?       // "KI-Kalorien-Tracking" / "Sprache und Text"
    @State private var vorschlaege: (name: String, liste: [Lebensmittel], code: String)?
    @State private var fotoBarcode: BarcodeVorlage?
```

Aufbau `body` (ohne `.searchable`, eigenes Suchfeld wie YAZIO):

```swift
NavigationStack(path: $pfad) {
    VStack(spacing: 0) {
        if suchModus { SuchKopf(text: $suchtext, abbrechen: suchBeenden) ; SuchChips(auswahl: $chip, partner: ich.partner) }
        else { HinzuKopf(titel: modell.mahlzeitName(mahlzeit), zaehler: zaehler, schliessen: { dismiss() })
               KachelReihe(aktiv: .suche, tippen: kachel)
               SuchFeldKnopf(platzhalter: "Was hattest du zum \(modell.mahlzeitName(mahlzeit))?") { suchModus = true }
               HStack { AuswahlKnopf(wert: $typ); AuswahlKnopf(wert: $sortierung) }.padding(.horizontal, 16) }
        ScrollView { LazyVStack(spacing: suchModus ? 12 : 0) { inhalt } }
    }
    .safeAreaInset(edge: .bottom) { if !suchModus { FertigKnopf { dismiss() } } }
    .toolbar(.hidden, for: .navigationBar)
    .navigationDestination(for: Lebensmittel.self) { … wie bisher … }
}
```

- `KachelReihe`: waagerechter `ScrollView`, fünf quadratische Kacheln 88 x 80 pt mit abgerundeten Ecken 18 pt, SF Symbols statt Emojis (`magnifyingglass`, `camera.fill`, `barcode.viewfinder`, `text.bubble.fill`, `ellipsis`), Titel darunter. Aktive Kachel mit `Color.accentColor`-Rand 2 pt und getönter Fläche. Tipp: Suche -> `suchModus = true`; Kamera -> `kommtBald = "KI-Kalorien-Tracking"`; Barcode -> `barcodeOffen = true`; Sprache/Text -> `kommtBald = "Sprache und Text"`; Mehr -> `erstellenOffen = true`.
- `AuswahlKnopf`: Rahmen-Knopf mit Text links und `chevron.down` rechts, `Menu` mit Häkchen vor dem aktiven Wert (Bild yazio-02/-03).
- Liste (nicht Such-Modus): Quelle je nach `typ` und `sortierung`:
  - Lebensmittel: `.haeufig` -> `faltung.haeufig`, `.zuletzt` -> `modell.zuletzt(ich)`, `.favoriten` -> `modell.favoriten(ich).filter { !$0.istRezept }`
  - Mahlzeiten/Rezepte: `modell.rezepte.filter { art passt }`, sortiert wie die Sortierung (Favoriten = Rezepte, deren `rezept-<id>` Favorit ist; Häufig/Zuletzt über dieselben Listen, gefiltert auf `rezept-`-IDs, Rest alphabetisch hinten).
  - Zeile (`HinzuZeile`): Name (`.body`), darunter Standardportion `"1 \(portion.name) (\(gramm) g)"` oder `"100 g"` in `.secondary`, rechts kcal der Standardportion und ein 36-pt-Kreis mit `plus` in `Color.accentColor` (Umriss). Trennlinie unten. Plus -> `direktEintragen(l)`, `zaehler += 1`, kurze Bestätigung (Plus wird 1 s zum Häkchen).
- Such-Modus (Bild yazio-09/-10): Karten (`SuchKarte`) mit 16 pt Innenabstand, Fläche `secondarySystemBackground`, Ecken 18 pt: Name fett, darunter `"\(marke), \(portion)"`, unten links Chip (Lebensmittel/Mahlzeit/Rezept), unten rechts kcal, oben rechts Plus. Chips oben: "Favoriten", "Von mir erstellt", "Von \(partner.name)". Kontextmenü auf Karten mit Ersteller Partner: "Zu mir kopieren" (`modell.kopieren`) und "Favorit".
- Suche beim Tippen:

```swift
.onChange(of: suchtext) { _, neu in
    suchAufgabe?.cancel()
    suche.nummer += 1
    let nummer = suche.nummer
    let t = neu.trimmingCharacters(in: .whitespaces)
    if t.count >= 8, t.allSatisfy(\.isNumber) { suche.sichtbar = []; barcodeSuchen(t); return }
    let vorne = modell.favoriten(ich) + modell.haeufig(ich) + modell.eigene + modell.rezepte.map(ErnaehrungLogik.alsLebensmittel)
    suche.lokal = LebensmittelIndex.shared.suchen(t, vorne: vorne)
    suche.sichtbar = suche.lokal
    guard t.count >= 2 else { return }
    suchAufgabe = Task {
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        do {
            let antwort = try await EssenServer.suchen(t)
            guard !Task.isCancelled else { return }
            serverFehlt = false
            suche = SuchZusammenfuehrung.server(suche, antwort: antwort, nummer: nummer)
        } catch {
            if !Task.isCancelled, nummer == suche.nummer { serverFehlt = true }
        }
    }
}
```

Ist der Server nicht erreichbar, erscheint unter den Karten eine leise Zeile "Markenprodukte gerade nicht erreichbar". Die lokale Suche läuft synchron auf dem Main-Thread; laut Task 3 unter 16 ms. Zeigt die CI-Messung mehr als 8 ms, die lokale Suche in `Task.detached` verlegen und das Ergebnis mit derselben `nummer`-Prüfung übernehmen.

- Barcode (`barcodeSuchen`) nutzt jetzt `BarcodeKette.suchen(code, .echt)`:
  - `.gefunden(l)` -> `pfad.append(l)`
  - `.vorschlaege(name, liste)` -> Blatt "Meintest du …?" mit `name` als Titel und den Karten; Tipp auf eine Karte speichert `var k = l; k.id = "eigen-\(UUID())"; k.barcode = code; modell.eigenesSichern(k)` und öffnet sie. Unten Knopf "Nichts davon, Nährwerte fotografieren".
  - `.unbekannt(code)` -> direkt `NaehrwertFotoBlatt(barcode: code)`
  - `.offline(code)` -> `modell.merken(code)` und Hinweis "Kein Netz. Barcode gemerkt, wir suchen, sobald du online bist."
- Beim Erscheinen von `HinzufuegenBlatt`: `Task { for l in await modell.nachholen() { zeigeHinweis("\(l.name) gefunden") } }` nur wenn `!modell.offeneBarcodes.isEmpty`.
- Erstellen-Blatt (Bild yazio-04): fünf Karten mit SF Symbols (`bolt.fill`, `barcode`, `carrot.fill`, `takeoutbag.and.cup.and.straw.fill`, `book.pages.fill`), Titel und Untertitel wörtlich wie im Bild. Schnell hinzufügen -> `schnellOffen`, mit Barcode -> Scanner und dann `NaehrwertFotoBlatt`, ohne Barcode -> `EigenesLebensmittelEditor()`, Mahlzeit -> `RezeptEditor(art: .mahlzeit)`, Rezept -> `RezeptEditor(art: .rezept)`.
- "Kommt bald"-Blatt: Titel (z. B. "KI-Kalorien-Tracking"), ein Satz "Kommt bald.", Knopf "Okay". `presentationDetents([.height(220)])`.

- [ ] **Step 4: Render-Tafeln**

In `RenderGalerieErnaehrungTests.swift` einen Test `testHinzufuegenYazio` ergänzen, der mit festen Daten rendert: Hinzufügen-Seite (Lebensmittel/Häufig mit 8 Zeilen wie Bild yazio-05), Such-Modus "Eier" mit 5 Karten (Marken Aldi, Rewe, Lidl), Erstellen-Blatt, jeweils hell und dunkel. Damit die Views ohne `ErnaehrungModell.shared` renderbar sind: die Listen-Teile (`HinzuZeile`, `SuchKarte`, `KachelReihe`, `ErstellenListe`) nehmen nur Werte, keine Singletons. `RenderTafel.speichern("hinzufuegen", spalten: 3, zellen: zellen)`.

- [ ] **Step 5: Commit**

```bash
git add Lovea/Sources/Health/Ernaehrung Lovea/Tests/SuchZusammenfuehrungTests.swift Lovea/Tests/RenderGalerieErnaehrungTests.swift
git commit -m "feat(essen): Hinzufuegen und Suche wie YAZIO"
```

---

### Task 11: Lebensmittel-Seite mit Mengen-Blatt

**Files:**
- Modify: `Lovea/Sources/Health/Ernaehrung/ErnaehrungPortionen.swift` (`MengenRadBlatt` ersetzt durch `MengenLeiste`, neue Logik `MengenRad`)
- Modify: `Lovea/Sources/Health/Ernaehrung/LebensmittelDetail.swift` (Kopf wie YAZIO, feste Leiste unten, BLS-Quelle)
- Test: `Lovea/Tests/MengenRadLogikTests.swift`, `Lovea/Tests/RenderGalerieErnaehrungTests.swift`

**Interfaces:**
- Consumes: `MengenOption` (vorhanden), `ErnaehrungLogik.eingabe(_:)` (vorhanden), `Lebensmittel.quelle` (T2).
- Produces:
  - `enum MengenRad { static let brueche: [(text: String, wert: Double)]; static func zerlegen(_ zahl: Double) -> (ganz: Int, bruch: Int); static func zahl(ganz: Int, bruch: Int) -> Double; static func feldText(_ zahl: Double) -> String; static let maxGanz = 2000 }`
  - `struct MengenLeiste: View` mit `init(lebensmittel: Lebensmittel, auswahl: Binding<MengenOption>, zahl: Binding<Double>, knopf: String, aktion: () -> Void)`
  - `LebensmittelDetailView` behält `init(lebensmittel:mahlzeit:datum:bearbeiten:fertig:)`.

- [ ] **Step 1: Tests**

```swift
import XCTest
@testable import Lovea

final class MengenRadLogikTests: XCTestCase {
    func testZusammensetzen() {
        XCTAssertEqual(MengenRad.zahl(ganz: 721, bruch: 7), 721.875)   // 7 = Index von 7/8
        XCTAssertEqual(MengenRad.zahl(ganz: 1, bruch: 0), 1)
    }

    func testZerlegen() {
        XCTAssertEqual(MengenRad.zerlegen(721.875).ganz, 721)
        XCTAssertEqual(MengenRad.brueche[MengenRad.zerlegen(721.875).bruch].text, "⅞")
        XCTAssertEqual(MengenRad.brueche[MengenRad.zerlegen(0.3).bruch].text, "⅓")
        XCTAssertEqual(MengenRad.zerlegen(500).ganz, 500)
        XCTAssertEqual(MengenRad.zerlegen(99999).ganz, MengenRad.maxGanz)
    }

    func testFeldText() {
        XCTAssertEqual(MengenRad.feldText(721.875), "721,875")
        XCTAssertEqual(MengenRad.feldText(500), "500")
        XCTAssertEqual(MengenRad.feldText(0.5), "0,5")
    }

    func testEingabe() {
        XCTAssertEqual(ErnaehrungLogik.eingabe("0,5"), 0.5)
        XCTAssertEqual(ErnaehrungLogik.eingabe("1.5"), 1.5)
        XCTAssertEqual(ErnaehrungLogik.eingabe("500"), 500)
        XCTAssertNil(ErnaehrungLogik.eingabe(""))
        XCTAssertNil(ErnaehrungLogik.eingabe("abc"))
        XCTAssertEqual(ErnaehrungLogik.eingabe("99999"), 99999)
    }
}
```

- [ ] **Step 2: Logik**

In `ErnaehrungPortionen.swift`:

```swift
/// Drei Spalten wie YAZIO: Ganzzahl, Bruch, Einheit. Das Feld darüber nimmt jede Zahl, das Rad klemmt am Rand.
enum MengenRad {
    static let maxGanz = 2000
    static let brueche: [(text: String, wert: Double)] = [
        ("–", 0), ("⅛", 0.125), ("¼", 0.25), ("⅓", 1.0 / 3), ("½", 0.5), ("⅔", 2.0 / 3), ("¾", 0.75), ("⅞", 0.875),
    ]

    static func zahl(ganz: Int, bruch: Int) -> Double { Double(ganz) + brueche[min(max(bruch, 0), brueche.count - 1)].wert }

    static func zerlegen(_ zahl: Double) -> (ganz: Int, bruch: Int) {
        let z = max(0, zahl)
        let ganz = min(Int(z.rounded(.down)), maxGanz)
        let rest = ganz == maxGanz ? 0 : z - Double(ganz)
        let bruch = brueche.indices.min { abs(brueche[$0].wert - rest) < abs(brueche[$1].wert - rest) } ?? 0
        return (ganz, bruch)
    }

    /// Bis 3 Nachkommastellen, deutsches Komma, ohne Nullen am Ende: 721,875 / 500 / 0,5.
    static func feldText(_ zahl: Double) -> String {
        var t = String(format: "%.3f", zahl)
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t.replacingOccurrences(of: ".", with: ",")
    }
}
```

`MengenOption.zahlStufen`, `zahlNeu` und `bruchText` werden nur noch vom alten Rad genutzt: nach dem Umbau greppen und löschen, wenn nichts mehr darauf zeigt.

- [ ] **Step 3: `MengenLeiste` (Bilder yazio-01, -06, -07, -08)**

```swift
struct MengenLeiste: View {
    let lebensmittel: Lebensmittel
    @Binding var auswahl: MengenOption
    @Binding var zahl: Double
    let knopf: String
    let aktion: () -> Void

    @State private var feld = ""
    @State private var ganz = 1
    @State private var bruch = 0
    @FocusState private var tippt: Bool

    private var optionen: [MengenOption] { MengenOption.optionen(lebensmittel) }

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(.secondary.opacity(0.5)).frame(width: 40, height: 5).padding(.top, 8)
            HStack(spacing: 2) {
                TextField("0", text: $feld)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($tippt)
                    .frame(width: 96)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(uiColor: .tertiarySystemFill), in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22))
                HStack {
                    Text(auswahl.anzeige(lebensmittel)).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color(uiColor: .tertiarySystemFill), in: UnevenRoundedRectangle(bottomTrailingRadius: 22, topTrailingRadius: 22))
                .allowsHitTesting(false)
            }
            .font(.title3)
            Button(action: aktion) {
                Text(knopf).font(.title3.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(zahl <= 0)
            if !tippt {
                HStack(spacing: 0) {
                    Picker("Ganz", selection: $ganz) { ForEach(0...MengenRad.maxGanz, id: \.self) { Text("\($0)").tag($0) } }
                        .frame(width: 80)
                    Picker("Bruch", selection: $bruch) { ForEach(MengenRad.brueche.indices, id: \.self) { Text(MengenRad.brueche[$0].text).tag($0) } }
                        .frame(width: 60)
                    Picker("Einheit", selection: $auswahl) { ForEach(optionen, id: \.self) { Text($0.anzeige(lebensmittel)).tag($0) } }
                        .frame(maxWidth: .infinity)
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 200)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
        .background(Color(uiColor: .secondarySystemBackground), in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
        .onAppear { vonZahl() }
        .onChange(of: feld) { _, neu in if tippt, let z = ErnaehrungLogik.eingabe(neu) { zahl = z } else if tippt { zahl = 0 } }
        .onChange(of: tippt) { _, an in if !an { vonZahl() } }
        .onChange(of: ganz) { _, _ in if !tippt { zahl = MengenRad.zahl(ganz: ganz, bruch: bruch); feld = MengenRad.feldText(zahl) } }
        .onChange(of: bruch) { _, _ in if !tippt { zahl = MengenRad.zahl(ganz: ganz, bruch: bruch); feld = MengenRad.feldText(zahl) } }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { tippt = false } } }
    }

    private func vonZahl() {
        feld = MengenRad.feldText(zahl)
        (ganz, bruch) = MengenRad.zerlegen(zahl)
    }
}
```

Die Einheit wechselt nur über das dritte Rad (Ahmed: "rechts davon nicht"). Beim Wechsel der Einheit bleibt die Zahl stehen wie bei YAZIO (1 Frucht mittelgroß -> 1 Frucht klein), die Werte oben rechnen neu. Das alte Umrechnen in `onChange(of: auswahl)` entfällt.

- [ ] **Step 4: Lebensmittel-Seite**

`LebensmittelDetailView.body`:
- Kopf: Fläche 220 pt hoch, dunkler Verlauf (`LinearGradient` aus `Color(white: 0.28)` nach `Color(white: 0.14)`), Name zentriert `.title2.weight(.bold)`, weiß.
- Darunter vier Spalten (Kalorien, Kohlenhydrate, Eiweiß, Fett) mit Wert fett und Titel darunter, live aus `naehrwerte`. Zahlen mit `ErnaehrungLogik.zahl`, kcal ganzzahlig mit Tausenderpunkt (`formatted(.number.locale(Locale(identifier: "de_DE")))`).
- Darunter mittig: bei `lebensmittel.quelle == "bls"` `Label("Geprüfte Nährwertangaben", systemImage: "checkmark.seal.fill")`; bei `modell.letzteMenge(ich, lebensmittel) != nil` `Label("Zuletzt hinzugefügt", systemImage: "clock.arrow.circlepath")`.
- Dann die vorhandenen Abschnitte `FoodSchilder`, `naehrwerteAbschnitt`, `portionsbeispieleZeile`. Bei BLS ganz unten klein: "Nährwerte: Max Rubner-Institut, BLS 4.0 (CC BY 4.0)".
- `.safeAreaInset(edge: .bottom) { MengenLeiste(lebensmittel: lebensmittel, auswahl: $auswahl, zahl: $zahl, knopf: bearbeiten == nil ? "Hinzufügen" : "Speichern", aktion: speichern) }` ersetzt `unten` und das `MengenRadBlatt`-Sheet. `mengenRadOffen` löschen.

- [ ] **Step 5: Render-Tafel**

`testMengenLeiste` in `RenderGalerieErnaehrungTests.swift`: Banane (BLS, Portionen klein/mittel/groß) mit 1 x mittelgroß und 721 7/8 x klein, Hühnerei mit 1 x mittelgroß, hell und dunkel, `RenderTafel.speichern("mengen", spalten: 3, zellen: zellen)`. Nach der CI die Tafel neben yazio-06 und yazio-08 legen und vergleichen.

- [ ] **Step 6: Commit**

```bash
git add Lovea/Sources/Health/Ernaehrung/ErnaehrungPortionen.swift Lovea/Sources/Health/Ernaehrung/LebensmittelDetail.swift Lovea/Tests/MengenRadLogikTests.swift Lovea/Tests/RenderGalerieErnaehrungTests.swift
git commit -m "feat(essen): Mengen-Blatt wie YAZIO mit Tastatur und Dreier-Rad"
```

---

### Task 12: CI, Server-Deploy, TestFlight

**Files:** keine neuen; nur Ausführen und Fehler beheben.

- [ ] **Step 1: Server-Tests lokal**

Run: `cd server && node --test`
Expected: alles PASS.

- [ ] **Step 2: CI**

```bash
git push -u origin essen-yazio
gh repo edit Tobito320/lovea-app-ios --visibility public --accept-visibility-change-consequences
gh pr create -R Tobito320/lovea-app-ios --base runde-3 --head essen-yazio --draft --title "Essen wie YAZIO" --body-file docs/superpowers/specs/2026-10-01-essen-wie-yazio-design.md
gh run watch -R Tobito320/lovea-app-ios $(gh run list -R Tobito320/lovea-app-ios --branch essen-yazio --limit 1 --json databaseId -q '.[0].databaseId')
```

Expected: `patterns`, `server`, `build-and-test` grün. Rot: Fehler aus dem Log lesen (`gh run view --log-failed`), beheben, neu pushen. Nicht öfter als dreimal raten; dann Ursache systematisch suchen (Skill `superpowers:systematic-debugging`).
Render-Tafeln `hinzufuegen` und `mengen` aus dem Artefakt `render-galerie` laden und mit den YAZIO-Bildern vergleichen. Abweichungen im Aufbau beheben.

- [ ] **Step 3: Server test, dann live**

Run: `cd server && npm run deploy:test`, Stichprobe mit der Test-App oder `curl -H "X-Lovea-Key: …" …/essen/barcode/4311501679715` (Schlüssel nicht ins Terminal-Log schreiben, aus der Umgebung lesen). Danach `npm run deploy:live` erst nach Ahmeds Ja.
Optional: opengtindb-ID als Secret, sobald Ahmed sie hat: `npx wrangler secret put OPENGTINDB_ID --env live` (und `--env test`).

- [ ] **Step 4: TestFlight und aufräumen**

Nach Ahmeds Ja: `essen-yazio` per Fast-Forward nach `runde-3`, TestFlight-Workflow starten (`gh workflow run testflight.yml -R Tobito320/lovea-app-ios --ref runde-3`), warten, danach `gh repo edit Tobito320/lovea-app-ios --visibility private --accept-visibility-change-consequences`.
Auftragsbrett (Vault) abhaken mit Commit-Hashes.
