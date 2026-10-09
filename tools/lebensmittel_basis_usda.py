"""Ersetzt die geschaetzten pro100-Werte und Portionen in lebensmittel-basis.json durch
echte USDA-SR-Legacy-Werte (Labordaten), inklusive Mikronaehrstoffe.

Aufruf: python lebensmittel_basis_usda.py <USDA-CSV-Ordner>

Jede Zuordnung id -> fdc_id steht unten mit der USDA-Beschreibung als Kommentar.
fdc_id = None heisst: kein passender SR-Legacy-Eintrag gefunden, alte Werte bleiben stehen.
"""
import csv
import json
import re
import sys
from pathlib import Path

# id (lebensmittel-basis.json) -> fdc_id (SR Legacy) oder None (keine Aenderung, alte Werte behalten)
ZUORDNUNG: dict[str, int | None] = {
    "basis-tomaten": 170457,  # Tomatoes, red, ripe, raw, year round average
    "basis-gurke": 168409,  # Cucumber, with peel, raw
    "basis-paprika-rot": 170108,  # Peppers, sweet, red, raw
    "basis-paprika-gruen": 170427,  # Peppers, sweet, green, raw
    "basis-zwiebel": 170000,  # Onions, raw
    "basis-knoblauch": 169230,  # Garlic, raw
    "basis-karotte": 170393,  # Carrots, raw
    "basis-brokkoli": 170379,  # Broccoli, raw
    "basis-blumenkohl": 169986,  # Cauliflower, raw
    "basis-spinat": 168462,  # Spinach, raw
    "basis-kopfsalat": 169248,  # Lettuce, iceberg (includes crisphead types), raw
    "basis-zucchini": 169291,  # Squash, summer, zucchini, includes skin, raw
    "basis-aubergine": 169228,  # Eggplant, raw
    "basis-champignons": 169251,  # Mushrooms, white, raw
    "basis-mais-dose": 169214,  # Corn, sweet, yellow, canned, whole kernel, drained solids
    "basis-erbsen-tk": 170016,  # Peas, green, frozen, unprepared
    "basis-gruene-bohnen-tk": 169962,  # Beans, snap, green, frozen, all styles, unprepared
    "basis-rotkohl": 169977,  # Cabbage, red, raw
    "basis-weisskohl": 169975,  # Cabbage, raw
    "basis-sellerie": 169988,  # Celery, raw
    "basis-lauch": 169246,  # Leeks, (bulb and lower leaf-portion), raw
    "basis-rettich": 168451,  # Radishes, oriental, raw -- Rettich = weisser/asiatischer Rettich, naechster USDA-Eintrag
    "basis-radieschen": 169276,  # Radishes, raw
    "basis-kuerbis-hokkaido": 168448,  # Pumpkin, raw -- Hokkaido ist eine Kuerbissorte, USDA fuehrt keine eigene Hokkaido-Sorte, generisches Pumpkin am naechsten
    "basis-suesskartoffel": 168482,  # Sweet potato, raw, unprepared
    "basis-feldsalat": None,  # kein SR-Legacy-Eintrag fuer Feldsalat/Corn Salad/Valerianella gefunden -- alte Werte behalten
    "basis-fruehlingszwiebel": 170005,  # Onions, spring or scallions (includes tops and bulb), raw
    "basis-apfel": 171688,  # Apples, raw, with skin (Includes foods for USDA's Food Distribution Program)
    "basis-banane": 173944,  # Bananas, raw
    "basis-orange": 169097,  # Oranges, raw, all commercial varieties
    "basis-birne": 169118,  # Pears, raw
    "basis-weintrauben": 174683,  # Grapes, red or green (European type, such as Thompson seedless), raw
    "basis-erdbeeren": 167762,  # Strawberries, raw
    "basis-blaubeeren": 171711,  # Blueberries, raw
    "basis-himbeeren": 167755,  # Raspberries, raw
    "basis-kiwi": 168153,  # Kiwifruit, green, raw
    "basis-ananas": 169124,  # Pineapple, raw, all varieties
    "basis-wassermelone": 167765,  # Watermelon, raw
    "basis-honigmelone": 169911,  # Melons, honeydew, raw
    "basis-mango": 169910,  # Mangos, raw
    "basis-pfirsich": 169928,  # Peaches, yellow, raw
    "basis-aprikose": 171697,  # Apricots, raw
    "basis-pflaume": 169949,  # Plums, raw
    "basis-kirschen": 171719,  # Cherries, sweet, raw
    "basis-avocado": 171705,  # Avocados, raw, all commercial varieties
    "basis-kartoffeln-gekocht": 170438,  # Potatoes, boiled, cooked in skin, flesh, without salt
    "basis-kartoffeln-roh": 170026,  # Potatoes, flesh and skin, raw
    "basis-pommes-ofen": 170437,  # Potatoes, french fried, crinkle or regular cut, salt added in processing, frozen, oven-heated
    "basis-kartoffelpueree": 170493,  # Potatoes, mashed, home-prepared, whole milk added
    "basis-reis-weiss-roh": 169756,  # Rice, white, long-grain, regular, raw, unenriched -- deutscher Reis ist nicht angereichert
    "basis-reis-weiss-gekocht": 169757,  # Rice, white, long-grain, regular, unenriched, cooked without salt
    "basis-vollkornreis-gekocht": 169704,  # Rice, brown, long-grain, cooked (Includes foods for USDA's Food Distribution Program)
    "basis-nudeln-roh": 168927,  # Pasta, dry, unenriched -- deutsche Nudeln sind nicht angereichert
    "basis-nudeln-gekocht": 168928,  # Pasta, cooked, unenriched, without added salt
    "basis-vollkornnudeln-gekocht": 168910,  # Pasta, whole-wheat, cooked (Includes foods for USDA's Food Distribution Program)
    "basis-vollkornbrot": 172688,  # Bread, whole-wheat, commercially prepared
    "basis-toastbrot": 174924,  # Bread, white, commercially prepared (includes soft bread crumbs)
    "basis-mischbrot": 172686,  # Bread, wheat -- Mischung aus Weizen- und Roggenmehl, naechster generischer Eintrag
    "basis-broetchen": 172793,  # Rolls, dinner, plain, commercially prepared (includes brown-and-serve)
    "basis-knaeckebrot": 172739,  # Crackers, crispbread, rye
    "basis-baguette": 172675,  # Bread, french or vienna (includes sourdough)
    "basis-haferflocken": 173904,  # Cereals, oats, regular and quick, not fortified, dry
    "basis-ei-gekocht": 173424,  # Egg, whole, cooked, hard-boiled
    "basis-ei-roh": 171287,  # Egg, whole, raw, fresh
    "basis-ruehrei": 172187,  # Egg, whole, cooked, scrambled
    "basis-milch-15": 170872,  # Milk, lowfat, fluid, 1% milkfat, with added vitamin A and vitamin D -- kein exaktes 1,5%-Pendant in US-Daten, 1% liegt am naechsten an "fettarmer Milch"
    "basis-milch-35": 171265,  # Milk, whole, 3.25% milkfat, with added vitamin D
    "basis-joghurt-natur": 170886,  # Yogurt, plain, low fat
    "basis-joghurt-griechisch": 171304,  # Yogurt, Greek, plain, whole milk
    "basis-quark-mager": None,  # Quark existiert nicht in SR Legacy (US-Datenbank kennt kein Quark) -- alte Werte behalten
    "basis-quark-40": None,  # siehe basis-quark-mager
    "basis-skyr": None,  # Skyr ist in SR Legacy (Stand 2018) nicht enthalten -- alte Werte behalten
    "basis-butter": 173430,  # Butter, without salt
    "basis-schlagsahne": 170859,  # Cream, fluid, heavy whipping
    "basis-frischkaese": 173418,  # Cheese, cream -- entspricht Doppelrahm-Frischkaese am naechsten
    "basis-mozzarella": 170845,  # Cheese, mozzarella, whole milk
    "basis-gouda": 171241,  # Cheese, gouda
    "basis-emmentaler": 171251,  # Cheese, swiss -- Emmentaler ist ein Schweizer Hartkaese, kein eigener USDA-Eintrag
    "basis-feta": 173420,  # Cheese, feta
    "basis-parmesan": 170848,  # Cheese, parmesan, hard
    "basis-huettenkaese": 172179,  # Cheese, cottage, creamed, large or small curd
    "basis-buttermilch": 170874,  # Milk, buttermilk, fluid, cultured, lowfat
    "basis-haehnchenbrust-roh": 171077,  # Chicken, broiler or fryers, breast, skinless, boneless, meat only, raw
    "basis-haehnchenbrust-gebraten": 171477,  # Chicken, broilers or fryers, breast, meat only, cooked, roasted
    "basis-rinderhack-roh": 171796,  # Beef, ground, 85% lean meat / 15% fat, raw (Includes foods for USDA's Food Distribution Program)
    "basis-rinderhack-gebraten": 174033,  # Beef, ground, 85% lean meat / 15% fat, patty, cooked, pan-broiled
    "basis-schweineschnitzel": 168232,  # Pork, fresh, loin, whole, separable lean only, cooked, broiled
    "basis-rindersteak": 173050,  # Beef, loin, top sirloin filet, boneless, separable lean only, trimmed to 0" fat, select, cooked, grilled
    "basis-putenbrust": 171098,  # Turkey, whole, breast, meat only, raw
    "basis-salami": 174582,  # Salami, dry or hard, pork, beef
    "basis-kochschinken": 173863,  # Ham, sliced, pre-packaged, deli meat (96%fat free, water added)
    "basis-lyoner": 171637,  # Bologna, meat and poultry -- Lyoner entspricht am ehesten einer feinen Bruehwurst wie US-Bologna
    "basis-bratwurst": 171620,  # Bratwurst, pork, cooked
    "basis-lachs-roh": 175167,  # Fish, salmon, Atlantic, farmed, raw
    "basis-lachs-gebraten": 175168,  # Fish, salmon, Atlantic, farmed, cooked, dry heat
    "basis-thunfisch-dose": 171986,  # Fish, tuna, light, canned in water, without salt, drained solids
    "basis-garnelen": 175180,  # Crustaceans, shrimp, cooked
    "basis-kabeljau": 171955,  # Fish, cod, Atlantic, raw
    "basis-linsen-gekocht": 172421,  # Lentils, mature seeds, cooked, boiled, without salt
    "basis-kichererbsen-dose": 173800,  # Chickpeas (garbanzo beans, bengal gram), mature seeds, canned, drained solids
    "basis-kidneybohnen-dose": 174285,  # Beans, kidney, red, mature seeds, canned, drained solids
    "basis-weisse-bohnen-dose": 175192,  # Beans, great northern, mature seeds, canned -- naechster Ersatz fuer "Weisse Bohnen"
    "basis-tofu": 172476,  # Tofu, raw, regular, prepared with calcium sulfate
    "basis-mandeln": 170567,  # Nuts, almonds
    "basis-walnuesse": 170187,  # Nuts, walnuts, english
    "basis-cashewkerne": 170162,  # Nuts, cashew nuts, raw
    "basis-erdnuesse": 172430,  # Peanuts, all types, raw
    "basis-erdnussbutter": 172470,  # Peanut butter, smooth style, without salt
    "basis-haselnuesse": 170581,  # Nuts, hazelnuts or filberts
    "basis-olivenoel": 171413,  # Oil, olive, salad or cooking
    "basis-rapsoel": 172336,  # Oil, canola
    "basis-sonnenblumenoel": 171017,  # Oil, sunflower, linoleic (less than 60%)
    "basis-zucker": 169655,  # Sugars, granulated
    "basis-honig": 169640,  # Honey
    "basis-marmelade": 169641,  # Jams and preserves
    "basis-nutella": 168000,  # Chocolate-flavored hazelnut spread
    "basis-wasser": None,  # reines Wasser, alle Werte bereits 0 -- US-Leitungswasser-Mineralstoffe waeren nicht repraesentativ
    "basis-kaffee-schwarz": 171890,  # Beverages, coffee, brewed, prepared with tap water
    "basis-tee": 173227,  # Beverages, tea, black, brewed, prepared with tap water
    "basis-orangensaft": 169098,  # Orange juice, raw (Includes foods for USDA's Food Distribution Program)
    "basis-cola": 174852,  # Beverages, carbonated, cola, regular
    "basis-apfelsaft": 173933,  # Apple juice, canned or bottled, unsweetened, without added ascorbic acid
}

