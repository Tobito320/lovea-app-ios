# Erzeugt die Kopf-Entwuerfe (SVG je Option) und das Vergleichsboard.
# Raum = Halbfigur der App: 200 x 240, Augenlinie ~y101, Torso = rumpf(0) aus FigurView.swift.
# python bau.py  ->  ahmed-A/B/D/E.svg, annika-1..3.svg, gesichter.html (C wurde verworfen)
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

def pony_schatten(s, farbe, clip, op=0.55, dy=5, aussen=None, pony=None):
    """Schatten des Ponys auf der Stirn: gleiche Kante, nach unten versetzt."""
    d = wolke((aussen or AH_AUSSEN) + [(x, y + dy) for x, y in (pony or AH_PONY)], (100, 58), 4)
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

# 25.09. nach Ahmeds Fotos: flacher, breiter Wuschel-Mop statt hoher Lockenwolke, Pony tief bis auf
# die Brauen (kleine Stirn), links eine Straehne ueber dem Auge.
AH_B_AUSSEN = [(51, 86), (43, 76), (40, 62), (44, 48), (54, 37), (68, 29), (85, 24), (102, 22), (119, 24),
               (134, 29), (147, 38), (156, 50), (160, 63), (158, 76), (150, 87)]
AH_B_PONY = [(150, 86), (142, 88), (133, 83), (124, 87), (115, 82), (106, 87), (97, 82), (89, 87), (82, 91), (75, 85), (65, 87), (57, 85)]

