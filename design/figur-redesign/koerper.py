"""Figur-Redesign Schritt 2: Oberkoerper der Halbfigur zum neuen Kopf (Ahmed B).
`python koerper.py` schreibt koerper.html; Screenshot -> koerper.png."""
import math, os
import bau
from bau import kontur, mal, f, AH

HIER = os.path.dirname(os.path.abspath(__file__))
HAUT, TOP = AH["haut"], AH["top"]

def skaliert(d_pts, fx):
    return d_pts

def rumpf(fx):
    """rumpf(0) aus der App, um x=100 mit fx skaliert."""
    pts = [(30,240),(33,200),(35,178),(50,166),(72,164),(86,161),(100,178),(114,161),(128,164),(150,166),(165,178),(167,200),(170,240)]
    X = lambda x: f(100 + (x - 100) * fx)
    p = pts
    return (f"M{X(p[0][0])},{p[0][1]} L{X(p[1][0])},{p[1][1]} C{X(p[2][0])},{p[2][1]} {X(p[3][0])},{p[3][1]} {X(p[4][0])},{p[4][1]} "
            f"L{X(p[5][0])},{p[5][1]} Q{X(p[6][0])},{p[6][1]} {X(p[7][0])},{p[7][1]} L{X(p[8][0])},{p[8][1]} "
            f"C{X(p[9][0])},{p[9][1]} {X(p[10][0])},{p[10][1]} {X(p[11][0])},{p[11][1]} L{X(p[12][0])},{p[12][1]} Z")

def strich(a, b, farbe, breite):
    return f'<path d="M{f(a[0])},{f(a[1])} L{f(b[0])},{f(b[1])}" stroke="#{farbe}" stroke-width="{f(breite)}" stroke-linecap="round" fill="none"/>'

def kreis(c, r, farbe, rand=None, rb=3.5):
    s = f' stroke="#{rand}" stroke-width="{rb}"' if rand else ""
    return f'<circle cx="{f(c[0])}" cy="{f(c[1])}" r="{f(r)}" fill="#{farbe}"{s}/>'

def arm_alt(s, e, h, d, m):
    """Wie `arm()` + `muskelBeulen()` in FigurView (Aermel kurz: oben Shirt, unten Haut)."""
    dx, dy = e[0] - s[0], e[1] - s[1]; l = math.hypot(dx, dy); nx, ny = -dy / l, dx / l
    if nx * (100 - s[0]) < 0: nx, ny = -nx, -ny
    kappe = (s[0] + dx * .14 + nx * 1.5 * d, s[1] + dy * .14 + ny * 1.5 * d)
    biz = (s[0] + dx * .55 - nx * 2 * m * d, s[1] + dy * .55 - ny * 2 * m * d)
    mus = [(kappe, (10.5 + 2.5 * m) * d), (biz, (9.5 + 2.2 * m) * d)] if m > 0 else []
    o = strich(s, e, kontur(TOP), 25 * d) + "".join(kreis(c, r + 3 * d, kontur(TOP)) for c, r in mus)
    o += strich(e, h, kontur(HAUT), 21 * d) + strich(e, h, HAUT, 15.5 * d)
    o += strich(s, e, TOP, 19 * d) + "".join(kreis(c, r, TOP) for c, r in mus)
    return o + kreis(h, 9.5 * min(d, 1.12), HAUT, kontur(HAUT))

def arm_frei(s, e, h, d, saum=0.5):
    """Neu: Oberarm = Haut mit kurzem Shirt-Aermel bis `saum`, Unterarm Haut, schmaler, ohne Beulen."""
    sx = (s[0] + (e[0] - s[0]) * saum, s[1] + (e[1] - s[1]) * saum)
    o = strich(s, e, kontur(HAUT), 17 * d) + strich(e, h, kontur(HAUT), 15.5 * d)
    o += strich(s, e, HAUT, 12 * d) + strich(e, h, HAUT, 11 * d)
    # Aermel: breiter als der Arm, gerader Saum
    o += strich(s, sx, kontur(TOP), 24 * d) + strich(s, sx, TOP, 18.5 * d)
    return o + kreis(h, 8 * d, HAUT, kontur(HAUT), 3)

def figur(prefix, torso_d, arme):
    s = bau.ahmed_B(prefix)
    gr = []
    for g in s.gruppen:
        if f'id="{prefix}torso-hint"' in g:
            gr.append(f'<g>{torso_d}</g>')
        else:
            gr.append(g)
    gr.append(f"<g>{arme}</g>")
    s.gruppen = gr
    return s.text(prefix)

