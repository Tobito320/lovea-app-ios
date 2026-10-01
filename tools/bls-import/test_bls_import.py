import json
from pathlib import Path
from bls_import import suchschluessel, portionen_fuer

def test_suchschluessel():
    assert suchschluessel("Hühnerei, Eier, gekocht") == "huhnerei eier gekocht"
    assert suchschluessel("Grieß (Weizen)") == "griess weizen"
    assert suchschluessel("Käse,  Gouda 45%") == "kase gouda 45"

def test_portionen_regel_und_alt():
    alt = {"banane ohne schale frisch": [{"name": "Frucht, mittelgroß", "gramm": 150}]}
    regeln = [{"muster": "apfel", "portionen": [{"name": "Frucht, mittelgroß", "gramm": 130}]}]
    assert portionen_fuer("Banane (ohne Schale), frisch", alt, regeln)[0]["gramm"] == 150
    assert portionen_fuer("Apfel, roh", alt, regeln)[0]["gramm"] == 130
    assert portionen_fuer("Zimt, gemahlen", alt, regeln) == []

def test_banane_regel_nur_frisch_oder_gekocht():
    """Die echte Banane-Regel aus portionen.json darf nur frische/gekochte Bananen treffen,
    keine verarbeiteten Formen (sonst bekommt z. B. ein Riegel Bananenchips die Portion einer
    ganzen frischen Banane)."""
    regeln = json.loads((Path(__file__).with_name("portionen.json")).read_text("utf-8"))
    assert portionen_fuer("Bananenchips frittiert, gesüßt", {}, regeln) == []
    assert portionen_fuer("Banane getrocknet", {}, regeln) == []
    assert portionen_fuer("Banane roh", {}, regeln)[0]["gramm"] == 150

if __name__ == "__main__":
    test_suchschluessel(); test_portionen_regel_und_alt(); test_banane_regel_nur_frisch_oder_gekocht()
    print("ok")
