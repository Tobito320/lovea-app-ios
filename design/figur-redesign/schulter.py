"""Halbfigur-Schulter exakt wie in der App (vRumpf + armUmriss + Aermel bis Saum 0.5), zum Nachbessern.
`python schulter.py` -> schulter.html """
import math, os
import bau
from bau import kontur, f
HIER = os.path.dirname(os.path.abspath(__file__))
HAUT, TOP = bau.AH["haut"], bau.AH["top"]

def einheit(x, y):
    l = max(1e-3, math.hypot(x, y)); return x / l, y / l

def arm_umriss(s, e, h, ws, we, wh, kS, kH):
    u1 = einheit(e[0] - s[0], e[1] - s[1]); n1 = (-u1[1], u1[0])
    u2 = einheit(h[0] - e[0], h[1] - e[1]); n2 = (-u2[1], u2[0])
    nm = einheit(n1[0] + n2[0], n1[1] + n2[1])
    P = lambda p, n, w: (p[0] + n[0] * w / 2, p[1] + n[1] * w / 2)
    a1, a2, a3 = P(s, n1, ws), P(e, nm, we), P(h, n2, wh)
    b1, b2, b3 = P(s, n1, -ws), P(e, nm, -we), P(h, n2, -wh)
    u = einheit(h[0] - e[0], h[1] - e[1]); v = einheit(s[0] - e[0], s[1] - e[1])
    sp = (h[0] + u[0] * wh * kH, h[1] + u[1] * wh * kH); ob = (s[0] + v[0] * ws * kS, s[1] + v[1] * ws * kS)
    q = lambda p: f"{f(p[0])},{f(p[1])}"
    return f"M{q(a1)} Q{q(a2)} {q(a3)} Q{q(sp)} {q(b3)} Q{q(b2)} {q(b1)} Q{q(ob)} {q(a1)} Z"

def halbebene(s, e, saum):
    u = einheit(e[0] - s[0], e[1] - s[1]); n = (-u[1], u[0])
    m = (s[0] + (e[0] - s[0]) * saum, s[1] + (e[1] - s[1]) * saum)
    pts = [(m[0] + n[0] * 300, m[1] + n[1] * 300), (m[0] - n[0] * 300, m[1] - n[1] * 300),
           (m[0] - n[0] * 300 - u[0] * 400, m[1] - n[1] * 300 - u[1] * 400), (m[0] + n[0] * 300 - u[0] * 400, m[1] + n[1] * 300 - u[1] * 400)]
    return "M" + " L".join(f"{f(x)},{f(y)}" for x, y in pts) + " Z"

def v_rumpf(sch, taille, armB, schulter_y=164, dx=(3, 1), y2=168):
    s, e = (sch, 182), (sch - 18, 228)
    dxx, dyy = e[0] - s[0], e[1] - s[1]; l = math.hypot(dxx, dyy)
    a = (s[0] + dxx * .5 + dyy / l * armB + 8, s[1] + dyy * .5 - dxx / l * armB - 9)
    M_ = lambda x: f(200 - x)
    return (f"M{f(taille)},240 L{f(a[0])},{f(a[1])} C{f(a[0]-dx[0])},{f(a[1]-15)} {f(a[0]-dx[1])},{f(y2)} 72,{schulter_y} "
            f"L86,161 Q100,178 114,161 L128,{schulter_y} C{M_(a[0]-dx[1])},{f(y2)} {M_(a[0]-dx[0])},{f(a[1]-15)} {M_(a[0])},{f(a[1])} L{M_(taille)},240 Z")