def shirt(d):
    return (f'<path d="{d}" fill="#{TOP}" stroke="#{kontur(TOP)}" stroke-width="3.5" stroke-linejoin="round"/>'
            + f'<path d="M86,161 Q100,178 114,161" fill="none" stroke="#{kontur(TOP)}" stroke-width="2" stroke-opacity="0.5"/>')

def aermel_trapez(s, e, saum, b0, b1):
    """Kurzer Aermel als Trapez entlang des Oberarms: Breite b0 an der Schulter, b1 am geraden Saum."""
    hx, hy = s[0] + (e[0] - s[0]) * saum, s[1] + (e[1] - s[1]) * saum
    dx, dy = e[0] - s[0], e[1] - s[1]; l = math.hypot(dx, dy); nx, ny = -dy / l, dx / l
    # Schulter leicht rund: Kontrollpunkt ueber der Schulter
    a1 = (s[0] + nx * b0 / 2, s[1] + ny * b0 / 2); a2 = (s[0] - nx * b0 / 2, s[1] - ny * b0 / 2)
    h1 = (hx + nx * b1 / 2, hy + ny * b1 / 2); h2 = (hx - nx * b1 / 2, hy - ny * b1 / 2)
    kap = (s[0] - dx / l * b0 * 0.55, s[1] - dy / l * b0 * 0.55)
    d = f"M{f(h1[0])},{f(h1[1])} L{f(a1[0])},{f(a1[1])} Q{f(kap[0])},{f(kap[1])} {f(a2[0])},{f(a2[1])} L{f(h2[0])},{f(h2[1])} Z"
    return f'<path d="{d}" fill="#{TOP}" stroke="#{kontur(TOP)}" stroke-width="3.2" stroke-linejoin="round"/>'

def arm_d(s, e, h, d=1.0, saum=0.55, b0=22, b1=25):
    o = strich(s, e, kontur(HAUT), 16.5 * d) + strich(e, h, kontur(HAUT), 15 * d)
    o += strich(s, e, HAUT, 11.5 * d) + strich(e, h, HAUT, 10.5 * d)
    o += aermel_trapez(s, e, saum, b0 * d, b1 * d)
    return o + kreis(h, 8 * d, HAUT, kontur(HAUT), 3)

def rumpf_rund(fx, schulter_y=170):
    """rumpf mit runder, tiefer liegender Schulter statt Kante."""
    X = lambda x: f(100 + (x - 100) * fx)
    return (f"M{X(34)},240 L{X(36)},204 C{X(37)},184 {X(52)},{schulter_y} {X(74)},165 L{X(86)},161 Q100,178 {X(114)},161 "
            f"L{X(126)},165 C{X(148)},{schulter_y} {X(163)},184 {X(164)},204 L{X(166)},240 Z")

VAR = []
# Heute: Athletisch, breite 1.2, armHalb 1.16, muskel 0.7
b = 1.2
VAR.append(("Heute", "Athletisch 1,2 breit, Arme im Shirt", shirt(rumpf(b)),
            arm_alt((100 - 40 * b, 184), (42, 216), (46, 252), 1.16, .7) + arm_alt((100 + 40 * b, 184), (158, 216), (154, 252), 1.16, .7)))
# A: schmaler, gleiche Machart
b = 0.98
VAR.append(("A", "Schmaler (0,98), kleine Beulen", shirt(rumpf(b)),
            arm_alt((100 - 40 * b, 184), (100 - 60, 218), (100 - 57, 252), 1.0, .3) + arm_alt((100 + 40 * b, 184), (160, 218), (157, 252), 1.0, .3)))
# B: Shirt als Rumpf mit runden Schultern, Arme haengen daneben (Aermel + Haut)
TB = "M50,240 L51,206 C51,186 60,172 77,166 L87,162 Q100,176 113,162 L123,166 C140,172 149,186 149,206 L150,240 Z"
VAR.append(("B", "Arme frei neben dem Rumpf", shirt(TB),
            arm_frei((57, 184), (47, 222), (50, 254), 1.05) + arm_frei((143, 184), (153, 222), (150, 254), 1.05)))
