"""Schreibt die festen Formen von Ahmed B und Annika 3 als Swift-Pfade nach
Lovea/Sources/Figuren/GesichterNeuPfade.swift. Aufruf: python swift_export.py (nach python bau.py)."""
import os, re
HIER = os.path.dirname(os.path.abspath(__file__))
ZIEL = os.path.join(HIER, "..", "..", "Lovea", "Sources", "Figuren", "GesichterNeuPfade.swift")

def num(v):
    s = ("%.2f" % float(v)).rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"

def pfad(d):
    toks = re.findall(r"[MLQCZmlqcz]|-?\d*\.?\d+(?:e-?\d+)?", d)
    out, i, cur, start, cmd = [], 0, (0.0, 0.0), (0.0, 0.0), None
    def take(n):
        nonlocal i
        vals = [float(t) for t in toks[i:i + n]]; i += n; return vals
    while i < len(toks):
        t = toks[i]
        if re.match(r"[A-Za-z]", t): cmd = t; i += 1
        rel = cmd.islower(); c = cmd.upper()
        ox, oy = cur if rel else (0.0, 0.0)
        P = lambda x, y: f"P({num(x)}, {num(y)})"
        if c == "M":
            x, y = take(2); cur = (x + ox, y + oy); start = cur
            out.append(f"p.move(to: {P(*cur)})"); cmd = "l" if rel else "L"
        elif c == "L":
            x, y = take(2); cur = (x + ox, y + oy); out.append(f"p.addLine(to: {P(*cur)})")
        elif c == "Q":
            cx, cy, x, y = take(4); ctl = (cx + ox, cy + oy); cur = (x + ox, y + oy)
            out.append(f"p.addQuadCurve(to: {P(*cur)}, control: {P(*ctl)})")
        elif c == "C":
            a, b, c2, d2, x, y = take(6)
            c1 = (a + ox, b + oy); cc = (c2 + ox, d2 + oy); cur = (x + ox, y + oy)
            out.append(f"p.addCurve(to: {P(*cur)}, control1: {P(*c1)}, control2: {P(*cc)})")
        elif c == "Z":
            out.append("p.closeSubpath()"); cur = start
        else: raise ValueError(cmd)
    return "Path { p in\n            " + "\n            ".join(out) + "\n        }"

def elemente(fn):
    s = open(os.path.join(HIER, fn), encoding="utf-8").read()
    res = {}
    for m in re.finditer(r'<g id="([^"]+)"[^>]*>(.*?)\n</g>', s, re.S):
        gid, body = m.groups()
        lst = []
        for e in re.finditer(r'<(path|circle|ellipse)\b([^>]*)/>', body):
            t, a = e.groups()
            at = dict(re.findall(r'([\w-]+)="([^"]*)"', a))
            if t == "path": lst.append(pfad(at["d"]))
            elif t == "circle": lst.append(f'kreis(P({num(at["cx"])}, {num(at["cy"])}), {num(at["r"])})')
            else: lst.append(f'oval(P({num(at["cx"])}, {num(at["cy"])}), {num(at["rx"])}, {num(at["ry"])})')
        res[gid] = lst
    return res