def variante(name, sch=50, taille=68, armB=13.5, stoff=(34, 29, 27, .55, .4), rumpf_kw={}, kappe_mitte=None):
    rumpf_kw = rumpf_kw if rumpf_kw == "rund" else dict(rumpf_kw)
    s = (sch, 182); e = (sch - 18, 228); h = (sch - 16, 262)
    sR, eR, hR = (200 - s[0], s[1]), (200 - e[0], e[1]), (200 - h[0], h[1])
    rd = v_rumpf_rund(sch, taille, armB) if rumpf_kw == "rund" else v_rumpf(sch, taille, armB, **rumpf_kw)
    kS = 0.0 if rumpf_kw == "rund" else 0.3
    arme = "".join(f'<path d="{arm_umriss(a, b, c, 26, 20, 15, kS, .9)}" fill="#{HAUT}" stroke="#{kontur(HAUT)}" stroke-width="3"/>' for a, b, c in [(s, e, h), (sR, eR, hR)])
    cid = name
    teile = [(rd, None)]
    defs = ""
    for i, (a, b, c) in enumerate([(s, e, h), (sR, eR, hR)]):
        defs += f'<clipPath id="{cid}{i}"><path d="{halbebene(a, b, .5)}"/></clipPath>'
        teile.append((arm_umriss(a, b, c, *stoff), f"{cid}{i}"))
    # Vereinigung simuliert: erst alle Konturen, dann alle Flaechen
    k = kontur(TOP)
    konturen = "".join(f'<path d="{d}" fill="none" stroke="#{k}" stroke-width="3.5" stroke-linejoin="round"' + (f' clip-path="url(#{c})"' if c else "") + "/>" for d, c in teile)
    flaechen = "".join(f'<path d="{d}" fill="#{TOP}"' + (f' clip-path="url(#{c})"' if c else "") + "/>" for d, c in teile)
    return defs, arme + konturen + flaechen

def figur(prefix, defs, koerper):
    s = bau.ahmed_B(prefix)
    s.defs.append(defs)
    s.gruppen = [f"<g>{koerper}</g>" if f'id="{prefix}torso-hint"' in g else g for g in s.gruppen]
    return s.text(prefix)

def v_rumpf_rund(sch, taille, armB):
    """Rumpf mit eigener runder Schulter bis ueber den Oberarm-Ansatz (Deltoid)."""
    s, e = (sch, 182), (sch - 18, 228)
    dxx, dyy = e[0] - s[0], e[1] - s[1]; l = math.hypot(dxx, dyy)
    a = (s[0] + dxx * .5 + dyy / l * armB + 8, s[1] + dyy * .5 - dxx / l * armB - 9)
    L = [("L", a), ("C", (a[0] - 2, a[1] - 14), (sch - 17, 190), (sch - 16, 180)),
         ("C", (sch - 15, 170), (sch - 5, 163), (sch + 10, 162)), ("Q", (78, 159), (86, 161))]
    R = [("Q", (122, 159), (200 - sch - 10, 162)), ("C", (200 - sch + 5, 163), (200 - sch + 15, 170), (200 - sch + 16, 180)),
         ("C", (200 - sch + 17, 190), (200 - a[0] + 2, a[1] - 14), (200 - a[0], a[1])), ("L", (200 - taille, 240))]
    q = lambda p: f"{f(p[0])},{f(p[1])}"
    d = f"M{f(taille)},240 " + " ".join(c + " ".join(q(p) for p in pts) for c, *pts in L)
    d += " Q100,178 114,161 " + " ".join(c + " ".join(q(p) for p in pts) for c, *pts in R) + " Z"
    return d

VAR = [("Heute (App)", {}), ("S1: Stoff-Kappe flach", dict(stoff=(34, 29, 27, .15, .4))),
       ("S2: Schulter breiter", dict(stoff=(36, 29, 27, .2, .4), rumpf_kw=dict(schulter_y=163, dx=(6, 8), y2=166))),
       ("S4: Schulter im Koerper", dict(stoff=(33, 29, 27, .0, .4), rumpf_kw="rund")),
       ("S5: wie S4, V5 Gym", dict(sch=46, taille=70, armB=15, stoff=(36, 31, 29, .0, .4), rumpf_kw="rund"))]
karten = ""
for i, (n, kw) in enumerate(VAR):
    d, k = variante(f"v{i}", **kw)
    karten += f"<div class='k'>{figur(f's{i}-', d, k)}<b>{n}</b></div>"
html = "<!doctype html><html><head><meta charset='utf-8'><style>body{margin:0;padding:20px;background:#FBF7F4;font:15px Segoe UI,sans-serif}.r{display:flex;gap:14px}.k{background:#fff;border-radius:14px;padding:8px;text-align:center}.k svg{width:280px;height:336px}</style></head><body><div class='r'>" + karten + "</div></body></html>"
open(os.path.join(HIER, "schulter.html"), "w", encoding="utf-8").write(html)
print("ok")