def ahmed_B(p=""):
    s = Svg(p); c = AH; haut, haar = c["haut"], c["haar"]
    rh = kontur(haut)
    # 25.09. (Ahmed: "Wangen bissl sharper"): Wangenknochen bei y 112, gerade Kante zur Kieferecke (137|133).
    # 25.09. (Ahmed: "Kinn zu klein und nicht scharf"): breites, eckiges Kinn mit flacher Unterkante.
    # 25.09. (Ahmed: "Abstand Kinn zu Mund zu gering"): Kinn 5 tiefer, Kieferecke 3 tiefer.
    gesicht = ("M100,26 C127,26 147,44 147,77 C147,95 146,106 144,114 L137,136 L117,153.5 Q100,158 83,153.5 "
               "L63,136 L56,114 C54,106 53,95 53,77 C53,44 73,26 100,26 Z")
    n = len(AH_B_AUSSEN)
    s.g("hair-back", teil(wolke(AH_B_AUSSEN + [(151, 97), (49, 97)], (100, 62), beulen(n + 2, 3.2)), haar))
    hals_und_rumpf(s, haut, c["top"])
    s.g("ears", ohren(haut, rh))
    weich = s.rad("hautB", 96, 92, 72, [(0.55, haut, 1), (1, mal(haut, 0.9), 1)])
    s.g("face-shape", f'<path d="{gesicht}" fill="{weich}" stroke="#{rh}" stroke-width="3.5" stroke-linejoin="round"/>')
    cl = s.clip("gesichtClip", gesicht)
    wl = s.rad("wlB", 62, 122, 14, [(0, mal(haut, 0.84), 0.7), (1, mal(haut, 0.84), 0)])
    wr = s.rad("wrB", 138, 122, 14, [(0, mal(haut, 0.84), 0.7), (1, mal(haut, 0.84), 0)])
    s.g("shading", pony_schatten(s, mal(haut, 0.88), cl, 0.6, 4, AH_B_AUSSEN, AH_B_PONY) + f'<g {cl}><ellipse cx="62" cy="122" rx="10" ry="15" fill="{wl}"/><ellipse cx="138" cy="122" rx="10" ry="15" fill="{wr}"/></g>')
    s.g("jaw", "")
    s.g("taper", taper(s, haar, haut, "taperB"))
    s.g("goatee", f'<g {cl}>' + fill("M96,147 Q100,146 104,147 Q103.5,152.5 100,153 Q96.5,152.5 96,147 Z", c["bart"], ' fill-opacity="0.45"')
        + fill("M86,153 Q100,149 114,153 L114,162 L86,162 Z", c["bart"], ' fill-opacity="0.14"') + '</g>')
    augen, smile = "", ""
    for sd in (-1, 1):
        cx, cy = 100 + sd * 19, 101
        weiss, i, o = auge_mandel(cx, cy, sd, 10, 11, 13, 9, 1.5)
        ecl = s.clip(f"augeB{sd}", weiss)
        # Fotos: schwere, entspannte Lider, das Oberlid liegt tief auf der Iris.
        lid = f"M{f(i-2)},{cy-9} L{f(o+2)},{cy-9} L{f(o+2)},{cy} Q{f(cx)},{cy-4.5} {f(i-2)},{cy+1.5} Z"
        augen += fill(weiss, "FFFFFF") + f'<g {ecl}>' + kreis(cx + sd * 0.5, cy + 1.2, 5.4, c["iris"]) + kreis(cx + sd * 0.5, cy + 1.2, 2.6, mal(TINTE, 0.7)) + kreis(cx - 1.6, cy - 0.2, 1.4, "FFFFFF") + fill(lid, haut) + '</g>'
        augen += linie(f"M{f(i)},{cy+1.5} Q{f(cx)},{cy-4.5} {f(o)},{cy}", TINTE, 3)
        augen += linie(f"M{f(i+sd*2)},{cy-5.5} Q{f(cx)},{cy-12} {f(o-sd*1)},{cy-5}", rh, 1.3, 0.5)
        smile += smile_lid(cx, cy, sd, 10, haut, rh, 6, s.clip(f"augeBs{sd}", weiss))
    s.g("eyes", augen)
    s.g("eyes-smile", smile, 'display="none"')
    # Fotos: dicke, fast gerade Brauen, tief und dicht ueber den Augen.
    s.g("brows", "".join(linie(f"M{f(100+sd*8)},93.5 Q{f(100+sd*19)},90.5 {f(100+sd*31)},92", mal(haar, 1.2), 5.2) for sd in (-1, 1)))
    # Lange, gerade Nase.
    s.g("nose", linie("M102,101 L105,124.5 Q103.5,129 98,128", rh, 2.4) + f'<ellipse cx="100" cy="129.5" rx="6.5" ry="2" fill="#{mal(haut,0.85)}" fill-opacity="0.6"/>')
    # Duenner Schnurrbart, breiter als der Mund, Enden haengen leicht.
    s.g("mustache", teil("M100,133 C95,131 87,131.5 80,138 C87,135 95,135 100,135.8 C105,135 113,135 120,138 C113,131.5 105,131 100,133 Z", c["bart"], 1.2))
    lo = "M90,141 Q95,138.5 100,139.5 Q105,138.5 110,141 Q100,142.2 90,141 Z"
    lu = "M90,141 Q100,142.2 110,141 Q106,146 100,146 Q94,146 90,141 Z"
    s.g("mouth-neutral", lippenmund(lo, lu, c["lippe"], mal(c["lippe"], 0.6)))
    s.g("mouth-smile", teil("M88,139 Q100,142.5 112,139 Q109,149.5 100,149.5 Q91,149.5 88,139 Z", "6B2335", 1.6, mal(c["lippe"], 0.5)) + fill("M90,140 Q100,143 110,140 L109,142.5 Q100,145 91,142.5 Z", "FFFFFF") + fill("M94,147.5 Q100,145 106,147.5 Q100,150 94,147.5 Z", "F07A8A"), 'display="none"')
    front = wolke(AH_B_AUSSEN + AH_B_PONY, (100, 60), beulen(n + len(AH_B_PONY), 3.6))
    ton = mix(haar, "FFFFFF", 0.16)
    locken = "".join(linie(d, ton, 2.2, 0.9) for d in ["M56,50 q7,-8 15,-7", "M82,34 q8,-6 16,-3", "M112,32 q9,-2 15,4", "M140,46 q6,5 6,12", "M66,66 q4,7 -1,12", "M92,62 q5,7 1,13", "M118,64 q5,6 1,12", "M142,68 q3,6 -1,11", "M76,50 q5,-5 11,-3", "M124,50 q6,-2 10,3", "M84,78 q2,7 -2,12"])
    s.g("hair-front", teil(front, haar, 3.5) + locken)
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

# ---------- Annika (Runde 2: nach ihren Stickern, kleine Stirn, Haar rahmt das Gesicht) ----------