B = elemente("ahmed-B.svg"); A = elemente("annika-3.svg")
# (Name, Gruppe, Index im SVG) - Iris, Pupillen und Glanzpunkte zeichnet der Swift-Code selbst (Blick).
NAMEN_B = [
    ("haarHinten", "hair-back", 0), ("hals", "neck", 0), ("halsSchatten", "neck", 1),
    ("ohrL", "ears", 0), ("ohrR", "ears", 1), ("ohrInnenL", "ears", 2), ("ohrInnenR", "ears", 3),
    ("gesicht", "face-shape", 0), ("ponySchatten", "shading", 0), ("wangeL", "shading", 1), ("wangeR", "shading", 2),
    ("taperL", "taper", 0), ("taperR", "taper", 1), ("kinnbart", "goatee", 0), ("kinnSchatten", "goatee", 1),
    ("augeWeissL", "eyes", 0), ("lidL", "eyes", 4), ("lidStrichL", "eyes", 5), ("lidFalteL", "eyes", 6),
    ("augeWeissR", "eyes", 7), ("lidR", "eyes", 11), ("lidStrichR", "eyes", 12), ("lidFalteR", "eyes", 13),
    ("lachLidL", "eyes-smile", 0), ("lachLidStrichL", "eyes-smile", 1), ("lachLidR", "eyes-smile", 2), ("lachLidStrichR", "eyes-smile", 3),
    ("braueL", "brows", 0), ("braueR", "brows", 1), ("nase", "nose", 0), ("nasenSchatten", "nose", 1),
    ("schnurrbart", "mustache", 0), ("lippeOben", "mouth-neutral", 0), ("lippeUnten", "mouth-neutral", 1),
    ("lachMund", "mouth-smile", 0), ("lachZaehne", "mouth-smile", 1), ("lachZunge", "mouth-smile", 2),
    ("haarVorn", "hair-front", 0),
]
NAMEN_A = [
    ("haarHinten", "hair-back", 0), ("hals", "neck", 0), ("halsSchatten", "neck", 1),
    ("ohr", "ears", 0), ("ohrInnen", "ears", 1),
    ("gesicht", "face-shape", 0), ("wangeL", "shading", 0), ("wangeR", "shading", 1),
    ("augeWeissL", "eyes", 0), ("lidStrichL", "eyes", 5), ("fluegelL", "eyes", 6),
    ("augeWeissR", "eyes", 7), ("lidStrichR", "eyes", 12), ("fluegelR", "eyes", 13),
    ("lachLidL", "eyes-smile", 0), ("lachLidStrichL", "eyes-smile", 1), ("lachLidR", "eyes-smile", 2), ("lachLidStrichR", "eyes-smile", 3),
    ("braueL", "brows", 0), ("braueR", "brows", 1), ("nase", "nose", 0),
    ("lippeOben", "mouth-neutral", 0), ("lippeUnten", "mouth-neutral", 1), ("lippenLinie", "mouth-neutral", 2), ("lippenGlanz", "mouth-neutral", 3),
    ("lachLippeOben", "mouth-smile", 0), ("lachLippeUnten", "mouth-smile", 1), ("lachLinie", "mouth-smile", 2),
    ("lachWinkelL", "mouth-smile", 3), ("lachWinkelR", "mouth-smile", 4),
    ("straehne", "hair-front", 0), ("haarVornL", "hair-front", 1), ("haarVornR", "hair-front", 2),
]

def block(name, doc, quelle, namen, listen):
    z = [f"/// {doc}", f"enum {name} {{"]
    for n, g, i in namen:
        z.append(f"    static var {n}: Path {{\n        {quelle[g][i]}\n    }}")
    for n, (g, von, bis) in listen.items():
        teile = ",\n        ".join(quelle[g][von:bis])
        z.append(f"    static var {n}: [Path] {{\n        [\n        {teile},\n        ]\n    }}")
    z.append("}")
    return "\n".join(z)

kopf = ("// Generated by design/figur-redesign/swift_export.py from ahmed-B.svg and annika-3.svg. Do not edit by hand:\n"
        "// change bau.py, run `python bau.py && python swift_export.py`.\n"
        "// Coordinates are the 200 x 240 half-figure space of FigurView. Colours and gradients live in FigurView.\n\n"
        "import SwiftUI\n\n")
text = kopf + block("GesichtB", "Ahmed, face option B (\"Bitmoji modern schlank\"). Draw order and colours: FigurView `neuesGesichtB`.", B, NAMEN_B,
                    {"lockenGlanz": ("hair-front", 1, 11)}) + "\n\n" + \
       block("GesichtAn3", "Annika, face option 3 (\"Modernes Bitmoji\"). Draw order and colours: FigurView `neuesGesichtAn3`.", A, NAMEN_A,
             {"haarLinien": ("hair-front", 3, 7), "haarGlanz": ("hair-front", 7, 10)}) + "\n"
open(ZIEL, "w", encoding="utf-8", newline="\n").write(text)
print("geschrieben:", os.path.normpath(ZIEL), len(text.splitlines()), "Zeilen")
