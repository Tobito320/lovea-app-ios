"""Erzeugt Lovea/Sources/Health/Ernaehrung/lebensmittel-basis.json aus dem BLS 4.0 (Max Rubner-Institut, CC BY 4.0).
Aufruf: python bls_import.py BLS_4_0.xlsx
Alte Portionen aus der bisherigen JSON bleiben erhalten (Zuordnung ueber den Suchschluessel),
sonst Regeln aus portionen.json (erste passende Regel gewinnt), sonst keine Portionen."""
import json, re, sys, unicodedata
from pathlib import Path

ZIEL = Path(__file__).resolve().parents[2] / "Lovea/Sources/Health/Ernaehrung/lebensmittel-basis.json"
REGELN = Path(__file__).with_name("portionen.json")

# App-Feld -> BLS-Spaltenname (aus den echten Headern von BLS_4_0_Daten_2025_DE.xlsx)
SPALTEN = {
    "code": "BLS Code",
    "name": "Lebensmittelbezeichnung",
    "kcal": "ENERCC Energie (Kilokalorien) [kcal/100g]",
    "protein": "PROT625 Protein (Nx6,25) [g/100g]",
    "kohlenhydrate": "CHO Kohlenhydrate, verfügbar [g/100g]",
    "fett": "FAT Fett [g/100g]",
    "zucker": "SUGAR Zucker (Mono- und Disaccharide), gesamt [g/100g]",
    "ballaststoffe": "FIBT Ballaststoffe, gesamt [g/100g]",
    "natrium_mg": "NA Natrium [mg/100g]",
    "gesFett": "FASAT Fettsäuren, gesättigt, gesamt [g/100g]",
    "wasser_g": "WATER Wasser [g/100g]",
}

# Mikro.rawValue -> BLS-Spaltenname; nur Werte, die es im BLS gibt.
# BLS-Einheit steht im Spaltenkopf; drei Spalten (VITB6, CU, MN) sind dort µg, Mikro.einheit
# verlangt aber mg, deshalb UMRECHNEN (Faktor 1/1000) in UMRECHNEN_MIKROGRAMM_ZU_MG unten.
# Mikro.selen und Mikro.koffein fehlen im BLS 4.0 komplett, deshalb nicht gemappt.
MIKRO: dict[str, str] = {
    "vitaminA": "VITA Vitamin A, Retinol-Äquivalent (RE) [µg/100g]",
    "vitaminD": "VITD Vitamin D [µg/100g]",
    "vitaminE": "VITE Vitamin E (Alpha-Tocopherol) [mg/100g]",
    "vitaminK": "VITK Vitamin K [µg/100g]",
    "vitaminC": "VITC Vitamin C [mg/100g]",
    "vitaminB1": "THIA Vitamin B1 (Thiamin) [mg/100g]",
    "vitaminB2": "RIBF Vitamin B2 (Riboflavin) [mg/100g]",
    "niacin": "NIA Niacin [mg/100g]",
    "pantothensaeure": "PANTAC Pantothensäure [mg/100g]",
    "vitaminB6": "VITB6 Vitamin B6 [µg/100g]",
    "folat": "FOL Folat-Äquivalent [µg/100g]",
    "vitaminB12": "VITB12 Vitamin B12 (Cobalamine) [µg/100g]",
    "kalium": "K Kalium [mg/100g]",
    "calcium": "CA Calcium [mg/100g]",
    "magnesium": "MG Magnesium [mg/100g]",
    "phosphor": "P Phosphor [mg/100g]",
    "eisen": "FE Eisen [mg/100g]",
    "zink": "ZN Zink [mg/100g]",
    "kupfer": "CU Kupfer [µg/100g]",
    "mangan": "MN Mangan [µg/100g]",
    "natrium": "NA Natrium [mg/100g]",
    "jod": "ID Iodid [µg/100g]",
    "wasser": "WATER Wasser [g/100g]",
    "cholesterin": "CHORL Cholesterin [mg/100g]",
    "einfachUngesaettigt": "FAMS Fettsäure, einfach ungesättigt, gesamt [g/100g]",
    "mehrfachUngesaettigt": "FAPU Fettsäuren, mehrfach ungesättigt, gesamt [g/100g]",
    "alkohol": "ALC Alkohol (Ethanol) [g/100g]",
}
# Diese drei liefert das BLS in µg, Mikro.einheit verlangt mg.
UMRECHNEN_MIKROGRAMM_ZU_MG = {"vitaminB6", "kupfer", "mangan"}

