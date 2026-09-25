"""Figur-Redesign Schritt 2b: Arme als eine durchgehende Form (Ahmed 25.09.: 'sieht aus wie Lego, aufgeklebt').
`python arme.py` -> arme.html; Screenshot -> arme.png."""
import math, os
import bau, koerper as K
from bau import kontur, f

HIER = os.path.dirname(os.path.abspath(__file__))
HAUT, TOP = K.HAUT, K.TOP

def norm(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]; l = math.hypot(dx, dy) or 1
    return -dy / l, dx / l

def arm_umriss(s, e, h, ws, we, wh, kappe_s=0.0, kappe_h=0.6):
    """Ein geschlossener Umriss: Schulter (Breite ws) -> Ellbogen (we) -> Handgelenk (wh).
    Aussen- und Innenkante laufen weich durch den Ellbogen; die Enden sind flache Bogen
    (`kappe_*` = wie weit der Bogen ueber das Ende hinaus ragt, in Breiten)."""
    n1 = norm(s, e); n2 = norm(e, h)
    nm = ((n1[0] + n2[0]) / 2, (n1[1] + n2[1]) / 2); l = math.hypot(*nm) or 1; nm = (nm[0] / l, nm[1] / l)
    P = lambda p, n, w: (p[0] + n[0] * w / 2, p[1] + n[1] * w / 2)
    a1, a2, a3 = P(s, n1, ws), P(e, nm, we), P(h, n2, wh)
    b1, b2, b3 = P(s, n1, -ws), P(e, nm, -we), P(h, n2, -wh)
    ux, uy = (h[0] - e[0]), (h[1] - e[1]); ul = math.hypot(ux, uy) or 1
    tip = (h[0] + ux / ul * wh * kappe_h, h[1] + uy / ul * wh * kappe_h)
    vx, vy = (s[0] - e[0]), (s[1] - e[1]); vl = math.hypot(vx, vy) or 1
    top = (s[0] + vx / vl * ws * kappe_s, s[1] + vy / vl * ws * kappe_s)
    pt = lambda p: f"{f(p[0])},{f(p[1])}"
    return (f"M{pt(a1)} Q{pt(a2)} {pt(a3)} Q{pt(tip)} {pt(b3)} Q{pt(b2)} {pt(b1)} Q{pt(top)} {pt(a1)} Z")

def arm_haut(s, e, h, dick):
    return f'<path d="{arm_umriss(s, e, h, 26 * dick, 20 * dick, 15 * dick, 0.3, 0.9)}" fill="#{HAUT}" stroke="#{kontur(HAUT)}" stroke-width="3" stroke-linejoin="round"/>'

def aermel(s, e, h, dick, saum_y, rumpf_d, cid):
    """Aermel = weiterer Arm-Umriss mit Deltoid-Bogen oben, geclippt ueber dem Saum. Auf dem Rumpf ohne
    Kontur nachgefuellt, damit Schulter und Aermel eine Flaeche sind."""
    d = arm_umriss(s, e, h, 34 * dick, 29 * dick, 27 * dick, 0.55, 0.4)
    k = kontur(TOP)
    clip = f'<clipPath id="{cid}"><path d="M0,0 L200,0 L200,{f(saum_y)} L0,{f(saum_y + 5)} Z"/></clipPath>'
    rclip = f'<clipPath id="{cid}r"><path d="{rumpf_d}"/></clipPath>'
    return (clip + rclip + f'<g clip-path="url(#{cid})"><path d="{d}" fill="#{TOP}" stroke="#{k}" stroke-width="3.2" stroke-linejoin="round"/>'
            f'<g clip-path="url(#{cid}r)"><path d="{d}" fill="#{TOP}"/></g></g>')

def rumpf_v(sch, taille):
    """V-Rumpf mit runder Schulter bis ueber den Arm (wie shirt_v, ohne eigene Aermel)."""
    M_ = lambda x: f(200 - x)
    return (f"M{f(taille)},240 L{f(sch+8)},200 C{f(sch-2)},186 {f(sch-8)},172 {f(sch+10)},166 L86,161 Q100,178 114,161 "
            f"L{M_(sch+10)},166 C{M_(sch-8)},172 {M_(sch-2)},186 {M_(sch+8)},200 L{M_(taille)},240 Z")

def variante(sch, taille, dick, saum_t, arm_dx, name):
    rd = rumpf_v(sch, taille)
    s = (sch + 6, 178); e = (sch - arm_dx, 226); h = (sch - arm_dx + 2, 258)
    saum = s[1] + (e[1] - s[1]) * saum_t
    sR, eR, hR = (200 - s[0], s[1]), (200 - e[0], e[1]), (200 - h[0], h[1])
    hinten = arm_haut(s, e, h, dick) + arm_haut(sR, eR, hR, dick)
    vorn = aermel(s, e, h, dick, saum, rd, name + "L") + aermel(sR, eR, hR, dick, saum, rd, name + "R")
    return hinten + K.shirt(rd) + K.brust(1.2, 0.3), vorn

VAR = []
for n, u, a in [("A1", "V4, Arm eine Form", (50, 68, 1.0, 0.5, 14, "a1")),
                ("A2", "V4, Arm naeher am Koerper", (52, 68, 1.0, 0.5, 10, "a2")),
                ("A3", "V5 Gym-Breite", (46, 70, 1.12, 0.5, 14, "a3"))]:
    t, ar = variante(*a)
    VAR.append((n, u, t, ar))

def figur(prefix, torso_d, arme):
    s = bau.ahmed_B(prefix)
    gr = []
    for g in s.gruppen:
        if f'id="{prefix}torso-hint"' in g:
            gr.append(f'<g>{torso_d}</g>')   # Haut-Arme, dann Rumpf (deckt den Arm-Ansatz)
            gr.append(f"<g>{arme}</g>")      # Aermel vorn, auf dem Rumpf ohne Naht
        else:
            gr.append(g)
    s.gruppen = gr
    return s.text(prefix)

# Reihenfolge: Arme zuerst, dann Rumpf darueber, damit die Schulter den Arm-Ansatz deckt
karten = "".join(f'<div class="k">{figur(f"w{i}-", t, a)}<b>{n}</b><span>{u}</span></div>' for i, (n, u, t, a) in enumerate(VAR))
html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
body{{margin:0;padding:24px;background:#FBF7F4;font:15px -apple-system,Segoe UI,sans-serif;color:#2A2024}}
.r{{display:flex;gap:16px}} .k{{background:#fff;border-radius:16px;padding:8px;display:flex;flex-direction:column;align-items:center}}
.k svg{{width:300px;height:360px}} b{{font-size:18px}} span{{color:#8A7D82;font-size:13px}}
</style></head><body><div class="r">{karten}</div></body></html>"""
open(os.path.join(HIER, "arme.html"), "w", encoding="utf-8").write(html)
print("ok")
