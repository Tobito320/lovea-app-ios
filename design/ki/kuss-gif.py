"""Smooth kiss loop for the "Wir" sticker tab (wir-kuss-echt.gif).

Source: roh/kuss-4.png, a 2x2 grid (look, lips close, kiss, kiss with hearts), untracked.
    python design/ki/kuss-gif.py [path/to/kuss-4.png] [out.gif]
Needs Pillow, numpy and ffmpeg on PATH.

Every frame lasts the same 50 ms: the app plays GIFs via UIImage.animatedImage, which ignores
per-frame delays, so holds are duplicate frames (almost free in the file thanks to transdiff).
Frame 0 is the kiss with hearts, the still the app shows under Reduce Motion.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

HIER = Path(__file__).resolve().parent
QUELLE = Path(sys.argv[1]) if len(sys.argv) > 1 else HIER / "roh" / "kuss-4.png"
ZIEL = Path(sys.argv[2]) if len(sys.argv) > 2 else HIER.parent.parent / "Lovea/Sources/Chat/Medien/StickerGIFs/wir-kuss-echt.gif"
FPS, W, H = 20, 480, 400
CW, CH = 660, 550  # crop inside each panel, 6:5 like the output

# Panel origins inside the 2x2 grid (white separators at x 683-690, y 570-575), plus a per-panel
# shift and zoom (found by a difference search) so the two kiss panels line up and only the
# hearts change between them. The other panels differ in pose, a crossfade carries those.
PANELS = [(0, 0), (691, 0), (0, 576), (691, 576)]
LAGE = [(0, 0, 1), (0, 0, 1), (0, 0, 1), (1, 3, 1.03)]
# Camera per keyframe: zoom and focus (fraction of the crop), eased in during transitions.
# ponytail: flat on purpose, a 1.00 -> 1.08 push-in looked nice but cost +460 KB (every pixel
# moves); raise the zooms here if size stops mattering.
KAMERA = [(1.00, 0.50, 0.50)] * 4

# (from, to, frames): a hold when from == to. 100 frames = 5 s. Starts on the kiss with hearts.
ABLAUF = [(3, 3, 18), (3, 0, 10), (0, 0, 20), (0, 1, 7), (1, 1, 12), (1, 2, 7), (2, 2, 16), (2, 3, 10)]
SCHWELLE, REIN = 12, 7


def ease(t):
    return t * t * (3 - 2 * t)


def panel(bild, i):
    dx, dy, s = LAGE[i]
    x = PANELS[i][0] + 341.5 + dx - CW / s / 2
    y = PANELS[i][1] + 285 + dy - CH / s / 2
    return bild.resize((CW, CH), Image.LANCZOS, box=(x, y, x + CW / s, y + CH / s))


def aufnahme(p, kamera):
    zoom, fx, fy = kamera
    bw, bh = CW / zoom, CH / zoom
    x0 = min(max(fx * CW - bw / 2, 0), CW - bw)
    y0 = min(max(fy * CH - bh / 2, 0), CH - bh)
    return np.asarray(p.resize((W, H), Image.LANCZOS, box=(x0, y0, x0 + bw, y0 + bh)), dtype=np.float32)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def bilder():
    quelle = Image.open(QUELLE).convert("RGB")
    panels = [panel(quelle, i) for i in range(4)]
    vorher = None
    for von, nach, n in ABLAUF:
        for k in range(n):
            t = 1.0 if von == nach else ease((k + 1) / (n + 1))
            kamera = mix(KAMERA[von], KAMERA[nach], t)
            bild = aufnahme(panels[von], kamera) * (1 - t) + aufnahme(panels[nach], kamera) * t
            # Lossy delta: during a transition a pixel only updates once it drifted more than
            # SCHWELLE from what is shown, so near-unchanged runs become transparent in the GIF.
            # A hold cleans up to REIN levels, or faint ghosts would linger on the flat pink.
            if vorher is not None:
                ruhig = np.abs(bild - vorher).max(axis=2) < (REIN if von == nach else SCHWELLE)
                bild[ruhig] = vorher[ruhig]
            vorher = bild
            yield bild


def main():
    with tempfile.TemporaryDirectory() as tmp:
        for i, f in enumerate(bilder()):
            Image.fromarray(np.clip(f + 0.5, 0, 255).astype(np.uint8)).save(f"{tmp}/f{i:03d}.png")
        filter_ = ("split[a][b];[a]palettegen=stats_mode=full[p];"
                   "[b][p]paletteuse=dither=none:diff_mode=rectangle")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{tmp}/f%03d.png",
                        "-filter_complex", filter_, "-loop", "0", str(ZIEL)], check=True)
    gif = Image.open(ZIEL)
    print(ZIEL.name, gif.size, gif.n_frames, "frames", round(ZIEL.stat().st_size / 1024), "KB")
    assert gif.n_frames == sum(n for *_, n in ABLAUF) and ZIEL.stat().st_size < 1.5 * 1024 * 1024


if __name__ == "__main__":
    main()
