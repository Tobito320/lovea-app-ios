# Figur-Redesign, Schritt 1: Gesichter

Board: `gesichter.png` (Quelle `gesichter.html`). Oben neutral, darunter lächelnd, unten Avatar-Größe 48 px.
Alles wird von `bau.py` erzeugt: `python bau.py` schreibt die 8 SVGs und das HTML neu. Formen dort ändern, nicht in den SVGs.
`heute-*.png` sind Ausschnitte aus dem aktuellen Render, nur für den Vergleich.

## Optionen

**Ahmed A – Clean Anime.** Schmales V-Kinn, große Mandelaugen mit dicker oberer Wimpernlinie und Glanzpunkten, Nase nur als harte Schattenkante.
Harte Cel-Schatten (Pony-Schatten, rechte Wange). Die Locken enden in Spitzen.

**Ahmed B – Bitmoji modern schlank.** Am nächsten an der heutigen App: gleiche Konturfarbe (Haut × 0,55) und Stärke 3,5, aber das Gesicht ist 20 % schmaler und hat Kiefer und Kinn.
Leicht schwere Lider, dicke gerade Brauen, L-Nase, hellrosa Lippen. Keine Rouge-Kreise, nur weiche Wangenschatten.

**Ahmed C – Halb-realistisch flach.** Dünne Kontur (2 px, Haut × 0,7). Schwere Oberlider mit Lidfalte, Nasenrücken als Schattenfläche mit Nasenflügeln, Oberlippe mit Amorbogen.
Licht von links: Seitenverlauf, Augenhöhlen, Wangenhöhle. Dazu Muttermale und Locken als einzelne Schwünge.

**Ahmed D – Sticker-Stil.** Wie `design/ki/sticker`: einheitliche dunkle Kontur 2A1C18 mit 3,8 px, weißer Sticker-Rand, runde Locken mit Glanzbögen.
Warme Haut, nur ein Hauch Wange. Beim Lächeln werden die Augen zu ^^ und der Mund lacht offen.

**Ahmed E – Scharf / cool.** Kantiges Gesicht aus geraden Segmenten mit eckigem Kinn. Halb geschlossene, ruhige Augen, gerade kräftige Brauen, langer gerader Nasenrücken.
Kantige Schattenflächen. Der Schnurrbart ist gestylt, mit leicht hochgezwirbelten Enden. Das Lächeln ist ein Smirk.

**Annika 1 – App-Stil verfeinert.** Schlankes Oval statt Rundgesicht. Mandelaugen mit Lidstrich, blaue Iris wie in der App, volle Lippen.
Rouge nur als weicher Verlauf (30 %). Mittelscheitel: das Haar liegt am Kopf an, statt als Helm abzustehen.

**Annika 2 – Sticker-Stil.** Gleiche Kontur und derselbe weiße Rand wie Ahmed D, damit beide als Paar funktionieren. Etwas größere Augen, kleine Hakennase wie im Sticker.
Beim Lächeln schließen sich die Augen zu ^^ mit Wimper.

**Annika 3 – Soft Anime.** Weiches V-Kinn, große Augen mit Wimpernflick, Nase nur als Strich, kleiner Mund. Dünnere Kontur (3 px).
Wirkt am erwachsensten und ruhigsten.

## Raum und Anker

Gleicher Raum wie die Halbfigur in `FigurView.swift`: 200 × 240. Der Torso ist unverändert `rumpf(0)`, die Halsbox bleibt `box(86,132,28,58,10)` (im SVG 87–113 ab y 128, wegen des Kinnschattens).
Der Hals wird sichtbar, weil das Kinn höher sitzt (Ahmed y 151, Annika y 147, Ausschnitt bei y 161). Den Körper nicht verschieben.

| Anker | alt (App) | neu Ahmed | neu Annika |
|---|---|---|---|
| Wangenknochen halbe Breite | 58 (x 42–158) | 47 (x 53–147) | 46 (x 54–146) |
| Augenmitten | (80\|98), (120\|98) | (81\|101) bei A/B, (81\|102) bei C/D/E | (81\|102), (119\|102) |
| Brauen innen/außen | (90\|80) / (70\|81) | (92\|89) / (69\|86) | (91\|90) / (70\|87) |
| Ohrmitte | (42\|100), (158\|100) | (50\|105), (150\|105) | unter dem Haar, Ohrläppchen ca. (60\|119) / (140\|119) |
| Nasenspitze | (100\|115) | (101\|124) | (100\|120) |
| Mundmitte | (100\|128) | (100\|138) | (100\|134) |
| Schnurrbart | – | y 127–134, x 84–116 | – |
| Kinn unten | 152–162 | 151 (E: 149) | 147 (3: 150) |
| Gesicht oben / Haar oben | 30 / ca. 20 | 26 / 16 | 30 / 20 |

Zubehör, das im alten Raum hart kodiert ist (Brillen, AirPods, Ohrringe, Hut-Clip y 34, alle Frisuren), bekommt eine einfache Abbildung:
`x' = 100 + (x − 100) · 0,81`, `y' = y + 3` für alles zwischen y 80 und 130 (Brillen, Mimik-Effekte an den Augen).
Hüte und Mützen: nur x skalieren. Das Haar oben liegt bei y 16 statt ca. 20, der Hut-Clip bei y 34 kann bleiben.
AirPods sitzen am Ohr bei (54\|110) und (146\|110). Ohrringe bei Annika hängen am Ohrläppchen und liegen über dem Haar.

Die alten Frisuren sind für die breite Kopfform gebaut. Zwei Wege: für die gewählte Option `hair-front`/`hair-back` als neue Frisur übernehmen (Ahmeds Locken mit Taper und schrägem Pony stecken schon drin), und die übrigen Frisuren in `haarKontext` mit `scaleBy(x: 0.81, y: 1)` um x = 100 zeichnen.