# Schlankes weiches Oval, kleines Kinn. Schaedel oben y 34 (vom Haar verdeckt), Kinn y 146.
AN_GES = "M100,34 C123,34 141,50 141,82 C141,104 137,120 128,131 C119,141 109,146 100,146 C91,146 81,141 72,131 C63,120 59,104 59,82 C59,50 77,34 100,34 Z"
# Schmalere Schultern und Hals fuer Annika: rumpf(0) um x=100 mit 0,88 skaliert.
AN_RUMPF = "M38.4,240 L41,200 C42.8,178 56,166 75.4,164 L87.7,161 Q100,176 112.3,161 L124.6,164 C144,166 157.2,178 159,200 L161.6,240 Z"
AN_HALS = "M90.5,126 L89.5,176 L110.5,176 L109.5,126 Z"
AN_BACK = ("M100,31 C76,31 56,40 54,62 C52,90 51,120 50,150 C48,180 40,205 36,232 "
           "L46,225 L53,236 L62,228 L74,234 L100,230 L126,234 L138,228 L147,236 L154,225 L164,232 "
           "C160,205 152,180 150,150 C149,120 148,90 146,62 C144,40 124,31 100,31 Z")

# Haaransatz tiefer als in Runde 2 (Ahmed 25.09.: "Annikas Stirn ist in echt noch etwas kleiner").
AN_ANSATZ = 5.5

def an_vorhang(sd, px=100.0, tief=0.0):
    """Eine Haarseite: Oberkopf ab dem Scheitel `px`, Pony-Strang ueber Schlaefe und Wange,
    lange Straehne vor der Schulter mit spitzen Enden. `tief` schiebt den Pony tiefer ins Gesicht."""
    x = lambda dx: f(100 + sd * dx)
    p = lambda dx: f(px + sd * dx)
    return (f"M{p(0.8)},30 C{x(28)},27 {x(46)},38 {x(48)},60 "
            f"C{x(50)},84 {x(47)},112 {x(49)},140 C{x(52)},168 {x(60)},198 {x(62)},230 "
            f"L{x(57)},222 L{x(53)},234 L{x(48)},222 L{x(42)},231 "
            f"C{x(41)},200 {x(39)},170 {x(36)},142 "
            f"C{x(34)},128 {x(37)},114 {x(36)},{f(102+tief)} "
            f"C{x(35)},{f(86+tief)} {x(25)},{f(71+tief*0.8+AN_ANSATZ*0.6)} {p(14)},{f(63+tief*0.6+AN_ANSATZ)} "
            f"C{p(8)},{f(60.5+tief*0.3+AN_ANSATZ)} {p(3)},{f(59.5+AN_ANSATZ)} {p(0.8)},{f(59.5+AN_ANSATZ)} Z")

def an_hinters_ohr(sd, px=100.0):
    """Seite, die hinters Ohr gesteckt ist: Pony vorne, dann hinter dem Ohr nach hinten (Rest liegt im hair-back)."""
    x = lambda dx: f(100 + sd * dx)
    p = lambda dx: f(px + sd * dx)
    # 25.09. (Ahmed: "Annika hat ihre Haare zu 99% nach vorne"): hinter dem Ohr, dann vor der Schulter lang nach unten.
    return (f"M{p(0.8)},30 C{x(28)},27 {x(46)},38 {x(48)},60 C{x(50)},86 {x(51)},122 {x(53)},152 "
            f"C{x(56)},176 {x(60)},200 {x(62)},230 L{x(57)},222 L{x(53)},234 L{x(48)},222 L{x(43)},231 "
            f"C{x(43)},206 {x(45)},180 {x(47)},158 "
            f"L{x(50)},154 C{x(49)},134 {x(49)},120 {x(48)},108 "
            f"C{x(46)},90 {x(28)},{f(70+AN_ANSATZ*0.6)} {p(14)},{f(63+AN_ANSATZ)} C{p(8)},{f(60.5+AN_ANSATZ)} {p(3)},{f(59.5+AN_ANSATZ)} {p(0.8)},{f(59.5+AN_ANSATZ)} Z")

def an_straehne(sd, y0=70, y1=142, dx0=37, dx1=33, b=4.5):
    """Duenne Straehne, die von der Schlaefe ueber die Wangenkante faellt und spitz endet."""
    x = lambda dx: f(100 + sd * dx)
    return (f"M{x(dx0+b)},{y0} C{x(dx0+b+1)},{y0+26} {x(dx1+b)},{y1-24} {x(dx1+2)},{y1} "
            f"C{x(dx1-1)},{y1-26} {x(dx0-2)},{y0+30} {x(dx0-1)},{y0+6} Z")

