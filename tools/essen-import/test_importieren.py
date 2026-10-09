from importieren import zeile_zu_produkt, sql_stapel, auswahl

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

def test_delta_json():
    j = {"code": "4311501679715", "product_name": "Skyr", "countries_tags": ["en:germany"], "brands": "Gut & Günstig",
         "nutriments": {"energy-kcal_100g": 65, "proteins_100g": 11}}
    j.update(j["nutriments"])
    assert zeile_zu_produkt(j)["pro100"]["protein"] == 11

def test_sql_escape():
    s = sql_stapel([{"code": "1", "name": "Mama's", "marke": None, "menge": None, "portion_g": None,
                     "portion_name": None, "pro100": {"kcal": 1}, "beliebtheit": 0}])
    assert "Mama''s" in s and "ON CONFLICT(code) DO UPDATE" in s and "OR REPLACE" not in s
    viele = [{"code": str(i), "name": "n", "marke": None, "menge": None, "portion_g": None,
              "portion_name": None, "pro100": {"kcal": 1}, "beliebtheit": 0} for i in range(120)]
    assert sql_stapel(viele).count("INSERT INTO produkt") == 3

# 5 rohe Zeilen: 1, 3, 5 passen (DACH + kcal); 2 ist nicht DACH; 4 hat kein kcal.
def _zeilen():
    return [
        {"code": "1", "product_name": "A", "countries_tags": "en:germany", "energy-kcal_100g": "100", "unique_scans_n": "0"},
        {"code": "2", "product_name": "B", "countries_tags": "en:france", "energy-kcal_100g": "100"},
        {"code": "3", "product_name": "C", "countries_tags": "en:austria", "energy-kcal_100g": "200", "unique_scans_n": "5"},
        {"code": "4", "product_name": "D", "countries_tags": "en:germany"},
        {"code": "5", "product_name": "E", "countries_tags": "en:switzerland", "energy-kcal_100g": "300", "unique_scans_n": "2"},
    ]

def test_auswahl_start_und_max():
    produkte, naechster = auswahl(_zeilen(), start=1, max_=1)
    assert [p["code"] for p in produkte] == ["3"]
    assert naechster == 2

def test_auswahl_ohne_grenzen():
    produkte, naechster = auswahl(_zeilen())
    assert [p["code"] for p in produkte] == ["1", "3", "5"]
    assert naechster == 3

def test_auswahl_nur_gescannt():
    produkte, _ = auswahl(_zeilen(), nur_gescannt=True)
    assert [p["code"] for p in produkte] == ["3", "5"]

def test_auswahl_nur_ungescannt():
    produkte, _ = auswahl(_zeilen(), nur_ungescannt=True)
    assert [p["code"] for p in produkte] == ["1"]

def test_auswahl_deterministisch():
    assert auswahl(_zeilen(), start=1, max_=2) == auswahl(_zeilen(), start=1, max_=2)

def test_auswahl_verworfene_zeilen_zaehlen_nicht_zum_start():
    # "2" (nicht DACH) und "4" (kein kcal) duerfen den Start-Zaehler nicht erhoehen,
    # sonst wuerde start=2 faelschlich "5" statt "5" nach genau 2 echten Treffern liefern.
    produkte, naechster = auswahl(_zeilen(), start=2)
    assert [p["code"] for p in produkte] == ["5"]
    assert naechster == 3

if __name__ == "__main__":
    test_zeile(); test_filter(); test_kj_statt_kcal(); test_delta_json(); test_sql_escape()
    test_auswahl_start_und_max(); test_auswahl_ohne_grenzen(); test_auswahl_nur_gescannt(); test_auswahl_nur_ungescannt()
    test_auswahl_deterministisch(); test_auswahl_verworfene_zeilen_zaehlen_nicht_zum_start()
    print("ok")
