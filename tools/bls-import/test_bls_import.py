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

if __name__ == "__main__":
    test_suchschluessel(); test_portionen_regel_und_alt(); print("ok")
