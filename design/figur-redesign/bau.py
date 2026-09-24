# Erzeugt die Kopf-Entwuerfe (SVG je Option) und das Vergleichsboard.
# Raum = Halbfigur der App: 200 x 240, Augenlinie ~y101, Torso = rumpf(0) aus FigurView.swift.
# python bau.py  ->  ahmed-A..E.svg, annika-1..3.svg, gesichter.html
import math, os

HIER = os.path.dirname(os.path.abspath(__file__))

def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
def hx(c): return "%02X%02X%02X" % tuple(max(0, min(255, round(v))) for v in c)
def mal(h, f): return hx(tuple(v * f for v in rgb(h)))
def mix(a, b, t): return hx(tuple(x + (y - x) * t for x, y in zip(rgb(a), rgb(b))))
def kontur(h): return mal(h, 0.55)   # wie FigurFarbe.kontur

TINTE = "3A2630"
ROSE = "FF3B5C"
AH = dict(haut="E8C2A6", haar="241712", iris="3A2418", bart="5C4030", lippe=mix("E8C2A6", "E07A8A", 0.38), top="1C1C1F")
AN = dict(haut="F9D3B8", haar="3B2A20", iris="3F74B5", lippe=mal(mix("F9D3B8", ROSE, 0.4), 0.9), top="2B2830")

def f(v): return ("%.1f" % v).rstrip("0").rstrip(".")
def pt(p): return f(p[0]) + "," + f(p[1])
def M(x): return 200 - x   # Spiegelung an x=100

