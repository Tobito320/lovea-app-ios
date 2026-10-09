"""Annika im Gym: Haare zurueck mit hohem Zopf, Sport-Top, nackte Arme. -> annika_gym.html"""
import os, bau
from bau import kontur, mal, mix, f, teil, linie, fill, AN
HIER = os.path.dirname(os.path.abspath(__file__))
HAAR = AN["haar"]; HAUT = "F9D3B8"; TOP = "F4A7C0"

KAPPE = ("M100,30 C73,30 55,45 55,72 C55,84 58,93 61,99 C64,82 76,66 100,64 C124,66 136,82 139,99 "
         "C142,93 145,84 145,72 C145,45 127,30 100,30 Z")
ZOPF = ("M117,37 C140,24 160,40 158,72 C156,100 151,124 146,140 C143,122 141,98 136,76 C132,60 125,47 117,37 Z")
BAND = "M113,33 Q119,29 125,34 L122,41 Q117,37 112,40 Z"
TOP_D = ("M52,240 L55,205 C57,190 66,180 78,176 L88,172 Q100,184 112,172 L122,176 C134,180 143,190 145,205 L148,240 Z")

def gym(prefix):
    s = bau.annika(3, prefix)
    neu = []
    for g in s.gruppen:
        if f'id="{prefix}hair-back"' in g:
            neu.append(f'<g>{teil(ZOPF, mal(HAAR, 0.85), 3, mal(HAAR, 0.55))}</g>')
        elif f'id="{prefix}torso-hint"' in g:
            # Schultern und Arme Haut, darueber das Sport-Top mit schmalen Traegern
            haut = teil("M38,240 L41,200 C43,180 58,168 78,165 L90,161 Q100,172 110,161 L122,165 C142,168 157,180 159,200 L162,240 Z", HAUT, 3.2)
            traeger = linie("M84,176 L78,166", mal(TOP, 0.8), 5) + linie("M116,176 L122,166", mal(TOP, 0.8), 5)
            neu.append(f'<g>{haut}{teil(TOP_D, TOP, 3)}{traeger}</g>')
        elif f'id="{prefix}hair-front"' in g:
            neu.append(f'<g>{teil(KAPPE, HAAR, 3, mal(HAAR, 0.55))}{teil(BAND, "F07C86", 1.5)}'
                       + linie("M100,34 Q80,38 68,58", mix(HAAR, "C9A080", 0.45), 2.2, 0.55) + linie("M100,34 Q120,38 132,58", mix(HAAR, "C9A080", 0.45), 2.2, 0.55) + '</g>')
        else:
            neu.append(g)
    s.gruppen = neu
    return s.text(prefix)

html = ("<!doctype html><html><head><meta charset='utf-8'><style>body{margin:0;padding:20px;background:#FBF7F4}"
        ".k{background:#fff;border-radius:14px;padding:8px;display:inline-block}svg{width:300px;height:360px}</style></head><body>"
        f"<div class='k'>{bau.annika(3, 'n-').text('n')}</div> <div class='k'>{gym('g-')}</div></body></html>")
open(os.path.join(HIER, "annika_gym.html"), "w", encoding="utf-8").write(html)
print("ok")