def anime_glanz(px):
    """Glanzband quer ueber den Oberkopf, Unterkante gezackt."""
    oben, unten = [], []
    for i, xx in enumerate(range(62, 139, 6)):
        if abs(xx - px) < 5: continue
        y = 39 + 24 * ((xx - 100) / 48) ** 2
        oben.append((xx, y))
        unten.append((xx, y + (7 if i % 2 else 4)))
    teile = []
    for seite in ([q for q in zip(oben, unten) if q[0][0] < px], [q for q in zip(oben, unten) if q[0][0] > px]):
        o = [a for a, b in seite]; u = [b for a, b in seite][::-1]
        teile.append("M" + " L".join(pt(q) for q in o + u) + " Z")
    return teile

def an_haar_linien(sd, farbe, px=100.0):
    x = lambda dx: f(100 + sd * dx)
    p = lambda dx: f(px + sd * dx)
    return "".join(linie(d, farbe, 1.2, 0.7) for d in [
        f"M{p(6)},35 C{x(28)},37 {x(44)},56 {x(46)},92 C{x(48)},130 {x(47)},170 {x(44)},214",
        f"M{p(14)},35 C{x(34)},37 {x(48)},52 {x(50)},80",
        f"M{x(40)},120 C{x(41)},150 {x(43)},180 {x(40)},222",
        f"M{p(4)},40 C{x(18)},44 {x(28)},58 {x(33)},78"])

def an_auge(s, name, cx, cy, sd, haut, iris, stil, lid_rand):
    """Mandelauge wie in den Stickern: grosse dunkle Iris, dicker Lidstrich mit kleinem Fluegel."""
    i, o = cx - sd * 8, cx + sd * 10
    hoch = 7.5 if stil != 2 else 9
    # Oberlid als Kurve mit dem hoechsten Punkt im aeusseren Drittel, wie in den Stickern
    oberlid = f"M{f(i)},{f(cy+1)} C{f(i+sd*3)},{f(cy-6)} {f(cx+sd*4)},{f(cy-hoch)} {f(o)},{f(cy-3.4)}"
    weiss = oberlid + f" Q{f(cx+sd*2)},{f(cy+7.5)} {f(i)},{f(cy+1)} Z"
    ecl = s.clip(name, weiss)
    hell = "A8D0F4" if iris == AN_BLAU else ("E0A868" if stil == 2 else "C8925A")
    ir = s.lin(name + "i", 0, cy - 6, 0, cy + 6, [(0, mal(iris, 0.45), 1), (1, mix(iris, hell, 0.6 if stil == 2 else 0.5), 1)])
    t = "2A1712" if stil != 3 else TINTE
    d = fill(weiss, "FFFFFF") + f'<g {ecl}><ellipse cx="{f(cx+sd*0.3)}" cy="{f(cy+0.3)}" rx="{5.2 if stil != 2 else 5}" ry="{6 if stil != 2 else 6.6}" fill="{ir}"/>'
    d += kreis(cx + sd * 0.3, cy + 0.6, 2.4, "140C0A") + kreis(cx - 1.8 + sd * 0.3, cy - 1.8, 1.7, "FFFFFF") + kreis(cx + 1.9 + sd * 0.3, cy + 2.4, 0.8, "FFFFFF", 0.85) + '</g>'
    d += linie(oberlid + f" L{f(o+sd*3.6)},{f(cy-6.2)}", t, 3.4 if stil != 3 else 3)
    if stil == 1:
        d += linie(f"M{f(o-sd*2.5)},{f(cy-4.6)} L{f(o+sd*0.2)},{f(cy-7.6)}", t, 1.4) + linie(f"M{f(o-sd*5.5)},{f(cy-5.4)} L{f(o-sd*3.8)},{f(cy-8.6)}", t, 1.2)
        d += linie(f"M{f(cx+sd*4)},{f(cy+4.4)} Q{f(cx+sd*7.5)},{f(cy+3.6)} {f(o-sd*1)},{f(cy+0.6)}", lid_rand, 0.9, 0.45)
    elif stil == 2:
        d += linie(f"M{f(o-sd*1)},{f(cy-3.8)} Q{f(o+sd*2.5)},{f(cy-6)} {f(o+sd*4.5)},{f(cy-8.5)}", t, 1.3)
    else:
        d += linie(f"M{f(o-sd*2.5)},{f(cy-4.6)} L{f(o+sd*0.2)},{f(cy-7.4)}", t, 1.5)
    return d, weiss