# nutrient_nbr (wie in USDA-Tabellen ueblich zitiert) fuer die Pflicht/optionalen pro100-Felder.
PRO100_NBR = {
    "kcal": "208",
    "protein": "203",
    "kohlenhydrate": "205",
    "fett": "204",
    "zucker": "269",
    "ballaststoffe": "291",
    "gesFett": "606",
}
NATRIUM_NBR = "307"

# Mikro.rawValue -> Mikro.usda (nutrient_nbr) und Mikro.einheit, siehe Mikronaehrstoffe.swift.
MIKRO_NBR = {
    "vitaminA": ("320", "µg"), "vitaminD": ("328", "µg"), "vitaminE": ("323", "mg"), "vitaminK": ("430", "µg"),
    "vitaminC": ("401", "mg"), "vitaminB1": ("404", "mg"), "vitaminB2": ("405", "mg"), "niacin": ("406", "mg"),
    "pantothensaeure": ("410", "mg"), "vitaminB6": ("415", "mg"), "folat": ("435", "µg"), "vitaminB12": ("418", "µg"),
    "kalium": ("306", "mg"), "calcium": ("301", "mg"), "magnesium": ("304", "mg"), "phosphor": ("305", "mg"),
    "eisen": ("303", "mg"), "zink": ("309", "mg"), "kupfer": ("312", "mg"), "mangan": ("315", "mg"),
    "selen": ("317", "µg"), "natrium": ("307", "mg"),
    "wasser": ("255", "g"), "cholesterin": ("601", "mg"), "einfachUngesaettigt": ("645", "g"),
    "mehrfachUngesaettigt": ("646", "g"), "koffein": ("262", "mg"), "alkohol": ("221", "g"),
}
EINHEIT_ZU_USDA = {"µg": "UG", "mg": "MG", "g": "G"}