# C: wie B, Schultern etwas breiter, Arme leicht nach aussen, Taille schmaler
TC = "M54,240 L52,210 C49,188 58,171 77,165 L87,162 Q100,176 113,162 L123,165 C142,171 151,188 148,210 L146,240 Z"
VAR.append(("C", "Breitere Schultern, schmale Taille", shirt(TC),
            arm_frei((55, 182), (42, 220), (44, 254), 1.1, .45) + arm_frei((145, 182), (158, 220), (156, 254), 1.1, .45)))

b = 0.9
VAR.append(("D", "Aermel als Stoff, Arm darunter", shirt(rumpf_rund(b)),
            arm_d((100 - 40 * b, 186), (38, 222), (41, 256)) + arm_d((100 + 40 * b, 186), (162, 222), (159, 256))))
b = 0.84
VAR.append(("E", "wie D, schlanker", shirt(rumpf_rund(b)),
            arm_d((100 - 40 * b, 186), (42, 222), (45, 256), 0.95) + arm_d((100 + 40 * b, 186), (158, 222), (155, 256), 0.95)))

def v_rumpf(sx, sy, tx, ax, ay=198):
    """V-Taper-Shirt: Schulteransatz (sx|sy), Achsel (ax|ay), Taille unten (tx|240). Spiegelung an x=100."""
    M_ = lambda x: f(200 - x)
    return (f"M{f(tx)},240 L{f(ax)},{ay} C{f(ax-3)},{ay-12} {f(sx-4)},{sy+4} {f(sx+18)},{sy-6} L86,161 Q100,178 114,161 "
            f"L{M_(sx+18)},{sy-6} C{M_(sx-4)},{sy+4} {M_(ax-3)},{ay-12} {M_(ax)},{ay} L{M_(tx)},240 Z")

def brust(tiefe=1.0, op=0.35):
    k = kontur(TOP)
    o = ""
    for sd in (-1, 1):
        X = lambda dx: f(100 + sd * dx)
        o += f'<path d="M{X(34)},{f(194)} Q{X(20)},{f(208+4*tiefe)} {X(3)},{f(204)}" fill="none" stroke="#{k}" stroke-width="2.4" stroke-linecap="round" stroke-opacity="{op}"/>'
    o += f'<path d="M100,208 L100,240" stroke="#{k}" stroke-width="1.8" stroke-opacity="{op*0.6}"/>'
    return o

def arm_v(s, e, h, dick=1.0, saum=0.5, b0=30, b1=26):
    """Muskuloeser Arm: runde Schulter (Deltoid) im Aermel, Bizeps-Wulst am Oberarm, Unterarm schmaler."""
    o = strich(s, e, kontur(HAUT), 20 * dick) + strich(e, h, kontur(HAUT), 16.5 * dick)
    o += strich(s, e, HAUT, 14.5 * dick) + strich(e, h, HAUT, 11.5 * dick)
    o += aermel_trapez(s, e, saum, b0 * dick, b1 * dick)
    return o + kreis(h, 8.5 * dick, HAUT, kontur(HAUT), 3)

VAR = []
VAR.append(("V1", "V-Taper", shirt(v_rumpf(52, 172, 66, 58)) + brust(),
            arm_v((52, 180), (34, 226), (36, 262)) + arm_v((148, 180), (166, 226), (164, 262))))
VAR.append(("V2", "V-Taper stark", shirt(v_rumpf(48, 172, 69, 56)) + brust(1.3, 0.4),
            arm_v((48, 180), (29, 226), (31, 262), 1.12, 0.5, 33, 28) + arm_v((152, 180), (171, 226), (169, 262), 1.12, 0.5, 33, 28)))
VAR.append(("V3", "V-Taper, enges Shirt", shirt(v_rumpf(54, 170, 70, 60)) + brust(1.5, 0.45),
            arm_v((52, 180), (35, 226), (37, 262), 1.05, 0.42, 29, 24) + arm_v((148, 180), (165, 226), (163, 262), 1.05, 0.42, 29, 24)))