AN_BLAU = "3F74B5"

def annika(stil, p=""):
    """1 = sticker-treu, 2 = soft Anime, 3 = modernes Bitmoji (App-Stil)."""
    s = Svg(p); c = AN
    haut = {1: "EFC09B", 2: "F6CDB0", 3: "F9D3B8"}[stil]     # 1 = Preset "Pfirsich" (warm wie die Sticker), 3 = Preset "Hell"
    haar = c["haar"]
    iris = AN_BLAU if stil == 3 else "3A2418"
    linie_haut = {1: "6A4232", 2: mal(haut, 0.72), 3: kontur(haut)}[stil]
    bh = {1: 2.2, 2: 1.6, 3: 3.2}[stil]
    haar_rand = {1: "22140F", 2: mal(haar, 0.55), 3: mal(haar, 0.55)}[stil]
    hb = {1: 2.2, 2: 1.8, 3: 3}[stil]
    px, tief_l, tief_r = (92, 0, 7) if stil == 2 else (100, 0, 0)
    haar_verlauf = s.lin("haarLang", 0, 30, 0, 236, [(0, mix(haar, "6A4632", 0.45), 1), (0.35, haar, 1), (1, mal(haar, 0.85), 1)])
    s.g("hair-back", teil(AN_BACK, mal(haar, 0.7), hb, haar_rand))
    hals = teil(AN_HALS, haut, bh, linie_haut)
    hcl = s.clip("halsClip", AN_HALS)
    hals += f'<g {hcl}>' + fill("M84,126 L116,126 L116,140 Q100,158 84,140 Z", s.lin("halsS", 0, 132, 0, 156, [(0, mal(haut, 0.78), 0.8), (1, mal(haut, 0.78), 0)])) + '</g>'
    s.g("neck", hals)
    top = c["top"]
    s.g("torso-hint", teil(AN_RUMPF, top, bh if stil != 2 else 2, kontur(top)))
    if stil == 3:
        ohr = "M140,97 C147,93 151,103 149,111 C148,118 144,121 140,118 Z"
        s.g("ears", teil(ohr, haut, bh, linie_haut) + linie("M142,101 C146,103 146,110 142,113", linie_haut, 1.4, 0.6) + kreis(143.5, 120.5, 2, "F5C542") + kreis(143, 120, 0.7, "FFFFFF", 0.8))
    else:
        s.g("ears", ohren(haut, linie_haut, 2, 11))   # unter Gesicht und Haar, nur Anker fuer Ohrringe
    weich = s.rad("hautAn", 98, 92, 64, [(0.62, haut, 1), (1, mal(haut, 0.93), 1)])
    s.g("face-shape", f'<path d="{AN_GES}" fill="{weich}" stroke="#{linie_haut}" stroke-width="{bh}" stroke-linejoin="round"/>')
    cl = s.clip("gesichtClip", AN_GES)
    rot = "F07C86"
    op = {1: 0.36, 2: 0.28, 3: 0.24}[stil]
    wange = "".join(f'<ellipse cx="{f(100+sd*27)}" cy="119" rx="11" ry="7" fill="{s.rad("w" + str(sd), 100 + sd * 27, 119, 11, [(0, rot, op), (1, rot, 0)])}"/>' for sd in (-1, 1))
    if stil == 1:
        wange += f'<ellipse cx="100" cy="114" rx="9" ry="4" fill="{s.rad("wn", 100, 114, 9, [(0, rot, 0.18), (1, rot, 0)])}"/>'
    s.g("shading", f'<g {cl}>' + wange + '</g>')
    s.g("jaw", "")
    augen, smile = "", ""
    lid_rand = mal(haut, 0.66)
    for sd in (-1, 1):
        cx, cy = 100 + sd * 18.5, 102
        d, weiss = an_auge(s, f"augeAn{sd}", cx, cy, sd, haut, iris, stil, lid_rand)
        augen += d
        if stil == 1:
            # wie im Kicher-Sticker: geschlossene Bogen-Augen mit Wimpern
            smile += linie(f"M{f(cx-9)},{f(cy+2)} Q{f(cx)},{f(cy-6)} {f(cx+9)},{f(cy+2)}", "2A1712", 3)
            smile += linie(f"M{f(cx+sd*8.5)},{f(cy+1)} L{f(cx+sd*11.5)},{f(cy-1.5)}", "2A1712", 1.4) + linie(f"M{f(cx+sd*6)},{f(cy-1.5)} L{f(cx+sd*8)},{f(cy-4.5)}", "2A1712", 1.2)
        else:
            smile += smile_lid(cx, cy, sd, 9.5, haut, lid_rand, 5.5, s.clip(f"augeAns{sd}", weiss))
    s.g("eyes", augen)
    s.g("eyes-smile", smile, 'display="none"' + (' data-replaces="eyes"' if stil == 1 else ""))
    braue = mal(haar, 1.15) if stil != 3 else mal(haar, 1.05)
    bd = 0 if stil == 3 else 0.8
    s.g("brows", "".join(fill(f"M{f(100+sd*8.5)},90 Q{f(100+sd*19)},{f(83.2-bd)} {f(100+sd*28.5)},87.2 Q{f(100+sd*19)},{f(86+bd*0.3)} {f(100+sd*9)},{f(92.4+bd)} Z", braue) for sd in (-1, 1)))
    if stil == 3:
        s.g("nose", linie("M101.5,112 Q104,118 100.5,119.5", linie_haut, 1.8))
    else:
        s.g("nose", f'<ellipse cx="102.4" cy="117.4" rx="1.6" ry="2.6" fill="#{mal(haut, 0.86)}" fill-opacity="0.6"/>'
            + linie("M97.6,119.6 Q99.2,120.8 100.8,120.2", mal(haut, 0.6), 1.3) + f'<ellipse cx="100" cy="117" rx="1.5" ry="1" fill="#FFFFFF" fill-opacity="0.6"/>')
    lip = {1: "D9867E", 2: "E58E96", 3: mal(mix(haut, ROSE, 0.4), 0.9)}[stil]
    rl = mal(lip, 0.62)
    lo = "M92.5,130.6 Q96,127.8 100,129.2 Q104,127.8 107.5,130.6 Q100,131.6 92.5,130.6 Z"
    lu = "M92.5,130.6 Q100,131.6 107.5,130.6 Q105,135.8 100,135.8 Q95,135.8 92.5,130.6 Z"
    s.g("mouth-neutral", fill(lo, mal(lip, 0.88)) + fill(lu, lip) + linie("M93,130.6 Q100,131.8 107,130.6", rl, 0.9)
        + f'<ellipse cx="101.2" cy="133.4" rx="3" ry="0.9" fill="#FFFFFF" fill-opacity="0.45"/>')
    if stil == 3:
        s.g("mouth-smile", fill("M92,129.5 Q96,127.4 100,128.6 Q104,127.4 108,129.5 Q100,132.8 92,129.5 Z", mal(lip, 0.88)) + fill("M92,129.5 Q100,132.8 108,129.5 Q105.5,135.6 100,135.6 Q94.5,135.6 92,129.5 Z", lip)
            + linie("M91.5,129.3 Q100,133.4 108.5,129.3", rl, 1.3) + linie("M90.5,128 Q91,129.5 92.2,129.8", rl, 1) + linie("M109.5,128 Q109,129.5 107.8,129.8", rl, 1), 'display="none"')
    else:
        breit = 10 if stil == 1 else 8.5
        s.g("mouth-smile", teil(f"M{f(100-breit)},129 Q100,132.6 {f(100+breit)},129 Q{f(100+breit*0.72)},138.6 100,138.6 Q{f(100-breit*0.72)},138.6 {f(100-breit)},129 Z", "7A2A36", 1.4, rl)
            + fill(f"M{f(100-breit+1.8)},129.9 Q100,133.4 {f(100+breit-1.8)},129.9 L{f(100+breit-2.4)},132.2 Q100,134.8 {f(100-breit+2.4)},132.2 Z", "FFFFFF")
            + fill("M95,136.4 Q100,133.8 105,136.4 Q100,138.6 95,136.4 Z", "F0707E"), 'display="none"')
    # Haar vorn: Straehnen unter den Vorhaengen, dann zwei Seiten ab dem Scheitel
    unter = ""
    if stil != 3:
        for sd in (-1, 1):
            unter += f'<path d="{an_straehne(sd)}" fill="#{mix(haar, "6A4632", 0.2)}" stroke="#{haar_rand}" stroke-width="{hb*0.5:.1f}" stroke-linejoin="round"/>'
    else:
        unter += f'<path d="{an_straehne(-1)}" fill="#{haar}" stroke="#{haar_rand}" stroke-width="{hb}" stroke-linejoin="round"/>'
    vorne = unter
    for sd, tief in ((-1, tief_l), (1, tief_r)):
        pfad = an_hinters_ohr(sd, px) if (stil == 3 and sd == 1) else an_vorhang(sd, px, tief)
        vorne += f'<path d="{pfad}" fill="{haar_verlauf}" stroke="#{haar_rand}" stroke-width="{hb}" stroke-linejoin="round"/>'
    for sd in ((-1,) if stil == 3 else (-1, 1)):
        vorne += an_haar_linien(sd, mal(haar, 0.55), px)
    glanz = mix(haar, "C9A080", 0.45)
    if stil == 2:
        # Anime-Glanzband quer ueber den Oberkopf
        vorne += "".join(fill(d, glanz, ' fill-opacity="0.5"') for d in anime_glanz(px))
    else:
        vorne += "".join(linie(d, glanz, 2.2, 0.55) for d in [f"M{f(px-6)},38 Q{f(px-26)},39 {f(px-37)},56", f"M{f(px+6)},38 Q{f(px+26)},39 {f(px+37)},56", "M56,150 Q58,175 62,205"] + ([] if stil == 3 else ["M144,150 Q142,175 138,205"]))
    s.g("hair-front", vorne)
    return s