# Getränke: Hauptgruppen-Buchstabe allein reicht nicht (Milch liegt unter "M" bei den Käsesorten,
# Saft unter "F" bei den Früchten, Bier/Wein unter "P" bei Fett/Alkohol) - deshalb über Wörter im
# Namen erkannt. Endungen fangen zusammengesetzte Wörter ("Rotwein", "Trinkwasser"); "cola" nur als
# eigenes Wort, sonst faengt es sich in "Rucola". FEST_SUBSTRING/FEST_EXAKT gehen vor Treffern.
FLUESSIG_SUFFIX = ("wasser", "saft", "milch", "wein", "tee", "kefir", "molke", "kaffee", "bier",
                   "sekt", "schorle", "limonade", "sirup", "bruhe", "bouillon", "smoothie",
                   "nektar", "cocktail", "schnaps", "likor", "wodka", "rum", "gin", "whisky",
                   "weinbrand", "obstbrand", "apfelwein", "getrank", "espresso", "mokka")
FLUESSIG_EXAKT = ("cola",)

# Kaese/Pulver/Schokolade etc. werden im Deutschen ohne Leerzeichen angehaengt
# ("Salzlakenkaese", "Milchpulver"), ein Teilwort-Treffer ist hier sicher; dazu zusammengesetzte
# Gerichte, die ein Getraenk nur als Zutat enthalten (Suppe mit Gemuesebruehe, Kuchen mit Rum).
FEST_SUBSTRING = re.compile(
    r"(pulver|kase|schokolade|creme|quark|sahne|starke|mehl|konserve|praline|schwein|"
    r"suppe|eintopf|kloss|puree|schmarren|tiramisu|speiseeis|sandwich)"
)
# Nur als eigenes Wort fest: ein Teilwort-Treffer wuerde "Eistee" blockieren.
FEST_EXAKT = {"eis", "riegel", "pudding", "joghurt", "chips", "keks", "kuchen", "brot",
              "pfannkuchen", "eierkuchen", "brei", "sosse", "sauce"}

def suchschluessel(name: str) -> str:
    t = name.lower().replace("ß", "ss")
    t = unicodedata.normalize("NFKD", t)
    t = "".join(c for c in t if not unicodedata.combining(c))
    return " ".join(re.findall(r"[a-z0-9]+", t))

def ist_fluessig(suche: str) -> bool:
    if "eigenen saft" in suche or FEST_SUBSTRING.search(suche):
        return False
    tokens = suche.split()
    if FEST_EXAKT.intersection(tokens):
        return False
    if any(t in FLUESSIG_EXAKT for t in tokens):
        return True
    return any(t.endswith(FLUESSIG_SUFFIX) for t in tokens)

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
    # Alte Portionen tragen vereinzelt kaputte Sonderzeichen (z. B. "gro?" statt "groß") aus einem
    # frueheren Encoding-Fehler; beim Uebernehmen reparieren, statt den Fehler weiterzutragen.
    def alte_portionen(liste):
        return [{**p, "name": p["name"].replace("�", "ß")} for p in liste]
    alt = {suchschluessel(e["name"]): alte_portionen(e["portionen"])
           for e in json.loads(ZIEL.read_text("utf-8")) if e.get("portionen")}
    regeln = json.loads(REGELN.read_text("utf-8"))
    liste = []
    for z in zeilen:
        code, name, kcal = z[idx["code"]], z[idx["name"]], zahl(z[idx["kcal"]])
        if not code or not name or kcal is None:
            continue
        natrium = zahl(z[idx["natrium_mg"]])
        suche = suchschluessel(str(name))
        mikro = {}
        for m, i in midx.items():
            v = zahl(z[i])
            if v is None:
                continue
            mikro[m] = round(v / 1000, 6) if m in UMRECHNEN_MIKROGRAMM_ZU_MG else v
        liste.append({
            "id": f"bls-{code}", "name": str(name).strip(), "quelle": "bls",
            "fluessig": ist_fluessig(suche),
            "suche": suche,
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