def shirt_v(sch, taille, saum_t=0.5, arm_b=13.5, delt=1.0):
    """Ein Pfad fuer Shirt + Aermel: Taille -> Achsel -> Aermel innen -> Saum -> runde Schulter (Deltoid)
    -> Trapez-Linie zum Ausschnitt. `sch` = Schulterpunkt des Arms (x), Arm geht nach (sch-18|228)."""
    s_, e_ = (sch, 182), (sch - 18, 228)
    dx, dy = e_[0] - s_[0], e_[1] - s_[1]; l = math.hypot(dx, dy); ux, uy = dx / l, dy / l; nx, ny = uy, -ux
    if nx > 0: nx, ny = -nx, -ny
    p = (s_[0] + dx * saum_t, s_[1] + dy * saum_t)
    ho = (p[0] + nx * arm_b, p[1] + ny * arm_b); hi = (p[0] - nx * arm_b, p[1] - ny * arm_b)
    top = (sch + 12, 168)
    achsel = (hi[0] + 8, hi[1] - 9)
    L = [("M", (taille, 240)), ("L", achsel), ("L", hi), ("L", ho),
         ("C", (ho[0] - 6 * delt, ho[1] - 18 * delt), (top[0] - 20 * delt, top[1] - 2 * delt), top),
         ("Q", (76, 161), (86, 161))]
    def txt(seq, spiegel):
        X = (lambda x: 200 - x) if spiegel else (lambda x: x)
        o = ""
        for c, *pts in seq:
            o += c + " ".join(f"{f(X(a))},{f(b)}" for a, b in pts) + " "
        return o
    links = txt(L, False)
    # rechte Seite rueckwaerts: Ausschnitt -> Schulter -> Saum -> Achsel -> Taille
    R = [("Q", (124, 161), (200 - top[0], top[1])),
         ("C", (200 - (top[0] - 20 * delt), top[1] - 2 * delt), (200 - (ho[0] - 6 * delt), ho[1] - 18 * delt), (200 - ho[0], ho[1])),
         ("L", (200 - hi[0], hi[1])), ("L", (200 - achsel[0], achsel[1])), ("L", (200 - taille, 240))]
    rechts = "Q100,178 114,161 " + "".join(c + " ".join(f"{f(a)},{f(b)}" for a, b in pts) + " " for c, *pts in R)
    return links + rechts + "Z", s_, e_

def arm_haut(s, e, h, dick=1.0):
    o = strich(s, e, kontur(HAUT), 24 * dick) + strich(e, h, kontur(HAUT), 19 * dick)
    o += strich(s, e, HAUT, 18.5 * dick) + strich(e, h, HAUT, 13.5 * dick)
    return o + kreis(h, 9.5 * dick, HAUT, kontur(HAUT), 3)

def v_variante(sch, taille, arm_b, delt, brust_op, dick):
    d, s_, e_ = shirt_v(sch, taille, 0.5, arm_b, delt)
    h_ = (e_[0] + 2, 262)
    arme = arm_haut(s_, e_, h_, dick) + arm_haut((200 - s_[0], s_[1]), (200 - e_[0], e_[1]), (200 - h_[0], h_[1]), dick)
    # Arme zuerst, Shirt darueber: Aermel deckt den Oberarm
    return arme + shirt(d) + (brust(1.2, brust_op) if brust_op else ""), ""

VAR = []
for n, u, args in [("V4", "V-Taper", (50, 68, 13.5, 1.0, 0.3, 1.0)),
                   ("V5", "V-Taper stark", (46, 70, 15, 1.2, 0.38, 1.1)),
                   ("V6", "V-Taper sehr stark", (42, 72, 16.5, 1.35, 0.45, 1.2))]:
    t, a = v_variante(*args)
    VAR.append((n, u, t, a))
b = 1.2
VAR.insert(0, ("Heute", "jetzt in der App", shirt(rumpf(b)),
               arm_alt((100 - 40 * b, 184), (42, 216), (46, 252), 1.16, .7) + arm_alt((100 + 40 * b, 184), (158, 216), (154, 252), 1.16, .7)))

karten = "".join(f'<div class="k">{figur(f"v{i}-", t, a)}<b>{n}</b><span>{u}</span></div>' for i, (n, u, t, a) in enumerate(VAR))
html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
body{{margin:0;padding:24px;background:#FBF7F4;font:15px -apple-system,Segoe UI,sans-serif;color:#2A2024}}
.r{{display:flex;gap:16px}} .k{{background:#fff;border-radius:16px;padding:8px;display:flex;flex-direction:column;align-items:center}}
.k svg{{width:300px;height:360px}} b{{font-size:18px}} span{{color:#8A7D82;font-size:13px}}
</style></head><body><div class="r">{karten}</div></body></html>"""
open(os.path.join(HIER, "koerper.html"), "w", encoding="utf-8").write(html)
print("ok")
