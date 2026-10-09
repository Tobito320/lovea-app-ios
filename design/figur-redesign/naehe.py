"""Naehe-Posen in 2D aus den echten Figur-Teilen (Ahmed B mit S4-Rumpf, Annika 3). -> naehe.html"""
import os, re, math
import bau, schulter as SC
from bau import kontur, f, teil, linie, kreis, AH, AN
HIER = os.path.dirname(os.path.abspath(__file__))

def gruppen(svgobj):
    out = {}
    for g in svgobj.gruppen:
        m = re.match(r'<g id="[^"]*?(hair-back|neck|torso-hint|ears|face-shape|shading|jaw|taper|goatee|eyes-smile|eyes|brows|nose|mustache|mouth-neutral|mouth-smile|hair-front)"', g)
        if m: out[m.group(1)] = g
    return out

def kopf(g, laecheln=False):
    teile = ["ears", "face-shape", "shading", "taper", "goatee", "eyes", "brows", "nose", "mustache",
             "mouth-smile" if laecheln else "mouth-neutral", "hair-front"]
    s = "".join(g.get(t, "") for t in teile)
    return s.replace('display="none"', '')

def ahmed(prefix):
    s = bau.ahmed_B(prefix); g = gruppen(s)
    d, koerper = SC.variante(prefix + "k", rumpf_kw="rund", stoff=(33, 29, 27, .0, .4))
    return "".join(s.defs) + d, g["hair-back"], g["neck"] + koerper, kopf(g)

def annika(prefix):
    s = bau.annika(3, prefix); g = gruppen(s)
    return "".join(s.defs), g["hair-back"], g["neck"] + g["torso-hint"], kopf(g, laecheln=True)

def hand(x, y, r, farbe, winkel=0):
    """Weiche Hand: Handflaeche plus angedeutete Finger."""
    k = kontur(farbe)
    return (f'<g transform="rotate({winkel} {x} {y})"><ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r*1.15}" fill="#{farbe}" stroke="#{k}" stroke-width="2.6"/>'
            + "".join(linie(f"M{f(x+dx)},{f(y+r*0.3)} L{f(x+dx)},{f(y+r*0.95)}", k, 1.2, 0.6) for dx in (-r*0.35, 0, r*0.35)) + '</g>')

def arm(s, e, h, farbe, d=1.0):
    return f'<path d="{SC.arm_umriss(s, e, h, 26*d, 20*d, 15*d, 0, .9)}" fill="#{farbe}" stroke="#{kontur(farbe)}" stroke-width="3"/>'

W, H = 360, 280

def kopf_an_kopf():
    ad, ahb, akr, akopf = ahmed("a3-")
    nd, nhb, nkr, nkopf = annika("n3-")
    # Ahmed rechts, Kopf leicht zu ihr geneigt; Annika links, lehnt den Kopf an seine Schlaefe.
    A = 'translate(150,24) rotate(-5 100 160)'
    N = 'translate(48,38) rotate(14 100 170)'
    o = f"<defs>{ad}{nd}</defs>"
    o += f'<g transform="{N}">{nhb}</g>'
    o += f'<g transform="{A}">{ahb}</g>'
    o += f'<g transform="{N}">{nkr}</g>'
    o += f'<g transform="{A}">{akr}</g>'
    # seine Hand auf ihrer Schulter (sein Arm liegt hinter ihr)
    o += hand(86, 208, 9.5, AH["haut"], -20)
    o += f'<g transform="{N}">{nkopf}</g>'
    o += f'<g transform="{A}">{akopf}</g>'
    # ihre Hand auf seiner Brust: Unterarm kommt von unten
    o += arm((178, 300), (190, 266), (206, 240), "F9D3B8", 0.78) + hand(207, 236, 8.5, "F9D3B8", 15)
    return o

FEATURES = ["eyes", "brows", "nose", "mustache", "mouth-neutral", "mouth-smile", "goatee"]

def kopf_gedreht(g, richtung, laecheln=False, zu=False, person="a", staerke=11):
    """3/4-Drehung: Gesichtsflaeche etwas schmaler, Gesichtszuege rutschen zur Seite und werden schmaler.
    `richtung` +1 = dreht sich nach rechts (Bild), -1 = nach links. `zu` = Augen geschlossen (Kuss)."""
    mund = "mouth-smile" if laecheln else "mouth-neutral"
    flaeche = "".join(g.get(t, "") for t in ["ears", "face-shape", "shading", "taper"])
    zuege_teile = [t for t in ["goatee", "brows", "nose", "mustache", mund] if t in g]
    zuege = "".join(g[t] for t in zuege_teile).replace('display="none"', '')
    if zu:
        cy = 102
        xs = (81, 119)
        tinte = "3A2630"
        augen = "".join(linie(f"M{f(x-9)},{f(cy)} Q{f(x)},{f(cy+6)} {f(x+9)},{f(cy)}", tinte, 3) for x in xs)
        if person == "n":
            augen += "".join(linie(f"M{f(x + s*9)},{f(cy)} L{f(x + s*12.5)},{f(cy-2.5)}", tinte, 1.6) for x, s in ((81.5, -1), (118.5, 1)))
    else:
        augen = g.get("eyes", "")
    dx = staerke * richtung
    zuege_g = f'<g transform="translate({100+dx},0) scale(0.84,1) translate(-100,0)">{augen}{zuege}</g>'
    return (f'<g transform="translate(100,0) scale(0.93,1) translate(-100,0)">{flaeche}</g>' + zuege_g + g.get("hair-front", ""))