# (Erkennungsmuster in modifier, deutscher Name). Nur fuer Nicht-cup-Modifier, siehe portion_name().
MODIFIER_PORTIONEN = [
    ("tbsp", "Esslöffel"),
    ("tablespoon", "Esslöffel"),
    ("tsp", "Teelöffel"),
    ("clove", "Zehe"),
    ("crispbread", "Scheibe"),
    ("stalk", "Stange"),
    ("slice", "Scheibe"),
    ("medium", "ganze, mittelgroß"),
    ("small", "ganze, klein"),
    ("large", "ganze, groß"),
    ("fruit (", "ganze"),
    ("avocado", "ganze"),
    ("apricot", "ganze"),
    ("cucumber (", "ganze"),
]

# Reihenfolge, in der Portionen bevorzugt werden (fuer den Default in LebensmittelDetail.first!):
# natuerliche Stueckzahlen zuerst, dann Scheibe, dann Loeffel, Tassen zuletzt.
PORTION_PRIORITAET = {"Tasse": 3, "Tasse, gehackt": 3, "Esslöffel": 2, "Esslöffel, gerieben": 2, "Teelöffel": 2, "Scheibe": 1}

# Plausibilitaetsgrenzen in Gramm: eine USDA-Portion mit diesem Namen, die schwerer ist,
# passt nicht zur deutschen Vorstellung davon (z. B. "Scheibe" Baguette mit 139 g) -- lieber
# weglassen als eine irrefuehrende Zahl uebernehmen.
MAX_GRAMM = {"Scheibe": 100.0, "Esslöffel": 40.0, "Teelöffel": 15.0}