class Svg:
    """Sammelt Defs und benannte Gruppen. `p` = ID-Praefix, damit mehrere SVGs in einer Seite leben."""
    def __init__(s, p=""):
        s.p, s.defs, s.gruppen = p, [], []
    def id(s, n): return s.p + n
    def lin(s, n, x1, y1, x2, y2, stops):
        st = "".join(f'<stop offset="{o}" stop-color="#{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        s.defs.append(f'<linearGradient id="{s.id(n)}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
        return f"url(#{s.id(n)})"
    def rad(s, n, cx, cy, r, stops):
        st = "".join(f'<stop offset="{o}" stop-color="#{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        s.defs.append(f'<radialGradient id="{s.id(n)}" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="{r}">{st}</radialGradient>')
        return f"url(#{s.id(n)})"
    def clip(s, n, d):
        s.defs.append(f'<clipPath id="{s.id(n)}"><path d="{d}"/></clipPath>')
        return f'clip-path="url(#{s.id(n)})"'
    def g(s, n, inhalt, extra=""):
        s.gruppen.append(f'<g id="{s.id(n)}"{(" " + extra) if extra else ""}>\n{inhalt}\n</g>')
    def text(s, titel):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 240" width="200" height="240">\n'
                f'<title>{titel}</title>\n<defs>{"".join(s.defs)}</defs>\n' + "\n".join(s.gruppen) + "\n</svg>\n")

def fill(d, c, extra=""): return f'<path d="{d}" fill="{c if c.startswith(("url", "#", "none")) else "#" + c}"{extra}/>'
def teil(d, c, breite=3.5, rand=None):
    """Fuellung + Kontur wie `teil()` in Swift."""
    k = rand or kontur(c)
    return f'<path d="{d}" fill="#{c}" stroke="#{k}" stroke-width="{breite}" stroke-linecap="round" stroke-linejoin="round"/>'
def linie(d, c, breite, op=1):
    o = f' stroke-opacity="{op}"' if op != 1 else ""
    return f'<path d="{d}" fill="none" stroke="#{c}" stroke-width="{breite}" stroke-linecap="round" stroke-linejoin="round"{o}/>'
def kreis(x, y, r, c, op=1):
    o = f' fill-opacity="{op}"' if op != 1 else ""
    return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#{c}"{o}/>'

# ---------- gemeinsame Teile ----------

RUMPF = "M30,240 L33,200 C35,178 50,166 72,164 L86,161 Q100,178 114,161 L128,164 C150,166 165,178 167,200 L170,240 Z"
HALS = "M88,128 L87,176 L113,176 L112,128 Z"

def ohren(haut, rand, breite=3.5, dx=0):
    # Mitte (51|104) und (149|104); alte App: (42|100) und (158|100)
    l = f"M{56+dx},93 C{47+dx},87 {41+dx},97 {43+dx},107 C{45+dx},116 {51+dx},121 {57+dx},117 Z"
    r = f"M{M(56+dx)},93 C{M(47+dx)},87 {M(41+dx)},97 {M(43+dx)},107 C{M(45+dx)},116 {M(51+dx)},121 {M(57+dx)},117 Z"
    innen = f"M{52+dx},97 C{47+dx},99 {47+dx},108 {52+dx},111"
    innen_r = f"M{M(52+dx)},97 C{M(47+dx)},99 {M(47+dx)},108 {M(52+dx)},111"
    k = rand or kontur(haut)
    return teil(l, haut, breite, k) + teil(r, haut, breite, k) + linie(innen, k, 1.6, 0.6) + linie(innen_r, k, 1.6, 0.6)

def wolke(punkte, mitte, beule, spitz=False, haken=0.0):
    """Geschlossener Pfad durch `punkte`; zwischen zwei Punkten eine Locke, die von `mitte` weg zeigt."""
    d = "M" + pt(punkte[0])
    n = len(punkte)
    for i in range(n):
        a, b = punkte[i], punkte[(i + 1) % n]
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        vx, vy = mx - mitte[0], my - mitte[1]
        l = math.hypot(vx, vy) or 1
        nx, ny = vx / l, vy / l
        tx, ty = b[0] - a[0], b[1] - a[1]
        bb = beule if isinstance(beule, (int, float)) else beule[i]
        if spitz:
            tip = (mx + nx * bb * 1.25 + tx * haken, my + ny * bb * 1.25 + ty * haken)
            c1 = ((a[0] + tip[0]) / 2 + nx * bb * 0.45, (a[1] + tip[1]) / 2 + ny * bb * 0.45)
            c2 = ((tip[0] + b[0]) / 2 - nx * bb * 0.1, (tip[1] + b[1]) / 2 - ny * bb * 0.1)
            d += f" Q{pt(c1)} {pt(tip)} Q{pt(c2)} {pt(b)}"
        else:
            c = (mx + nx * bb * 2 + tx * haken, my + ny * bb * 2 + ty * haken)
            d += f" Q{pt(c)} {pt(b)}"
    return d + " Z"

# Ahmeds Locken: Aussenkontur (links -> ueber den Kopf -> rechts), dann Pony-Kante (rechts -> links).
AH_AUSSEN = [(51, 82), (46, 70), (45, 56), (50, 42), (59, 31), (71, 23), (86, 18), (102, 16), (118, 18), (132, 23), (144, 32), (151, 44), (155, 58), (154, 71), (149, 82)]
# Pony faellt schraeg: links (Bildseite) hoeher, rechts bis fast auf die Braue, wie auf seinen Fotos.
AH_PONY = [(146, 81), (138, 85), (128, 79), (119, 82), (110, 74), (101, 77), (92, 70), (83, 73), (74, 68), (65, 72), (57, 74)]

def beulen(n, b, spiel=1.0):
    """Unterschiedlich grosse Locken, damit die Wolke nicht wie ein Helm aussieht."""
    return [b + spiel * ((i * 7) % 3 - 1) for i in range(n)]

def pony_schatten(s, farbe, clip, op=0.55, dy=5):
    """Schatten des Ponys auf der Stirn: gleiche Kante, nach unten versetzt."""
    d = wolke(AH_AUSSEN + [(x, y + dy) for x, y in AH_PONY], (100, 58), 4)
    return f'<g {clip}>' + fill(d, farbe, f' fill-opacity="{op}"') + '</g>'

def taper(s, haar, haut, name):
    """Kurze Seiten: Haarfarbe laeuft ueber dem Ohr in die Haut aus."""
    grad = s.lin(name, 0, 78, 0, 104, [(0, haar, 0.95), (0.55, haar, 0.55), (1, haar, 0.05)])
    l = "M47,80 C46,88 47,96 51,101 L57,100 C56,94 56,87 59,81 Z"
    r = f"M{M(47)},80 C{M(46)},88 {M(47)},96 {M(51)},101 L{M(57)},100 C{M(56)},94 {M(56)},87 {M(59)},81 Z"
    return fill(l, grad) + fill(r, grad)

def hals_und_rumpf(s, haut, top, rand_haut=None, rand_top=None, breite=3.5):
    h = teil(HALS, haut, breite, rand_haut)
    kinn_schatten = s.lin("halsSchatten", 0, 140, 0, 166, [(0, mal(haut, 0.78), 0.9), (1, mal(haut, 0.78), 0)])
    cl = s.clip("halsClip", HALS)
    h += f'<g {cl}>' + fill("M80,128 L120,128 L120,150 Q100,166 80,150 Z", kinn_schatten) + '</g>'
    s.g("neck", h)
    s.g("torso-hint", teil(RUMPF, top, breite, rand_top) + linie("M86,161 Q100,178 114,161", rand_top or kontur(top), 2, 0.5))

def lippenmund(d_oben, d_unten, farbe, rand, breite=1.6):
    return teil(d_oben, mal(farbe, 0.9), breite, rand) + teil(d_unten, farbe, breite, rand)

def smile_lid(cx, cy, s_, breite, haut, rand, y0=6, clip=""):
    """Unteres Lid schiebt beim Laecheln hoch (froh, aber offen)."""
    a, b = cx - breite, cx + breite
    d = f"M{f(a-2)},{f(cy+y0)} Q{f(cx)},{f(cy-1)} {f(b+2)},{f(cy+y0-1)} L{f(b+2)},{f(cy+14)} L{f(a-2)},{f(cy+14)} Z"
    return f'<g {clip}>' + fill(d, haut) + '</g>' + linie(f"M{f(a+1)},{f(cy+y0-1)} Q{f(cx)},{f(cy)} {f(b-1)},{f(cy+y0-1.5)}", rand, 1.4, 0.55)

# ---------- Ahmed A: clean anime ----------

def auge_mandel(cx, cy, sd, innen=9, aussen=11, oben=12, unten=8, kipp=2):
    """Mandelform: innerer Winkel, oberer Bogen, aeusserer Winkel (leicht hoeher), unterer Bogen."""
    i, o = cx - sd * innen, cx + sd * aussen
    return f"M{f(i)},{f(cy+1)} Q{f(cx)},{f(cy-oben)} {f(o)},{f(cy-kipp)} Q{f(cx+sd*1)},{f(cy+unten)} {f(i)},{f(cy+1)} Z", i, o

def ahmed_A(p=""):
    s = Svg(p); c = AH; haut, haar = c["haut"], c["haar"]
    rh = kontur(haut)
    gesicht = "M100,26 C127,26 147,44 147,78 C147,100 144,115 137,127 L113,147 Q100,155 87,147 L63,127 C56,115 53,100 53,78 C53,44 73,26 100,26 Z"
    n = len(AH_AUSSEN)
    s.g("hair-back", fill(wolke(AH_AUSSEN + [(150, 94), (50, 94)], (100, 60), beulen(n + 2, 4.5), True, 0.2), haar))
    hals_und_rumpf(s, haut, c["top"], breite=3)
    s.g("ears", ohren(haut, rh, 3))
    s.g("face-shape", teil(gesicht, haut, 3, rh))
    cl = s.clip("gesichtClip", gesicht)
    sch = mal(haut, 0.88)
    # Cel-Schatten: Pony-Schatten auf der Stirn + harte Flaeche an der rechten Wange
    s.g("shading", pony_schatten(s, sch, cl, 0.9) + f'<g {cl}>' + fill("M147,92 L140,126 L116,146 Q134,122 141,92 Z", sch) + '</g>')
    s.g("jaw", f'<g {cl}>' + linie("M67,130 L86,145", rh, 1.2, 0.3) + linie(f"M{M(67)},130 L{M(86)},145", rh, 1.2, 0.3) + '</g>')
    s.g("taper", taper(s, haar, haut, "taperA"))
    s.g("goatee", f'<g {cl}>' + fill("M96.5,142.5 Q100,141.5 103.5,142.5 L101.5,147 Q100,148 98.5,147 Z", c["bart"], ' fill-opacity="0.55"')
        + fill("M88,148 Q100,145 112,148 L112,158 L88,158 Z", c["bart"], ' fill-opacity="0.13"') + '</g>')
    augen, smile = "", ""
    for sd in (-1, 1):
        cx, cy = 100 + sd * 19, 101
        weiss, i, o = auge_mandel(cx, cy, sd, 9, 10.5, 12, 8, 2)
        ecl = s.clip(f"augeA{sd}", weiss)
        ir = s.lin(f"irisA{sd}", 0, cy - 7, 0, cy + 7, [(0, mal(c["iris"], 0.55), 1), (1, mix(c["iris"], "B07A4A", 0.55), 1)])
        augen += fill(weiss, "FFFFFF") + f'<g {ecl}>' + fill(f"M{f(i)},{cy-8} L{f(o)},{cy-8} L{f(o)},{cy-3} Q{f(cx)},{cy-7} {f(i)},{cy-1} Z", "E6E0E4")
        augen += f'<ellipse cx="{f(cx+sd*0.5)}" cy="{cy+0.5}" rx="5.2" ry="6.6" fill="{ir}"/>' + kreis(cx + sd * 0.5, cy + 1, 2.6, "1A1016")
        augen += kreis(cx - 1.8 + sd * 0.5, cy - 2.2, 1.8, "FFFFFF") + kreis(cx + 2 + sd * 0.5, cy + 3.4, 0.9, "FFFFFF", 0.8) + '</g>'
        # dicke obere Wimpernlinie, aussen mit kleinem Flick; kurzer unterer Strich nur aussen
        augen += linie(f"M{f(i-sd*0.5)},{cy+0.5} Q{f(cx)},{cy-11.5} {f(o+sd*0.5)},{cy-2.5}", TINTE, 3.6)
        smile += smile_lid(cx, cy, sd, 10, haut, rh, 6.5, s.clip(f"augeAs{sd}", weiss))
    s.g("eyes", augen)
    s.g("eyes-smile", smile, 'display="none"')
    s.g("brows", "".join(fill(f"M{f(100+sd*8)},88.5 Q{f(100+sd*18)},84 {f(100+sd*31)},85.5 L{f(100+sd*31)},87 Q{f(100+sd*18)},87.5 {f(100+sd*8.5)},92 Z", mal(haar, 1.1)) for sd in (-1, 1)))
    s.g("nose", fill("M102.5,100 L106,121.5 L101,123.5 Q104.5,117 102.5,100 Z", mal(haut, 0.84)) + linie("M99.5,123.5 L105.5,121.8", rh, 1.8))
    s.g("mustache", fill("M100,129.5 C95,127.5 88,128 84,133 C89,131 95,131.5 100,132 C105,131.5 111,131 116,133 C112,128 105,127.5 100,129.5 Z", c["bart"]))
    s.g("mouth-neutral", linie("M92.5,137.2 Q100,138.8 107.5,137", mal(TINTE, 1.1), 2) + fill("M95,139.5 Q100,142 105,139.5 Q100,141 95,139.5 Z", c["lippe"]))
    s.g("mouth-smile", fill("M90,135.5 Q100,138.5 110,135.5 Q108,146 100,146.5 Q92,146 90,135.5 Z", "6B2335") + fill("M92,136.5 Q100,139 108,136.5 L107,138.6 Q100,140.6 93,138.6 Z", "FFFFFF") + fill("M95,144 Q100,141.5 105,144 Q100,146.5 95,144 Z", "F07A8A") + linie("M90,135.5 Q100,138.5 110,135.5", TINTE, 1.6), 'display="none"')
    front = wolke(AH_AUSSEN + AH_PONY, (100, 58), beulen(n + len(AH_PONY), 4.3), True, 0.2)
    glanz = mix(haar, "8C7B8C", 0.55)
    s.g("hair-front", teil(front, haar, 3, mal(haar, 0.6)) + linie("M64,42 Q76,30 94,28", glanz, 3, 0.8) + linie("M112,27 Q128,29 138,40", glanz, 3, 0.8)
        + "".join(linie(d, "0A0606", 1.6, 0.8) for d in ["M70,56 Q74,64 68,70", "M96,52 Q101,62 94,72", "M122,52 Q127,64 121,76", "M142,58 Q145,68 140,78"]))
    return s

# ---------- Ahmed B: Bitmoji modern slim ----------

def ahmed_B(p=""):
    s = Svg(p); c = AH; haut, haar = c["haut"], c["haar"]
    rh = kontur(haut)
    gesicht = "M100,26 C127,26 147,44 147,77 C147,100 145,117 139,129 C132,142 117,150 100,151 C83,150 68,142 61,129 C55,117 53,100 53,77 C53,44 73,26 100,26 Z"
    n = len(AH_AUSSEN)
    s.g("hair-back", teil(wolke(AH_AUSSEN + [(150, 94), (50, 94)], (100, 60), beulen(n + 2, 3.8)), haar))
    hals_und_rumpf(s, haut, c["top"])
    s.g("ears", ohren(haut, rh))
    weich = s.rad("hautB", 96, 92, 72, [(0.55, haut, 1), (1, mal(haut, 0.9), 1)])
    s.g("face-shape", f'<path d="{gesicht}" fill="{weich}" stroke="#{rh}" stroke-width="3.5" stroke-linejoin="round"/>')
    cl = s.clip("gesichtClip", gesicht)
    wl = s.rad("wlB", 62, 122, 14, [(0, mal(haut, 0.84), 0.7), (1, mal(haut, 0.84), 0)])
    wr = s.rad("wrB", 138, 122, 14, [(0, mal(haut, 0.84), 0.7), (1, mal(haut, 0.84), 0)])
    s.g("shading", pony_schatten(s, mal(haut, 0.88), cl, 0.6) + f'<g {cl}><ellipse cx="62" cy="122" rx="10" ry="15" fill="{wl}"/><ellipse cx="138" cy="122" rx="10" ry="15" fill="{wr}"/></g>')
    s.g("jaw", "")
    s.g("taper", taper(s, haar, haut, "taperB"))
    s.g("goatee", f'<g {cl}>' + fill("M96,143 Q100,142 104,143 Q103.5,148 100,148.5 Q96.5,148 96,143 Z", c["bart"], ' fill-opacity="0.45"')
        + fill("M86,149 Q100,145 114,149 L114,158 L86,158 Z", c["bart"], ' fill-opacity="0.14"') + '</g>')
    augen, smile = "", ""
    for sd in (-1, 1):
        cx, cy = 100 + sd * 19, 101
        weiss, i, o = auge_mandel(cx, cy, sd, 10, 11, 13, 9, 1.5)
        ecl = s.clip(f"augeB{sd}", weiss)
        lid = f"M{f(i-2)},{cy-9} L{f(o+2)},{cy-9} L{f(o+2)},{cy-1.5} Q{f(cx)},{cy-8} {f(i-2)},{cy+0.5} Z"
        augen += fill(weiss, "FFFFFF") + f'<g {ecl}>' + kreis(cx + sd * 0.5, cy + 0.8, 5.4, c["iris"]) + kreis(cx + sd * 0.5, cy + 0.8, 2.6, mal(TINTE, 0.7)) + kreis(cx - 1.6, cy - 1.2, 1.6, "FFFFFF") + fill(lid, haut) + '</g>'
        augen += linie(f"M{f(i)},{cy+0.5} Q{f(cx)},{cy-8} {f(o)},{cy-1.5}", TINTE, 3)
        augen += linie(f"M{f(i+sd*2)},{cy-5.5} Q{f(cx)},{cy-12} {f(o-sd*1)},{cy-5}", rh, 1.3, 0.5)
        smile += smile_lid(cx, cy, sd, 10, haut, rh, 6, s.clip(f"augeBs{sd}", weiss))
    s.g("eyes", augen)
    s.g("eyes-smile", smile, 'display="none"')
    s.g("brows", "".join(linie(f"M{f(100+sd*8)},88.5 Q{f(100+sd*19)},85 {f(100+sd*30)},86.5", mal(haar, 1.2), 4.4) for sd in (-1, 1)))
    s.g("nose", linie("M102,103 L104.5,120 Q103,124.5 98,123.5", rh, 2.4) + f'<ellipse cx="100" cy="125" rx="6" ry="2" fill="#{mal(haut,0.85)}" fill-opacity="0.6"/>')
    s.g("mustache", teil("M100,129.5 C95,127.5 88,128 84,133.5 C89,131 95,131.5 100,132.2 C105,131.5 111,131 116,133.5 C112,128 105,127.5 100,129.5 Z", c["bart"], 1.2))
    lo = "M90,137.5 Q95,134.5 100,136 Q105,134.5 110,137.5 Q100,139 90,137.5 Z"
    lu = "M90,137.5 Q100,139 110,137.5 Q106,143.5 100,143.5 Q94,143.5 90,137.5 Z"
    s.g("mouth-neutral", lippenmund(lo, lu, c["lippe"], mal(c["lippe"], 0.6)))
    s.g("mouth-smile", teil("M88,135.5 Q100,139 112,135.5 Q109,146 100,146 Q91,146 88,135.5 Z", "6B2335", 1.6, mal(c["lippe"], 0.5)) + fill("M90,136.5 Q100,139.5 110,136.5 L109,139 Q100,141.5 91,139 Z", "FFFFFF") + fill("M94,144 Q100,141.5 106,144 Q100,146.5 94,144 Z", "F07A8A"), 'display="none"')
    front = wolke(AH_AUSSEN + AH_PONY, (100, 58), beulen(n + len(AH_PONY), 4.2))
    ton = mix(haar, "FFFFFF", 0.16)
    locken = "".join(linie(d, ton, 2.2, 0.9) for d in ["M60,44 q6,-8 14,-6", "M84,28 q8,-6 16,-3", "M112,26 q9,-2 15,4", "M138,42 q6,5 6,12", "M70,58 q3,6 -1,10", "M94,54 q5,6 1,12", "M118,56 q5,6 1,12", "M140,62 q3,6 -1,11", "M78,44 q5,-5 11,-3", "M122,44 q6,-2 10,3"])
    s.g("hair-front", teil(front, haar, 3.5) + locken)
    return s

# ---------- Ahmed C: semi-realistisch flach ----------

def ahmed_C(p=""):
    s = Svg(p); c = AH; haut, haar = c["haut"], c["haar"]
    rh = mal(haut, 0.7)
    gesicht = "M100,26 C127,26 146,44 146,78 C146,98 145,113 141,125 C138,135 128,144 114,149 Q100,153 86,149 C72,144 62,135 59,125 C55,113 54,98 54,78 C54,44 73,26 100,26 Z"
    n = len(AH_AUSSEN)
    s.g("hair-back", fill(wolke(AH_AUSSEN + [(150, 94), (50, 94)], (100, 60), beulen(n + 2, 3.4)), mal(haar, 0.8)))
    hals_und_rumpf(s, haut, c["top"], rh, None, 2)
    s.g("ears", ohren(haut, rh, 2))
    s.g("face-shape", teil(gesicht, haut, 2, rh))
    cl = s.clip("gesichtClip", gesicht)
    seite = s.lin("seiteC", 118, 0, 146, 0, [(0, mal(haut, 0.8), 0), (1, mal(haut, 0.8), 0.45)])
    s.g("shading", pony_schatten(s, mal(haut, 0.86), cl, 0.55, 4) + f'<g {cl}>'
        + fill("M100,20 L160,20 L160,170 L100,170 Z", seite)                                                     # Licht von links
        + f'<ellipse cx="81" cy="98" rx="12" ry="6" fill="{s.rad("hoeleL", 81, 98, 12, [(0, mal(haut, 0.85), 0.5), (1, mal(haut, 0.85), 0)])}"/>'
        + f'<ellipse cx="119" cy="98" rx="12" ry="6" fill="{s.rad("hoeleR", 119, 98, 12, [(0, mal(haut, 0.85), 0.5), (1, mal(haut, 0.85), 0)])}"/>'
        + fill("M62,114 Q70,126 82,130 Q70,131 61,122 Z", mal(haut, 0.88), ' fill-opacity="0.6"')              # Wangenhoehle
        + fill(f"M{M(62)},114 Q{M(70)},126 {M(82)},130 Q{M(70)},131 {M(61)},122 Z", mal(haut, 0.84), ' fill-opacity="0.7"')
        + fill("M94,145 Q100,143.5 106,145 Q100,147 94,145 Z", mal(haut, 0.8), ' fill-opacity="0.6"')          # unter der Unterlippe
        + '</g>')
    s.g("jaw", f'<g {cl}>' + linie("M61,126 C67,138 77,145 89,149", rh, 1.3, 0.45) + linie(f"M{M(61)},126 C{M(67)},138 {M(77)},145 {M(89)},149", rh, 1.3, 0.3) + '</g>')
    s.g("taper", taper(s, haar, haut, "taperC"))
    s.g("goatee", f'<g {cl}>' + fill("M96,145.5 Q100,144.5 104,145.5 L102.5,150 Q100,151 97.5,150 Z", c["bart"], ' fill-opacity="0.45"')
        + fill("M72,136 Q100,158 128,136 L128,160 L72,160 Z", c["bart"], ' fill-opacity="0.08"') + '</g>')
    augen, smile = "", ""
    for sd in (-1, 1):
        cx, cy = 100 + sd * 19, 102
        weiss, i, o = auge_mandel(cx, cy, sd, 9, 10, 10.5, 7.5, 1.5)
        ecl = s.clip(f"augeC{sd}", weiss)
        augen += fill(weiss, "F6F0EA") + f'<g {ecl}>' + kreis(cx, cy + 0.3, 4.7, mix(c["iris"], "8A5A35", 0.45)) + kreis(cx, cy + 0.3, 2.1, "1A1010") + kreis(cx - 1.5, cy - 1.3, 1.1, "FFFFFF", 0.95)
        augen += fill(f"M{f(i-2)},{cy-9} L{f(o+2)},{cy-9} L{f(o+2)},{cy-1.8} Q{f(cx)},{cy-6} {f(i-2)},{cy+0.3} Z", mal(haut, 0.92)) + '</g>'   # schweres Oberlid
        augen += linie(f"M{f(i)},{cy+0.6} Q{f(cx)},{cy-6.2} {f(o+sd*0.5)},{cy-1.6}", "2A1A18", 2.4)
        augen += linie(f"M{f(i+sd*1)},{cy-4.8} Q{f(cx)},{cy-10} {f(o-sd*0.5)},{cy-4.6}", mal(haut, 0.62), 1.3)              # Lidfalte
        augen += linie(f"M{f(i+sd*3)},{cy+3.2} Q{f(cx+sd*1)},{cy+4.8} {f(o-sd*1.5)},{cy+1.2}", mal(haut, 0.66), 1, 0.6)     # Unterlid
        smile += smile_lid(cx, cy, sd, 9, haut, mal(haut, 0.6), 4.5, s.clip(f"augeCs{sd}", weiss))
    s.g("eyes", augen)
    s.g("eyes-smile", smile, 'display="none"')
    s.g("brows", "".join(fill(f"M{f(100+sd*6)},91 C{f(100+sd*10)},86.5 {f(100+sd*22)},85.5 {f(100+sd*31)},88 C{f(100+sd*22)},88 {f(100+sd*12)},89.5 {f(100+sd*7)},93.5 Z", mal(haar, 1.35)) for sd in (-1, 1)))
    s.g("nose", fill("M102.5,98 C103.5,106 105,114 107.5,121 C104,120 102,110 101,98 Z", mal(haut, 0.82))
        + linie("M95,121.5 Q96.5,125.5 100,125 Q103.5,125.5 105,121.5", mal(haut, 0.6), 1.6)
        + linie("M95.5,118.5 Q92.5,121.5 95.5,124", mal(haut, 0.6), 1.4) + linie("M104.5,118.5 Q107.5,121.5 104.5,124", mal(haut, 0.6), 1.4)
        + f'<ellipse cx="100.5" cy="118.5" rx="2.2" ry="1.6" fill="#FFFFFF" fill-opacity="0.4"/>')
    bart = c["bart"]
    s.g("mustache", fill("M100,129 C94,127 87,128 83.5,134 C88,131 94,131.5 100,132 C106,131.5 112,131 116.5,134 C113,128 106,127 100,129 Z", bart)
        + "".join(linie(d, mal(bart, 0.65), 0.8, 0.7) for d in ["M88,130.3 L86.3,133", "M93,129.2 L92,131.5", "M107,129.2 L108,131.5", "M112,130.3 L113.7,133"]))
    lip = c["lippe"]
    lo = "M89,137 Q94,134.5 100,135.8 Q106,134.5 111,137 Q100,138 89,137 Z"
    lu = "M89,137 Q100,138 111,137 Q107,143 100,143 Q93,143 89,137 Z"
    s.g("mouth-neutral", fill(lo, mal(lip, 0.82)) + fill(lu, lip) + linie("M89,137 Q100,138.4 111,137", mal(lip, 0.5), 1.3) + f'<ellipse cx="101" cy="140" rx="4" ry="1.1" fill="#FFFFFF" fill-opacity="0.35"/>')
    s.g("mouth-smile", fill("M88,136 Q100,139 112,135.5 Q108,144 100,144.5 Q92,144 88,136 Z", "5A2230") + fill("M90,136.5 Q100,139 110,136.2 L109,138.8 Q100,141 91,138.8 Z", "F4EEE8")
        + linie("M88,136 Q100,139 112,135.5", mal(lip, 0.5), 1.4) + linie("M85,133 Q87,136 88.5,137.5", mal(haut, 0.66), 1.2) + linie("M115,133 Q113,136 111.5,137.5", mal(haut, 0.66), 1.2), 'display="none"')
    s.g("moles", kreis(70, 118, 1.2, mal(haut, 0.45), 0.8) + kreis(131, 126, 1, mal(haut, 0.45), 0.8) + kreis(78, 131, 0.9, mal(haut, 0.45), 0.7))
    front = wolke(AH_AUSSEN + AH_PONY, (100, 58), beulen(n + len(AH_PONY), 3.6, 1.3))
    hell, tief = mix(haar, "9A7A66", 0.45), "0C0707"
    # Locken als einzelne Schwuenge: helle Oberkante, dunkle Unterkante
    locken = [(62, 44), (78, 32), (96, 26), (114, 27), (132, 34), (144, 48), (70, 58), (88, 50), (106, 48), (124, 52), (140, 64), (80, 66), (116, 66)]
    tex = "".join(linie(f"M{x-6},{y+2} Q{x},{y-5} {x+6},{y+1}", hell, 2, 0.75) + linie(f"M{x+6},{y+1} Q{x+4},{y+7} {x-1},{y+7}", tief, 1.4, 0.7) for x, y in locken)
    s.g("hair-front", teil(front, haar, 2, mal(haar, 0.6)) + tex)
    return s

# ---------- Ahmed D: Sticker-Stil (wie design/ki/sticker) ----------

STK = "2A1C18"

def ahmed_D(p=""):
    s = Svg(p); c = AH; haut, haar = c["haut"], c["haar"]
    gesicht = "M100,26 C128,26 148,44 148,80 C148,105 142,123 131,137 C122,147 111,151 100,151 C89,151 78,147 69,137 C58,123 52,105 52,80 C52,44 72,26 100,26 Z"
    n = len(AH_AUSSEN)
    back = wolke(AH_AUSSEN + [(150, 94), (50, 94)], (100, 60), beulen(n + 2, 4.2), False, 0.12)
    front = wolke(AH_AUSSEN + AH_PONY, (100, 58), beulen(n + len(AH_PONY), 4.4), False, 0.12)
    rand = "".join(f'<path d="{d}" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="12" stroke-linejoin="round"/>' for d in [back, RUMPF, gesicht, front])
    s.g("sticker-border", rand)
    s.g("hair-back", teil(back, haar, 3.8, STK))
    hals_und_rumpf(s, haut, c["top"], STK, STK, 3.8)
    s.g("ears", ohren(haut, STK, 3.4, 1))
    warm = s.rad("hautD", 100, 96, 70, [(0.5, haut, 1), (1, mix(haut, "D89A80", 0.35), 1)])
    s.g("face-shape", f'<path d="{gesicht}" fill="{warm}" stroke="#{STK}" stroke-width="3.8" stroke-linejoin="round"/>')
    cl = s.clip("gesichtClip", gesicht)
    s.g("shading", pony_schatten(s, mal(haut, 0.86), cl, 0.6) + f'<g {cl}>'
        + f'<ellipse cx="69" cy="119" rx="9" ry="5" fill="{s.rad("wlD", 69, 119, 9, [(0, "F08A8A", 0.22), (1, "F08A8A", 0)])}"/>'
        + f'<ellipse cx="131" cy="119" rx="9" ry="5" fill="{s.rad("wrD", 131, 119, 9, [(0, "F08A8A", 0.22), (1, "F08A8A", 0)])}"/>' + '</g>')
    s.g("jaw", "")
    s.g("taper", taper(s, haar, haut, "taperD"))
    s.g("goatee", f'<g {cl}>' + fill("M93,144 Q100,142 107,144 Q106,151 100,152 Q94,151 93,144 Z", haar, ' fill-opacity="0.22"') + '</g>')
    augen = ""
    for sd in (-1, 1):
        cx, cy = 100 + sd * 19, 102
        o, i = cx + sd * 10, cx - sd * 9
        form = f"M{f(i)},{cy} Q{f(cx)},{cy-9} {f(o)},{cy-2} Q{f(cx+sd*1)},{cy+7} {f(i)},{cy} Z"
        ecl = s.clip(f"augeD{sd}", form)
        augen += fill(form, "FFFFFF") + f'<g {ecl}>' + f'<ellipse cx="{f(cx+sd*0.5)}" cy="{cy+0.5}" rx="6" ry="6.8" fill="#{mal(c["iris"],0.9)}"/>' + kreis(cx + sd * 0.5, cy + 1, 3, "140C0A")
        augen += kreis(cx - 2 + sd * 0.5, cy - 2, 2, "FFFFFF") + kreis(cx + 2 + sd * 0.5, cy + 3, 1, "FFFFFF", 0.85) + '</g>'
        augen += linie(f"M{f(i-sd*0.5)},{cy} Q{f(cx)},{cy-9.5} {f(o+sd*0.5)},{cy-2}", STK, 3.4)
    s.g("eyes", augen)
    s.g("eyes-smile", "".join(linie(f"M{f(100+sd*19-9)},{104} Q{f(100+sd*19)},{95} {f(100+sd*19+9)},{104}", STK, 3.4) for sd in (-1, 1)), 'display="none" data-replaces="eyes"')
    s.g("brows", "".join(linie(f"M{f(100+sd*9)},90 Q{f(100+sd*19)},86.5 {f(100+sd*28)},88", STK, 4.2) for sd in (-1, 1)))
    s.g("nose", linie("M102,110 Q106,120 101,123", STK, 2.4) + linie("M97,122.5 Q98.5,124 100,123.5", STK, 1.8))
    s.g("mustache", teil("M100,129.2 C95,127 88,128 84,133.5 Q86.5,132 88,132.5 C93,131 96.5,131.5 100,132.2 C103.5,131.5 107,131 112,132.5 Q113.5,132 116,133.5 C112,128 105,127 100,129.2 Z", "3A2A22", 1.4, STK))
    s.g("mouth-neutral", linie("M94,138.6 Q100,140.6 106,138.2", STK, 2.6) + fill("M95,141.5 Q100,143.5 105,141.5 Q100,142.8 95,141.5 Z", mix(haut, "E07A7A", 0.4)))
    s.g("mouth-smile", teil("M89,136.5 Q100,140 111,136.5 Q109,148 100,148 Q91,148 89,136.5 Z", "7A2A36", 3, STK) + fill("M91.5,138 Q100,140.5 108.5,138 L108,140 Q100,142 92,140 Z", "FFFFFF") + fill("M94,145.5 Q100,142 106,145.5 Q100,148 94,145.5 Z", "F0707E"), 'display="none"')
    glanz = "6E6878"
    s.g("hair-front", teil(front, haar, 3.8, STK)
        + "".join(linie(d, glanz, 2.6, 0.9) for d in ["M64,40 Q74,28 90,24", "M108,21 Q122,22 132,31", "M140,46 Q146,54 146,62"])
        + "".join(linie(d, "000000", 1.8, 0.6) for d in ["M76,56 q6,8 0,18", "M98,52 q6,10 -2,22", "M120,54 q6,9 0,18", "M140,60 q4,8 -2,14", "M62,60 q-2,8 2,14"]))
    return s

# ---------- Ahmed E: scharf / cool ----------

def ahmed_E(p=""):
    s = Svg(p); c = AH; haut, haar = c["haut"], c["haar"]
    rh = mal(haut, 0.5)
    gesicht = "M100,26 C127,26 147,42 147,76 L145.5,108 L137,131 L113,149 L87,149 L63,131 L54.5,108 L53,76 C53,42 73,26 100,26 Z"
    n = len(AH_AUSSEN)
    s.g("hair-back", fill(wolke(AH_AUSSEN + [(150, 94), (50, 94)], (100, 60), beulen(n + 2, 4.3), True, 0.3), haar))
    hals_und_rumpf(s, haut, c["top"], rh, None, 3)
    s.g("ears", ohren(haut, rh, 3))
    s.g("face-shape", teil(gesicht, haut, 3, rh))
    cl = s.clip("gesichtClip", gesicht)
    sch = mal(haut, 0.87)
    s.g("shading", pony_schatten(s, sch, cl, 0.85, 4) + f'<g {cl}>'
        + fill("M146,98 L137,131 L113,149 L127,131 L138,108 Z", sch)
        + fill("M58,112 L80,124 L63,129 Z", sch, ' fill-opacity="0.75"') + fill(f"M{M(58)},112 L{M(80)},124 L{M(63)},129 Z", sch) + '</g>')
    s.g("jaw", f'<g {cl}>' + linie("M64,131 L87,148", rh, 1.4, 0.4) + linie(f"M{M(64)},131 L{M(87)},148", rh, 1.4, 0.4) + '</g>')
    s.g("taper", taper(s, haar, haut, "taperE"))
    s.g("goatee", f'<g {cl}>' + fill("M96.5,143 L103.5,143 L102,148.5 L98,148.5 Z", c["bart"], ' fill-opacity="0.5"')
        + fill("M87,148.5 L113,148.5 L113,156 L87,156 Z", c["bart"], ' fill-opacity="0.14"') + '</g>')
    augen, smile = "", ""
    for sd in (-1, 1):
        cx, cy = 100 + sd * 19, 102
        o, i = cx + sd * 10.5, cx - sd * 9
        form = f"M{f(i)},{cy+0.5} L{f(cx-sd*2)},{cy-5.5} L{f(o)},{cy-3} Q{f(cx+sd*2)},{cy+5} {f(i)},{cy+0.5} Z"
        ecl = s.clip(f"augeE{sd}", form)
        augen += fill(form, "F7F2EC") + f'<g {ecl}>' + kreis(cx + sd * 0.5, cy - 0.3, 4.8, mix(c["iris"], "6A4020", 0.35)) + kreis(cx + sd * 0.5, cy - 0.3, 2.2, "140C0A") + kreis(cx - 1.4, cy - 2, 1.2, "FFFFFF") + '</g>'
        augen += linie(f"M{f(i-sd*0.5)},{cy+0.6} L{f(cx-sd*2)},{cy-5.8} L{f(o+sd*1)},{cy-3.2}", "1E1418", 3.2)
        augen += linie(f"M{f(i+sd*4)},{cy+3.4} L{f(o-sd*1)},{cy+0.6}", rh, 1.1, 0.55)
        smile += smile_lid(cx, cy, sd, 9.5, haut, rh, 4, s.clip(f"augeEs{sd}", form))
    s.g("eyes", augen)
    s.g("eyes-smile", smile, 'display="none"')
    # gerade, kraeftige Brauen, innen kaum tiefer: ruhig, nicht boese
    s.g("brows", "".join(fill(f"M{f(100+sd*7)},90.5 L{f(100+sd*9)},87 L{f(100+sd*31)},86 L{f(100+sd*30.5)},89 L{f(100+sd*10)},91.5 Z", mal(haar, 1.1)) for sd in (-1, 1)))
    s.g("nose", linie("M101.5,96 L104.5,119 L100,123.5 L96.5,121.5", rh, 2.2) + fill("M102,99 L104.5,119 L106.5,118 Z", mal(haut, 0.84)))
    # gestylter Schnurrbart: schmal, Enden leicht nach oben
    s.g("mustache", fill("M100,129 C95,127 89,127.5 85.5,131 Q83.5,132.5 82,131 Q83,134.5 87,133.3 C91,131.6 95,131.6 100,132 C105,131.6 109,131.6 113,133.3 Q117,134.5 118,131 Q116.5,132.5 114.5,131 C111,127.5 105,127 100,129 Z", mal(c["bart"], 0.9)))
    s.g("mouth-neutral", linie("M93.5,137.8 Q100,138.6 106.5,137.4", "3A2226", 2) + fill("M95.5,140 Q100,142.2 104.5,140 Q100,141.2 95.5,140 Z", mal(c["lippe"], 0.95)))
    s.g("mouth-smile", linie("M92,137.5 Q100,140.5 108.5,135.8", "3A2226", 2.2) + linie("M108,134.6 Q110.3,135.6 109.8,137.8", rh, 1.2) + fill("M95.5,141 Q101,143.2 106,140.4 Q101,142 95.5,141 Z", mal(c["lippe"], 0.95)), 'display="none"')
    front = wolke(AH_AUSSEN + AH_PONY, (100, 58), beulen(n + len(AH_PONY), 4.6), True, 0.3)
    glanz = mix(haar, "9AA0B0", 0.45)
    s.g("hair-front", teil(front, haar, 3, mal(haar, 0.55)) + "".join(linie(d, glanz, 2.2, 0.8) for d in ["M60,46 L74,30 L92,24", "M112,22 L130,26 L142,38"])
        + "".join(linie(d, "0A0606", 1.5, 0.8) for d in ["M78,54 L82,64 L76,72", "M102,52 L106,64 L100,76", "M126,52 L130,64 L124,76"]))
    return s

# ---------- Annika ----------

AN_GES = "M100,30 C126,30 146,47 146,80 C146,102 141,118 132,130 C123,141 111,147 100,147 C89,147 77,141 68,130 C59,118 54,102 54,80 C54,47 74,30 100,30 Z"
AN_GES_V = "M100,30 C126,30 146,47 146,80 C146,102 142,118 135,128 L110,145 Q100,150 90,145 L65,128 C58,118 54,102 54,80 C54,47 74,30 100,30 Z"
AN_BACK = "M100,20 C66,20 46,42 46,86 L42,196 C42,214 46,228 54,238 L146,238 C154,228 158,214 158,196 L154,86 C154,42 134,20 100,20 Z"

def an_vorhang(sd):
    """Mittelscheitel: Vorhang links (sd=-1) bzw. rechts (+1). Deckt den Oberkopf, rahmt das Gesicht,
    faellt ueber die Schulter. Stirn-Haaransatz in der Mitte bei y~48."""
    x = lambda dx: f(100 + sd * dx)
    return (f"M{x(0.8)},22 C{x(22)},21 {x(42)},32 {x(47)},58 C{x(51)},78 {x(50)},100 {x(49)},124 "
            f"C{x(48)},152 {x(44)},186 {x(40)},226 L{x(58)},228 C{x(63)},196 {x(63)},160 {x(61)},134 "
            f"C{x(58)},112 {x(49)},92 {x(45)},84 C{x(41)},66 {x(30)},53 {x(14)},50 C{x(6)},48.5 {x(2)},46 {x(0.8)},40 Z")

def annika(stil, p=""):
    s = Svg(p); c = AN; haut, haar = c["haut"], c["haar"]
    stk = STK if stil == 2 else None
    rh = stk or kontur(haut)
    rr = stk or mal(haar, 0.6)
    hb = 3.8 if stk else 3
    ges = AN_GES_V if stil == 3 else AN_GES
    if stil == 2:
        s.g("sticker-border", "".join(f'<path d="{d}" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="12" stroke-linejoin="round"/>' for d in [AN_BACK, RUMPF, an_vorhang(-1), an_vorhang(1)]))
    lang = s.lin("haarLang", 0, 60, 0, 238, [(0, haar, 1), (1, mal(haar, 0.78), 1)])
    s.g("hair-back", teil(AN_BACK, mal(haar, 0.72), hb, rr))
    hals_und_rumpf(s, haut, c["top"], stk, stk, hb)
    s.g("ears", ohren(haut, rh, 3, 6))   # unter Gesicht/Haar versteckt, nur Anker fuer Ohrringe
    if stil == 2:
        warm = s.rad("hautAn", 100, 96, 68, [(0.5, haut, 1), (1, mix(haut, "E0A090", 0.35), 1)])
        s.g("face-shape", f'<path d="{ges}" fill="{warm}" stroke="#{STK}" stroke-width="3.8" stroke-linejoin="round"/>')
    else:
        weich = s.rad("hautAn", 98, 90, 70, [(0.6, haut, 1), (1, mal(haut, 0.93), 1)])
        s.g("face-shape", f'<path d="{ges}" fill="{weich}" stroke="#{rh}" stroke-width="{3 if stil == 3 else 3.5}" stroke-linejoin="round"/>')
    cl = s.clip("gesichtClip", ges)
    rot = "F27A8A"
    op = 0.32 if stil != 2 else 0.4
    ansatz = s.lin("ansatz", 0, 44, 0, 64, [(0, mal(haut, 0.82), 0.6), (1, mal(haut, 0.82), 0)])
    s.g("shading", f'<g {cl}>' + fill("M40,30 L160,30 L160,70 L40,70 Z", ansatz)
        + f'<ellipse cx="71" cy="121" rx="10" ry="6" fill="{s.rad("wl", 71, 121, 10, [(0, rot, op), (1, rot, 0)])}"/>'
        + f'<ellipse cx="129" cy="121" rx="10" ry="6" fill="{s.rad("wr", 129, 121, 10, [(0, rot, op), (1, rot, 0)])}"/>' + '</g>')
    s.g("jaw", "")
    augen, smile = "", ""
    for sd in (-1, 1):
        cx, cy = 100 + sd * 19, 102
        if stil == 3:
            weiss, i, o = auge_mandel(cx, cy, sd, 9, 11, 14, 8.5, 3)
        elif stil == 2:
            weiss, i, o = auge_mandel(cx, cy, sd, 9, 11, 14, 9, 2)
        else:
            weiss, i, o = auge_mandel(cx, cy, sd, 9, 11, 12.5, 8.5, 2.5)
        ecl = s.clip(f"augeAn{sd}", weiss)
        ir = s.lin(f"irisAn{sd}", 0, cy - 7, 0, cy + 7, [(0, mal(c["iris"], 0.55), 1), (1, mix(c["iris"], "9CC8F0", 0.45), 1)])
        ry = 7.4 if stil == 3 else 6.6
        augen += fill(weiss, "FFFFFF") + f'<g {ecl}><ellipse cx="{f(cx+sd*0.5)}" cy="{cy+0.5}" rx="{5.6 if stil == 3 else 6}" ry="{ry}" fill="{ir}"/>' + kreis(cx + sd * 0.5, cy + 1, 2.8, "1A1420")
        augen += kreis(cx - 2 + sd * 0.5, cy - 2.2, 2, "FFFFFF") + kreis(cx + 2 + sd * 0.5, cy + 3.2, 1, "FFFFFF", 0.85) + '</g>'
        ob = {1: 12.5, 2: 14, 3: 14}[stil]
        kp = {1: 2.5, 2: 2, 3: 3}[stil]
        augen += linie(f"M{f(i-sd*0.5)},{cy+0.6} Q{f(cx)},{f(cy-ob-0.5)} {f(o)},{f(cy-kp-0.5)} L{f(o+sd*3)},{f(cy-kp-2.5)}", stk or TINTE, 3.4 if stil != 1 else 3.1)
        if stil != 1:
            augen += linie(f"M{f(o-sd*3)},{f(cy-kp-3.5)} L{f(o)},{f(cy-kp-6.5)}", stk or TINTE, 1.8)    # eine Wimper
        smile += smile_lid(cx, cy, sd, 10, haut, rh, 6, s.clip(f"augeAns{sd}", weiss))
    s.g("eyes", augen)
    if stil == 2:
        s.g("eyes-smile", "".join(linie(f"M{f(100+sd*19-9)},104 Q{f(100+sd*19)},95 {f(100+sd*19+9)},104", STK, 3.4) + linie(f"M{f(100+sd*28)},101 L{f(100+sd*31)},98.5", STK, 2) for sd in (-1, 1)), 'display="none" data-replaces="eyes"')
    else:
        s.g("eyes-smile", smile, 'display="none"')
    bf = stk or mal(haar, 1.05)
    s.g("brows", "".join(fill(f"M{f(100+sd*9)},89.5 Q{f(100+sd*20)},83 {f(100+sd*30)},86.5 Q{f(100+sd*20)},85.5 {f(100+sd*9)},91.5 Z", bf) + linie(f"M{f(100+sd*9)},90.5 Q{f(100+sd*20)},84 {f(100+sd*30)},86.5", bf, 1.2) for sd in (-1, 1)))
    if stil == 3:
        s.g("nose", linie("M101.5,117.5 L99.5,119.5", mal(haut, 0.6), 1.8))
    elif stil == 2:
        s.g("nose", linie("M101,113 Q104,118.5 100,120", STK, 2) + kreis(99, 116.5, 1.2, "FFFFFF", 0.7))
    else:
        s.g("nose", fill("M102,108 Q105,116 103,120 Q101,114 101,108 Z", mal(haut, 0.86)) + linie("M97,120 Q100,122 103,120", mal(haut, 0.62), 1.6))
    lip = c["lippe"]
    if stil == 3:
        s.g("mouth-neutral", linie("M95,131 Q100,132.8 105,131", mal(lip, 0.5), 1.8) + fill("M96,132.6 Q100,135.6 104,132.6 Q100,133.8 96,132.6 Z", lip))
        s.g("mouth-smile", teil("M93,130 Q100,132.5 107,130 Q105,137.5 100,137.5 Q95,137.5 93,130 Z", "7A2A36", 1.4, mal(lip, 0.5)) + fill("M95.5,135 Q100,133 104.5,135 Q100,137.5 95.5,135 Z", "F0707E"), 'display="none"')
    else:
        rl = stk or mal(lip, 0.6)
        lo = "M91,132 Q95.5,128.5 100,130.2 Q104.5,128.5 109,132 Q100,133.2 91,132 Z"
        lu = "M91,132 Q100,133.2 109,132 Q105.5,138.5 100,138.5 Q94.5,138.5 91,132 Z"
        s.g("mouth-neutral", lippenmund(lo, lu, lip, rl, 1.6 if not stk else 2) + f'<ellipse cx="101.5" cy="135.2" rx="3.4" ry="1" fill="#FFFFFF" fill-opacity="0.5"/>')
        s.g("mouth-smile", teil("M89,130 Q100,134 111,130 Q108.5,141.5 100,141.5 Q91.5,141.5 89,130 Z", "7A2A36", 2 if stk else 1.6, rl) + fill("M91,131 Q100,134.5 109,131 L108.3,133.5 Q100,136 91.7,133.5 Z", "FFFFFF") + fill("M94,138.5 Q100,135.5 106,138.5 Q100,141.5 94,138.5 Z", "F0707E"), 'display="none"')
    glanz = mix(haar, "FFFFFF", 0.32)
    strich = "".join(linie(d, glanz, 2.2, 0.6) for d in ["M84,26 Q64,32 56,54", "M116,26 Q136,32 144,54"])
    strich += "".join(linie(d, mal(haar, 0.62), 1.2, 0.8) for d in ["M140,60 Q148,100 146,140 Q144,180 146,222", f"M{M(140)},60 Q{M(148)},100 {M(146)},140 Q{M(144)},180 {M(146)},222", "M104,28 Q128,34 136,64", f"M{M(104)},28 Q{M(128)},34 {M(136)},64"])
    s.g("hair-front", "".join(f'<path d="{an_vorhang(sd)}" fill="{lang}" stroke="#{rr}" stroke-width="{hb}" stroke-linejoin="round"/>' for sd in (-1, 1)) + strich)
    return s

OPTIONEN = {
    "ahmed-A": ("Ahmed A", "Clean Anime", ahmed_A),
    "ahmed-B": ("Ahmed B", "Bitmoji modern schlank", ahmed_B),
    "ahmed-C": ("Ahmed C", "Halb-realistisch flach", ahmed_C),
    "ahmed-D": ("Ahmed D", "Sticker-Stil", ahmed_D),
    "ahmed-E": ("Ahmed E", "Scharf / cool", ahmed_E),
    "annika-1": ("Annika 1", "App-Stil verfeinert", lambda p="": annika(1, p)),
    "annika-2": ("Annika 2", "Sticker-Stil", lambda p="": annika(2, p)),
    "annika-3": ("Annika 3", "Soft Anime", lambda p="": annika(3, p)),
}

def als_ausdruck(txt, laecheln):
    """Schaltet im Inline-SVG zwischen neutral und Laecheln um."""
    if not laecheln: return txt
    txt = txt.replace('display="none"', 'data-x="1"')
    for n in ("mouth-neutral",):
        txt = txt.replace(f'-{n}">', f'-{n}" display="none">')
    if 'data-replaces="eyes"' in txt:
        txt = txt.replace('-eyes">', '-eyes" display="none">')
    return txt

def main():
    for k, (titel, stil, fn) in OPTIONEN.items():
        with open(os.path.join(HIER, k + ".svg"), "w", encoding="utf-8") as fh:
            fh.write(fn().text(f"{titel} - {stil}"))
    def karte(k, gross, laecheln, suffix):
        titel, stil, fn = OPTIONEN[k]
        svg = fn(f"{k}-{suffix}-").text(titel)
        svg = als_ausdruck(svg, laecheln).replace('width="200" height="240"', f'width="{gross}" height="{int(gross*1.2)}"')
        return svg
    def reihe(keys, heute):
        z = f'<div class="spalte heute"><img src="{heute}" alt="Heute"><div class="lab">Heute</div></div>'
        for k in keys:
            titel, stil, _ = OPTIONEN[k]
            z += (f'<div class="spalte"><div class="kopf">{karte(k, 250, False, "n")}</div><div class="kopf klein2">{karte(k, 150, True, "s")}</div>'
                  f'<div class="lab">{titel}<span>{stil}</span></div></div>')
        return f'<div class="reihe">{z}</div>'
    ah = [k for k in OPTIONEN if k.startswith("ahmed")]
    an = [k for k in OPTIONEN if k.startswith("annika")]
    mini = "".join(f'<div class="mini">{karte(k, 48, False, "m")}{karte(k, 48, True, "ms")}<div>{OPTIONEN[k][0][-1]}</div></div>' for k in OPTIONEN)
    html = f"""<!doctype html><html lang="de"><head><meta charset="utf-8"><title>Gesichter Redesign</title>
<style>
:root{{--bg:#FBF7F4;--ink:#2A2024;--muted:#8A7D82;--line:#E9E0DA}}
body{{margin:0;background:var(--bg);color:var(--ink);font:15px/1.35 -apple-system,Segoe UI,sans-serif;padding:28px 36px}}
h1{{font-size:26px;margin:0 0 4px}} p.sub{{margin:0 0 22px;color:var(--muted)}}
h2{{font-size:18px;margin:26px 0 8px;border-bottom:1px solid var(--line);padding-bottom:6px}}
.reihe{{display:flex;gap:18px;align-items:flex-start}}
.spalte{{display:flex;flex-direction:column;align-items:center;background:#fff;border-radius:18px;padding:10px 8px 12px;box-shadow:0 1px 0 var(--line)}}
.spalte.heute{{background:#F1ECE8;opacity:.9}} .spalte.heute img{{width:150px;height:auto;margin-top:40px}}
.kopf svg{{display:block}} .klein2{{margin-top:-6px}}
.lab{{font-weight:700;font-size:17px;margin-top:4px;text-align:center}} .lab span{{display:block;font-weight:400;font-size:13px;color:var(--muted)}}
.minis{{display:flex;gap:14px;flex-wrap:wrap}} .mini{{display:flex;gap:2px;align-items:center;background:#fff;border-radius:12px;padding:6px 10px}} .mini div{{font-weight:700;margin-left:6px}}
</style></head><body>
<h1>Gesichter-Redesign, Schritt 1: nur Kopf</h1>
<p class="sub">Oben neutral, darunter laechelnd. Gleicher 200x240-Raum wie die Halbfigur der App, Torso = heutiger rumpf(0).</p>
<h2>Ahmed</h2>{reihe(ah, "heute-ahmed.png")}
<h2>Annika</h2>{reihe(an, "heute-annika.png")}
<h2>Avatar-Groesse (48 px, neutral + laechelnd)</h2><div class="minis">{mini}</div>
</body></html>"""
    with open(os.path.join(HIER, "gesichter.html"), "w", encoding="utf-8") as fh:
        fh.write(html)

if __name__ == "__main__":
    main()
