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
    anzahl_mit_scans = 0
    zeilen_gesamt = 0
    for z in zeilen(quelle):
        zeilen_gesamt += 1
        if not LAENDER & set((z.get("countries_tags") or "").split(",")):
            continue
        if not z.get("energy-kcal_100g") or not z.get("product_name"):
            continue
        anzahl += 1
        bytes_ += sum(len(z.get(f) or "") for f in FELDER) + 40
        try:
            if float(z.get("unique_scans_n") or 0) >= 1:
                anzahl_mit_scans += 1
        except ValueError:
            pass
    print(f"Zeilen gesamt: {zeilen_gesamt}")
    print(f"DACH mit kcal: {anzahl}")
    print(f"DACH mit kcal und unique_scans_n >= 1: {anzahl_mit_scans}")
    print(f"Rohdaten ca. {bytes_ / 1e6:.0f} MB, mit FTS-Index ca. {bytes_ * 2.2 / 1e6:.0f} MB")

if __name__ == "__main__":
    main()
