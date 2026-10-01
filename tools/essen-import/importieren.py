"""Open Food Facts (DACH) -> D1-Tabelle produkt.
  voll:  python importieren.py voll [csv.gz-pfad-oder-url] --db lovea-essen-test [--nur-gescannt] [--start N] [--max M]
  delta: python importieren.py delta --db lovea-essen-live   (Delta-Dateien der letzten 2 Tage)

--nur-gescannt / --start / --max dienen dazu, die Erstbefuellung ueber mehrere Tage zu verteilen
(Cloudflare Free: 100.000 geschriebene Zeilen/Tag). --start ueberspringt die ersten N passenden
Produkte (Zaehlung nach --nur-gescannt-Filter), --max schreibt hoechstens M. Am Ende wird der
naechste Start-Index ausgegeben, damit der naechste Lauf direkt dort weitermachen kann."""
import argparse, csv, gzip, io, itertools, json, subprocess, sys, urllib.request
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
    menge = z.get("quantity") or None
    portion_name = z.get("serving_size") or None
    # Laengen deckeln wie beim Namen: haelt die D1-Anweisungslaenge (100 KB-Grenze) im Griff.
    return {"code": code, "name": name[:200], "marke": marke[:100] if marke else None,
            "menge": str(menge)[:100] if menge else None,
            "portion_g": zahl(z.get("serving_quantity")) or None,
            "portion_name": str(portion_name)[:100] if portion_name else None,
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
    ist_datei = not quelle.startswith("http")
    roh = open(quelle, "rb") if ist_datei else urllib.request.urlopen(urllib.request.Request(quelle, headers=AGENT), timeout=60)
    csv.field_size_limit(2**31 - 1)  # sys.maxsize laeuft unter Windows ueber
    try:
        yield from csv.DictReader(io.TextIOWrapper(gzip.GzipFile(fileobj=roh), encoding="utf-8"), delimiter="\t")
    finally:
        roh.close()

# Reine Funktion (kein I/O): aus rohen Zeilen die passenden Produkte filtern, dabei Start
# uebersrpingen und bei Max abbrechen. Zeilen, die zeile_zu_produkt oder nur_gescannt verwerfen,
# zaehlen nicht zum Start-Index - nur tatsaechlich passende Produkte tun das. Deterministisch,
# daher direkt mit kleinen Listen testbar, ohne CSV/Netz.
def auswahl(zeilen, start=0, max_=None, nur_gescannt=False, nur_ungescannt=False):
    produkte, gesehen = [], 0
    for z in zeilen:
        p = zeile_zu_produkt(z)
        if not p or (nur_gescannt and p["beliebtheit"] < 1) or (nur_ungescannt and p["beliebtheit"] >= 1):
            continue
        if gesehen >= start:
            produkte.append(p)
        gesehen += 1
        if max_ is not None and len(produkte) >= max_:
            break
    return produkte, gesehen

# ponytail: Rohzeilen-Abschnittsgroesse grob nach der Treffer-Quote aus Task 1 (ca. 6,8% DACH-Treffer)
# gewaehlt, damit ein Abschnitt meist auf ~20.000 passende Produkte kommt. Kein Problem, wenn ein
# Abschnitt mehr oder weniger liefert, hochladen() zerlegt ohnehin in 20.000er-Haeppchen.
ROHZEILEN_PRO_ABSCHNITT = 300_000

def voll(quelle, db, nur_gescannt=False, nur_ungescannt=False, start=0, max_n=None):
    rest_start, rest_max, gesamt, gesamt_gesehen = start, max_n, 0, 0
    zeilen = csv_zeilen(quelle)
    while True:
        abschnitt = list(itertools.islice(zeilen, ROHZEILEN_PRO_ABSCHNITT))
        if not abschnitt:
            break
        produkte, gezaehlt = auswahl(abschnitt, start=rest_start, max_=rest_max, nur_gescannt=nur_gescannt,
                                      nur_ungescannt=nur_ungescannt)
        gesamt_gesehen += gezaehlt
        rest_start = max(0, rest_start - gezaehlt)
        if produkte:
            hochladen(db, produkte)
            gesamt += len(produkte)
            print(gesamt, flush=True)
            if rest_max is not None:
                rest_max -= len(produkte)
        if rest_max is not None and rest_max <= 0:
            break
    zeilen.close()  # schliesst bei vorzeitigem Abbruch (--max) auch das Datei-/Netz-Handle in csv_zeilen
    print("fertig", gesamt, "naechster start", gesamt_gesehen)

def delta(db):
    index = urllib.request.urlopen(urllib.request.Request(DELTA + "index.txt", headers=AGENT), timeout=60).read().decode().split()
    produkte = []
    for datei in index[-2:]:
        roh = urllib.request.urlopen(urllib.request.Request(DELTA + datei, headers=AGENT), timeout=60)
        for zeile in io.TextIOWrapper(gzip.GzipFile(fileobj=roh), encoding="utf-8"):
            j = json.loads(zeile)
            j.update(j.get("nutriments") or {})
            p = zeile_zu_produkt(j)
            if p:
                produkte.append(p)
        roh.close()
    hochladen(db, produkte); print("delta", len(produkte))

if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("modus", choices=["voll", "delta"])
    a.add_argument("quelle", nargs="?", default=CSV_URL)
    a.add_argument("--db", required=True)
    a.add_argument("--nur-gescannt", action="store_true", help="nur Produkte mit unique_scans_n >= 1")
    a.add_argument("--nur-ungescannt", action="store_true", help="nur Produkte mit unique_scans_n == 0")
    a.add_argument("--start", type=int, default=0, help="die ersten N passenden Produkte ueberspringen")
    a.add_argument("--max", type=int, default=None, help="hoechstens M Produkte schreiben")
    args = a.parse_args()
    if args.modus == "voll":
        voll(args.quelle, args.db, nur_gescannt=args.nur_gescannt, nur_ungescannt=args.nur_ungescannt,
             start=args.start, max_n=args.max)
    else:
        delta(args.db)