# Manche USDA-Zeilen beschreiben mit dem Modifier-Text eine Mehrfachmenge, z. B.
# "serving 2 TBSP" (1 Portion = 2 Esslöffel) oder amount=6 bei "6 slices" (6 Scheiben zusammen),
# oder amount=0.5 bei "cup" (0,5 Tassen). Ohne diese Korrektur waere z. B. eine "Scheibe"
# Mozzarella 170 g statt 28 g (170 g / 6 Scheiben).
_EINGEBETTETE_MENGE = re.compile(r"(\d+)\s*(tbsp|tsp|cups?|slices?)", re.I)
_NUR_OZ = re.compile(r"[\d.]*\s*(fl\s*)?oz\.?$")


def portion_name(text: str) -> str | None:
    """Deutscher Portionsname aus einem USDA-modifier/portion_description-Text, oder None wenn
    nicht sinnvoll uebersetzbar (dann wird diese USDA-Zeile verworfen statt geraten)."""
    if "extra" in text:
        return None  # "extra small"/"extra large" -- keine passende deutsche Groesse
    if "cup" in text:
        if re.fullmatch(r"cups?", text):
            return "Tasse"
        if re.match(r"cups?,?\s*chopped", text):
            return "Tasse, gehackt"
        return None  # andere cup-Varianten (sliced, mashed, crushed, cherry tomatoes, ...) nicht uebersetzt
    for muster, deutscher_name in MODIFIER_PORTIONEN:
        if muster in text:
            return deutscher_name
    return None


