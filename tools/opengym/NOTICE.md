# Herkunft der Muskelkarte

Die Körperumrisse in `Lovea/Sources/Health/Koerper/muskelkarte.json` kommen aus `body-paths.js`
(in diesem Ordner). Erzeugt mit `node tools/muskelkarte-bauen.mjs`.

- **openGym** (https://github.com/DuarteSantos8/openGym, `frontend/src/lib/body-paths.js`,
  Commit `ce30c7304bdeb66a6eb4a3d14821a06035523b06`), Lizenz AGPL-3.0, Text in
  `LICENSE-openGym-AGPL-3.0.txt`. Der Besitzer von Lovea hat die Übernahme für die private App freigegeben.
- Die Geometrie darin stammt von **MuscleMap** von Melih Colpan (https://github.com/melihcolpan/MuscleMap),
  MIT-Lizenz (Text unten). openGym hat die Pfade in ein JSON-Modul umgewandelt und die Untergruppen weggelassen.
- Aus openGym ist nur `body-paths.js` übernommen. Keine Übungsbilder oder GIFs (ExerciseDB), keine
  weiteren openGym-Dateien.

## MuscleMap, MIT License


Copyright (c) 2026 Melih Colpan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