def teile_a(prefix):
    s = bau.ahmed_B(prefix); g = gruppen(s)
    d, koerper = SC.variante(prefix + "k", rumpf_kw="rund", stoff=(33, 29, 27, .0, .4))
    return "".join(s.defs) + d, g, g["hair-back"], g["neck"] + koerper

def teile_n(prefix):
    s = bau.annika(3, prefix); g = gruppen(s)
    return "".join(s.defs), g, g["hair-back"], g["neck"] + g["torso-hint"]

def stufe1():
    ad, ag, ahb, akr = teile_a("a1-")
    nd, ng, nhb, nkr = teile_n("n1-")
    A = 'translate(162,20)'
    N = 'translate(28,34) rotate(3 100 170)'
    o = f"<defs>{ad}{nd}</defs>"
    o += f'<g transform="{N}">{nhb}</g><g transform="{A}">{ahb}</g>'
    o += f'<g transform="{N}">{nkr}</g><g transform="{A}">{akr}</g>'
    o += f'<g transform="{N}">{kopf_gedreht(ng, 1, laecheln=True, person="n")}</g>'
    o += f'<g transform="{A} rotate(-3 100 150)">{kopf_gedreht(ag, -1, laecheln=True)}</g>'
    return o

def finger_ueber_schulter(x, y, farbe, r=9):
    """Hand von hinten ueber die Schulter gelegt: vier Fingerkuppen und ein Stueck Handruecken."""
    k = kontur(farbe)
    o = f'<path d="M{f(x-r*1.1)},{f(y-r*0.6)} Q{f(x)},{f(y-r*1.3)} {f(x+r*1.1)},{f(y-r*0.6)} L{f(x+r*1.0)},{f(y+r*0.5)} Q{f(x)},{f(y+r*0.9)} {f(x-r*1.0)},{f(y+r*0.5)} Z" fill="#{farbe}" stroke="#{k}" stroke-width="2.6" stroke-linejoin="round"/>'
    for dx in (-0.62, -0.2, 0.22, 0.62):
        o += linie(f"M{f(x+dx*r)},{f(y+r*0.1)} L{f(x+dx*r)},{f(y+r*0.75)}", k, 1.2, 0.6)
    return o

def stufe2():
    """Arm um sie: sie steht leicht vor seiner Schulter, sein Arm laeuft hinter ihrem Ruecken,
    vorn sieht man nur seine Hand ueber ihrer fernen Schulter."""
    ad, ag, ahb, akr = teile_a("a2-")
    nd, ng, nhb, nkr = teile_n("n2-")
    A = 'translate(146,16)'
    N = 'translate(54,40) rotate(6 100 170)'
    o = f"<defs>{ad}{nd}</defs>"
    o += f'<g transform="{A}">{ahb}</g>'
    o += f'<g transform="{A}">{akr}</g>'
    o += f'<g transform="{N}">{nhb}</g>'
    o += f'<g transform="{N}">{nkr}</g>'
    o += f'<g transform="{N}">{kopf(ng, laecheln=True)}</g>'
    o += finger_ueber_schulter(92, 214, AH["haut"])
    o += f'<g transform="{A} rotate(-4 100 150)">{kopf(ag)}</g>'
    return o

def kuss():
    ad, ag, ahb, akr = teile_a("a4-")
    nd, ng, nhb, nkr = teile_n("n4-")
    A = 'translate(104,12)'
    N = 'translate(56,34)'
    o = f"<defs>{ad}{nd}</defs>"
    o += f'<g transform="{N}">{nhb}</g><g transform="{A}">{ahb}</g>'
    o += f'<g transform="{N}">{nkr}</g><g transform="{A}">{akr}</g>'
    # seine Hand an ihrer Taille
    o += hand(120, 262, 9.5, AH["haut"], -10)
    o += f'<g transform="{N} rotate(14 100 150)">{kopf_gedreht(ng, 1, zu=True, person="n", staerke=16)}</g>'
    o += f'<g transform="{A} rotate(-10 100 150)">{kopf_gedreht(ag, -1, zu=True, staerke=22)}</g>'
    # ihre Hand an seinem Hals
    o += arm((150, 300), (176, 250), (206, 206), "F9D3B8", 0.75) + hand(208, 202, 8.5, "F9D3B8", 25)
    return o

posen = [("Stufe 1: nah, schauen sich an", stufe1()), ("Stufe 2: Arm um sie", stufe2()),
         ("Stufe 3: Kopf an Kopf", kopf_an_kopf()), ("Kuss", kuss())]
html = ("<!doctype html><html><head><meta charset='utf-8'><style>body{margin:0;padding:20px;background:#FBF7F4;font:15px Segoe UI,sans-serif}"
        ".k{background:#fff;border-radius:14px;padding:8px;display:inline-block;text-align:center;margin:0 10px 10px 0}.k svg{width:420px;height:327px}</style></head><body>")
html += "".join(f"<div class='k'><svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 {W} {H}'>{s}</svg><div>{n}</div></div>" for n, s in posen)
open(os.path.join(HIER, "naehe.html"), "w", encoding="utf-8").write(html + "</body></html>")
print("naehe ok")