def round_sig(x: float, sig: int = 3) -> float:
    if x == 0:
        return 0.0
    from math import log10, floor
    digits = sig - int(floor(log10(abs(x)))) - 1
    return round(x, digits)


def lade_csv(pfad: Path) -> list[dict]:
    with open(pfad, encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main() -> None:
    usda_dir = Path(sys.argv[1])
    json_pfad = Path(__file__).resolve().parent.parent / "Lovea/Sources/Health/Ernaehrung/lebensmittel-basis.json"

    nutrients = lade_csv(usda_dir / "nutrient.csv")
    nbr_zu_id: dict[str, str] = {n["nutrient_nbr"]: n["id"] for n in nutrients}
    nbr_zu_einheit: dict[str, str] = {n["nutrient_nbr"]: n["unit_name"] for n in nutrients}

    # Einheiten-Check: bricht ab, wenn ein Mikro.einheit nicht zur USDA-Einheit passt.
    for schluessel, (nbr, einheit) in MIKRO_NBR.items():
        usda_einheit = nbr_zu_einheit.get(nbr)
        if usda_einheit != EINHEIT_ZU_USDA[einheit]:
            raise SystemExit(f"Einheiten-Mismatch bei {schluessel}: Mikro erwartet {einheit}, USDA hat {usda_einheit}")

    gebrauchte_ids = {str(v) for v in ZUORDNUNG.values() if v is not None}

    # food_nutrient.csv ist 34 MB -- einmal streamen und nur relevante Zeilen behalten.
    gebrauchte_nutrient_ids = {nbr_zu_id[nbr] for nbr in PRO100_NBR.values()} | {nbr_zu_id[NATRIUM_NBR]} \
        | {nbr_zu_id[nbr] for nbr, _ in MIKRO_NBR.values()}
    nutrient_werte: dict[str, dict[str, float]] = {}  # fdc_id -> nutrient_id -> amount
    with open(usda_dir / "food_nutrient.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row["fdc_id"] in gebrauchte_ids and row["nutrient_id"] in gebrauchte_nutrient_ids and row["amount"]:
                nutrient_werte.setdefault(row["fdc_id"], {})[row["nutrient_id"]] = float(row["amount"])

    portionen_roh: dict[str, list[dict]] = {}
    with open(usda_dir / "food_portion.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row["fdc_id"] in gebrauchte_ids:
                portionen_roh.setdefault(row["fdc_id"], []).append(row)

    daten = json.loads(json_pfad.read_text(encoding="utf-8"))

    ohne_usda = []
    fehlende_kcal = []

    for eintrag in daten:
        fdc_id = ZUORDNUNG.get(eintrag["id"], "FEHLT")
        if fdc_id == "FEHLT":
            raise SystemExit(f"{eintrag['id']} fehlt in ZUORDNUNG")
        if fdc_id is None:
            ohne_usda.append(eintrag["id"])
            continue
        fdc_id = str(fdc_id)
        werte = nutrient_werte.get(fdc_id, {})

        pro100 = {}
        for feld, nbr in PRO100_NBR.items():
            nid = nbr_zu_id[nbr]
            if nid not in werte:
                continue
            if feld == "kcal":
                pro100[feld] = float(round(werte[nid]))
            elif feld in ("protein", "kohlenhydrate", "fett"):
                pro100[feld] = round(werte[nid], 1)
            else:
                # optionale Felder (zucker, ballaststoffe, gesFett): 3 signifikante Stellen statt
                # 1 Nachkommastelle, sonst wird ein echter kleiner Wert (z. B. 0.028 g gesFett bei
                # Tomaten) faelschlich zu 0.0 gerundet -- das sieht wie "fehlt" aus, ist aber falsch.
                pro100[feld] = round_sig(werte[nid], 3)
        natrium_id = nbr_zu_id[NATRIUM_NBR]
        if natrium_id in werte:
            pro100["salz"] = round(werte[natrium_id] * 2.5 / 1000, 4)

        if "kcal" not in pro100 or "protein" not in pro100 or "kohlenhydrate" not in pro100 or "fett" not in pro100:
            fehlende_kcal.append(eintrag["id"])
            continue

        mikro = {}
        for schluessel, (nbr, _einheit) in MIKRO_NBR.items():
            nid = nbr_zu_id[nbr]
            if nid in werte:
                mikro[schluessel] = round_sig(werte[nid], 3)
        if mikro:
            pro100["mikro"] = mikro

        eintrag["pro100"] = pro100

        # Portionen aus USDA uebersetzen.
        roh = sorted(portionen_roh.get(fdc_id, []), key=lambda r: int(r["seq_num"]))
        kandidaten = []  # (prioritaet, seq, name, gramm)
        gesehen = set()
        for seq, r in enumerate(roh):
            text = (r["modifier"] or r["portion_description"] or "").strip().lower()
            if "fl oz" in text:
                continue  # US-Getraenkegroessen in fluid ounces (Fast-Food-Becher) weglassen
            if _NUR_OZ.fullmatch(text):
                continue  # reine Unzen-Gewichtsangabe ("oz", "0.5 oz") weglassen, nicht "slice (1 oz)"
            gramm = float(r["gram_weight"]) if r["gram_weight"] else 0
            if gramm <= 0:
                continue
            name = portion_name(text)
            if name is None or name in gesehen:
                continue
            amount = float(r["amount"]) if r["amount"] else 1.0
            eingebettet = _EINGEBETTETE_MENGE.search(text)
            einheiten = amount * (int(eingebettet.group(1)) if eingebettet else 1)
            if einheiten != 1 and einheiten > 0:
                gramm = gramm / einheiten
            if gramm > MAX_GRAMM.get(name, float("inf")):
                continue
            gesehen.add(name)
            kandidaten.append((PORTION_PRIORITAET.get(name, 0), seq, name, round(gramm, 1)))
        # natuerliche Stueckzahlen zuerst (werden in LebensmittelDetail.swift als Default genommen),
        # Tassen/Loeffel zuletzt; innerhalb derselben Prioritaet die USDA-Reihenfolge behalten.
        kandidaten.sort(key=lambda k: (k[0], k[1]))
        neue_portionen = [{"name": name, "gramm": gramm} for _, _, name, gramm in kandidaten[:5]]
        if neue_portionen:
            eintrag["portionen"] = neue_portionen

    json_pfad.write_text(json.dumps(daten, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    print(f"USDA-Werte uebernommen: {len(daten) - len(ohne_usda) - len(fehlende_kcal)}")
    print(f"Ohne USDA-Zuordnung (alte Werte behalten): {ohne_usda}")
    if fehlende_kcal:
        print(f"fdc_id ohne vollstaendige Makros (alte Werte behalten): {fehlende_kcal}")


if __name__ == "__main__":
    main()