## Portierung nach Swift

- SVG-Pfade 1:1: `M` = `move(to:)`, `L` = `addLine(to:)`, `Q c p` = `addQuadCurve(to: p, control: c)`, `C c1 c2 p` = `addCurve(to: p, control1: c1, control2: c2)`, `Z` = `closeSubpath()`. Linke Seite = gespiegelte rechte (`x → 200 − x`). Dafür gibt es schon `gespiegelt()`.
- Fläche mit Kontur = `teil(g, pfad, farbe, breite)`. Striche = `linie()`. `stroke-opacity`/`fill-opacity` = `.opacity()`.
- Verläufe sind alle `userSpaceOnUse`: `.linearGradient(Gradient, startPoint:, endPoint:)`, `.radialGradient(Gradient, center:, startRadius: 0, endRadius: r)`.
- `clipPath` = `var h = g; h.clip(to: pfad)`. Keine Masken, Filter oder Muster.
- Sticker-Rand (D, Annika 2): dieselben Pfade (Haar hinten, Gesicht, Haar vorn, Torso) zuerst weiß mit Strichstärke 12 zeichnen.
- Die `face-shape` ist pro Option ein geschlossener Pfad und ersetzt `kopfPfad`. Damit funktionieren `gedreht()` (3/4-Drehung), `bartZone` und die Clips wie bisher.
- Zeichenreihenfolge = Reihenfolge der Gruppen im SVG: hair-back, neck, torso-hint, ears, face-shape, shading, jaw, taper, goatee, eyes, brows, nose, mustache, mouth, hair-front.
- Farben stammen aus den Presets: Haut „Hell warm“ E8C2A6 / „Hell“ F9D3B8, Haar „Fast schwarz“ 241712 / „Dunkelbraun“ 3B2A20, Iris 3A2418 / 3F74B5. Schnurrbart 5C4030. Lippen Ahmed = Haut gemischt mit E07A8A (38 %).
- Konturen: A und B Haut × 0,55 (wie `kontur`), C Haut × 0,7 mit 2 px, D fest 2A1C18 mit 3,8 px, E Haut × 0,5 mit 3 px.

## Mimik: was wohin gehört

- **Rouge.** `gesicht()` malt heute immer Rosa-Ovale bei (68\|120) mit 28 %. Das ist der Hauptgrund für „aufgedunsen“ und muss für Ahmed weg. Rouge nur noch bei verliebt, verlegen, Kuss und Herz, und dann als radialer Verlauf wie bei Annika. `schmollt` bläht heute die Wangen: bei Ahmed stattdessen nur den Mund ändern.
- **Augen** (`Auge`):
  - `offen(gross:)` ist die Gruppe `eyes`. `gross` = Mandel um die Augenmitte um 1,12 skalieren.
  - `zu` = Bogen entlang der Unterkante der Mandel. Das ist das heutige `geschlossen`, mit Breite 9–10.
  - `froh`: Bei A, B, C, E und Annika 1 und 3 ist `eyes-smile` das Lächeln mit offenem Auge (Unterlid schiebt hoch). Das volle ^^ ist bei D und Annika 2 `eyes-smile` und passt als `froh` für alle Optionen.
  - `muede` = Lid-Fläche (B und C haben sie schon) bis 55 % herunterziehen. A, D und E brauchen dafür eine Hautfläche, die auf die Mandel geclippt wird.
  - `schock` braucht neue Geometrie bei C und E, weil die Augen dort schmal sind: runde Lederhaut ca. 11 × 13 um dieselbe Mitte, kleine Pupille.
  - `boese` = heutiges Schräglid, auf die Mandel geclippt. E sieht schon fast so aus.
  - Blinzeln (`zyklus(4.2)`) bleibt und nutzt `zu`.
- **Brauen:** Die Verschiebungen (hoch, traurig, staunen, boese, denkt) wirken auf die neuen End- und Kontrollpunkte (Tabelle oben). Die Brauen von A, C, E und Annika sind gefüllte Flächen. Alle Punkte gemeinsam verschieben, die innere Spitze extra für boese und traurig.
- **Mund** (`Mund`):
  - `neutral` = `mouth-neutral`.
  - `laecheln`, `grinsen` und `zaehne` = `mouth-smile`. Bei E ist das Lächeln geschlossen (Smirk). Für `zaehne` dort den offenen Mund aus B nehmen.
  - `offen(x)` = `mouth-smile` vertikal mit x skalieren.
  - `kuss`, `schmoll`, `traurig`, `wellig`, `heulen` und `schief` bleiben die heutigen Formen. Sie werden auf die neue Mundmitte verschoben und auf 0,85 skaliert.
  - Der Schnurrbart liegt immer über dem Mund und wandert bei `offen` 1–2 px nach oben.
- **Bart:** `goatee` ist ein leichter Kinnbart mit Kinnschatten. Der Schnurrbart ist dünn, bei E gestylt. Beide entsprechen `kinnbart = 1` und `bart = 14`, nur mit neuer Form.
- **Mimik-Effekte** (Tränen, Schweiß, Herzen): Die Positionen an den Augen mit derselben Abbildung wie die Brillen umrechnen.

## Offen

- Annikas Iris bleibt blau wie im App-Preset. In einigen KI-Stickern ist sie braun, das soll Annika entscheiden.
- Der Körper ist nicht Teil dieses Schritts. Die Schultern von `rumpf(0)` sind 140 breit. Zu den schmaleren Köpfen passt das gut, ein athletischer Körper wirkt jetzt aber breiter als vorher.
