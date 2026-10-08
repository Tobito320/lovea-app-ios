# p65 Profil-Szene: plan

Spec: `docs/superpowers/specs/p65-profil-szene.md`. Order from the vault plan: B, A, C, D. One commit per step, tests first. CI is the only compiler (no local Xcode), so every step ends with a push and one CI check; render-gallery PNGs are viewed before any visual claim.

## Progress ledger

- [x] 0 spec + plan committed, branch pushed, draft PR open (target `runde-3`)
- [x] B1 `FigurPose.swift` pure logic + `FigurPoseTests` (tests first)
- [x] B2 engine: `FigurView(pose:)` sit sofa / sit bed edge / lie / wave; gallery boards per person
- [x] A1 `ProfilSlots` + `ProfilPanoramaLayout` pure logic + tests (overlap, 44 pt, zones, two device sizes)
- [x] A2 (CI offen) panorama stage: parallax, zones, dots, fixed scene, floating chips, tap actions, one avatar
- [x] A3 (CI offen) calm area below + three labelled buttons (Profil, Zimmer, Kleidung)
- [x] C1 (CI offen) gender tags fixed, `mitGueltigerKleidung` migration, Ahmed-has-no-women's-items tests
- [x] C2 (CI offen) Settings "Meine Figur" (`FigurEditor.Bereich.figur`); wardrobe in the profile (`.kleidung`: Oberteile, Hosen, Schuhe, Jacken, Accessoires + shop row via `GarderobeLogik`)
- [x] D1 (CI offen) free kit (~5 per person) via `*Shop` sets (`Grundausstattung.swift`), real short names, kit-only outfits, tests updated
- [x] D2 (CI offen) vector brand pieces (`Zubehoer/ModeMarken.swift`: Ralph Lauren, Adidas, Carhartt, The North Face, Nike tops; Air Jordan 1, Nike Dunk Low) built in directly, no switch, no notice; 63 new shop articles incl. Annika's women's catalog; gallery boards `figuren-kleiderschrank-*`, `figuren-marken-nah`
- [x] Z testlist in vault (`19 Bastelprojekte/Lovea – p65 Profil-Szene Testliste.md`), CI green (run 37771977904 on 9826bed, 2123 tests), boards viewed, PR ready, Büro report + Log line

## Step details

### B1 pose logic (pure, `Lovea/Sources/Figuren/FigurPose.swift`)
- `enum FigurPose: Equatable { stehen, gehen, sitzenSofa, sitzenBettkante, liegen, winken }`
- `FigurPoseLogik.pose(fuer: Platz) -> FigurPose`, `huefthoehe(pose, hoehe)`, `kopfOben(pose, hoehe)`, `breite(pose, hoehe)`, `sitzflaeche(pose)` (seat height the sofa must use).
- Tests (`FigurPoseTests`): place -> pose mapping; sitting head top >= 0 inside the figure frame; seat height equals sitting hip height for body sizes klein/mittel/gross; lying frame is wider than tall; walking/standing unchanged.

### B2 engine
- `FigurView.init(..., pose: FigurPose? = nil)`; `Zeichner` receives it. Only these branches change: `haltung` (sit), `beinGelenke` (thighs forward, lower legs down), `poseGanz` (arms rest on thighs / wave), lying = rotate canvas 90 degrees around the hips.
- Reuse `PaarPose`/`KussPaar` as they are.
- Gallery: `RenderGalerieFigurPosenTests` -> boards `figur-posen-ahmed.png`, `figur-posen-annika.png`, `figur-sofa.png`.

### A1 slots and layout (pure)
- `ProfilSlots.alle: [ProfilSlot]` (id, zone, rect in design units, tap rect min 44 pt). `ProfilPanoramaLayout.szeneHoehe(breite:, hoehe:, safeOben:)`.
- Tests: no overlap, gap >= 8 units, 44 pt at width 375 and 430, record player not over frames, every slot in its zone, scene height fits above the fold at 375x667 and 430x932.

### A2/A3 UI
- `ProfileView.kopf` -> fixed `ProfilPanorama` (ScrollView horizontal, `scrollTargetBehavior(.viewAligned)`, `visualEffect` parallax), dots under it. Existing `ZuhauseBuehne` stays the Wohn zone; sleeper/bed zone from `ProfilSzene`.
- Floating "Annika ist online" and gear are overlays inside the scene, not wall decor. The toolbar gear moves.
- Below: date, days together, coins, three labelled buttons.

### C1/C2
- Data: indices only grow. Gender tags corrected; `FigurAussehen.mitGueltigerKleidung`.
- Settings: `NavigationLink("Meine Figur")` -> `FigurEditor` (body tabs). Profile: "Kleidung" -> `GarderobeView` (categories, owned/free/shop state).

### D1/D2
- Free kit per person (about 5), everything else shop-gated in `*Shop` sets and `katalog.json` with real short names and coin prices.
- Brand pieces drawn as vector in `Lovea/Sources/Figuren/Zubehoer/ModeMarken.swift`: Nike, Adidas, Jordan, The North Face, Ralph Lauren, Carhartt; shoes AF1, Jordan 1, Dunk, Samba. The real logos are built in directly: the app stays private (TestFlight, two users, never the public App Store), so there is no switch and no notice.
- Tests: `shopTeile` ranges, Ahmed has no women's items, free kit size, every catalog id resolves to a drawable piece.

## CI routine per step
1. `git push`; the PR run starts automatically.
2. One `gh run list` / `gh run view` check later (no watch loops). Failures: `gh run view <id> --log-failed`, fix, push.
3. Download the `render-galerie` artifact, view the PNGs, then say what is seen.