OPTIONEN = {
    "ahmed-A": ("Ahmed A", "Clean Anime", ahmed_A),
    "ahmed-B": ("Ahmed B", "Bitmoji modern schlank", ahmed_B),
    "ahmed-D": ("Ahmed D", "Sticker-Stil", ahmed_D),
    "ahmed-E": ("Ahmed E", "Scharf / cool", ahmed_E),
    "annika-1": ("Annika 1", "Sticker-treu", lambda p="": annika(1, p)),
    "annika-2": ("Annika 2", "Soft Anime, Seitenscheitel", lambda p="": annika(2, p)),
    "annika-3": ("Annika 3", "Modernes Bitmoji", lambda p="": annika(3, p)),
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
    def reihe(keys, heute, vergleich=()):
        z = f'<div class="spalte heute"><img src="{heute}" alt="Heute"><div class="lab">Heute</div></div>'
        for k in list(keys) + list(vergleich):
            titel, stil, _ = OPTIONEN[k]
            if k in vergleich: stil = "zum Groessenvergleich"
            z += (f'<div class="spalte{" vergleich" if k in vergleich else ""}"><div class="kopf">{karte(k, 250, False, "n")}</div><div class="kopf klein2">{karte(k, 150, True, "s")}</div>'
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
.spalte.vergleich{{background:#F4F0ED}} .spalte.heute{{background:#F1ECE8;opacity:.9}} .spalte.heute img{{width:150px;height:auto;margin-top:40px}}
.kopf svg{{display:block}} .klein2{{margin-top:-6px}}
.lab{{font-weight:700;font-size:17px;margin-top:4px;text-align:center}} .lab span{{display:block;font-weight:400;font-size:13px;color:var(--muted)}}
.minis{{display:flex;gap:14px;flex-wrap:wrap}} .mini{{display:flex;gap:2px;align-items:center;background:#fff;border-radius:12px;padding:6px 10px}} .mini div{{font-weight:700;margin-left:6px}}
</style></head><body>
<h1>Gesichter-Redesign, Schritt 1: nur Kopf</h1>
<p class="sub">Oben neutral, darunter laechelnd. Gleicher 200x240-Raum wie die Halbfigur der App, Torso = heutiger rumpf(0).</p>
<h2>Ahmed</h2>{reihe(ah, "heute-ahmed.png")}
<h2>Annika</h2>{reihe(an, "heute-annika.png", ("ahmed-B", "ahmed-D"))}
<h2>Avatar-Groesse (48 px, neutral + laechelnd)</h2><div class="minis">{mini}</div>
</body></html>"""
    with open(os.path.join(HIER, "gesichter.html"), "w", encoding="utf-8") as fh:
        fh.write(html)

if __name__ == "__main__":
    main()
