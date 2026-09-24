# Brief Z report: drawing scene in the profile

Status: DONE_WITH_CONCERNS. Nothing was compiled locally (no Xcode). CI and the `profil-zeichnen` board are the check.

Branch: `worktree-agent-a42d1928babab0b56`, reset onto local `runde-3` (001b798) before the first commit.

## Commits

| Commit | What |
|---|---|
| `dac0eef` | Presence: the background pauses the app slot; leaving the studio clears only "zeichnet" |
| `23d514e` | Figure: full-body drawing pose with tablet, pencil and growing doodle; `FigurExtra.mitzeichnen` |
| `40e0a2c` | Scene: `ProfilSzene.zeichnen(zusammen:)`, priority, header wiring, tests |
| `3d8f77c` | Render board `profil-zeichnen` |

## 1. Does "zeichnet" reach the partner?

What already worked:
- The studio calls `ZeichnungLive.betreten()` on appear, which sends `.zeichnet`. It calls `verlassen()` on disappear. This happens for every drawing, shared or not.
- A tab switch triggers the studio's `onDisappear`, so leaving the tab ends it.
- `.zeichnet` is in `Anwesenheit.appGruppe`.
- On backgrounding, `Anwesenheit` cleared the slot.

Gaps I fixed:
- **Coming back from the background restored nothing.** The studio was still open, but the partner no longer saw "zeichnet". The same was true for chat and map.
  - Fix, in the one place every caller goes through: `Anwesenheit` now has an `imHintergrund` flag. Backgrounding pauses the slot instead of dropping it, and `didBecomeActive` brings it back and re-decides.
- **Leaving the studio sent `.ruhig`.** If the next screen's `onAppear` ran first, that `.ruhig` wiped the next screen's state.
  - Fix: `verlassen()` now calls the new `Anwesenheit.appEnde(.zeichnet)`, which clears the slot only while it still says "zeichnet".

Not fixed (reported): chat and map still send a plain clear on disappear. So in theory, chat's late `.ruhig` could wipe the studio's `.zeichnet` when you switch straight from the chat tab to a studio that is already open. I did not change those files. The upgrade path is to switch their `onDisappear` to `appEnde(.imChat)` / `appEnde(.karte)`.

## 2. Scene decision

- `ProfilSzene.zeichnen(zusammen: Bool)` is appended at the end. Every switch is exhaustive:
  - `ProfilSzene`: `figur`, `extras`, `dunkel`, `raumOrt`
  - `ProfilSzeneHintergrund`: `imZimmer`, `asset`, `bewegt`
  - `SzenenZeichnung.szene`
  - `ProfileView.belegung`
- The pure `fuer(...)` gained `zeichnet:` and `partnerZeichnet:` at the end, both defaulting to `false`, so old calls and tests are unchanged.
- **Priority:** drawing > sleep > travel > gym > home > outside.
  - This matches the drawer's own phone. `FigurZustand.bestimmen` already ranks App above sleep and place.
  - A drawer who is travelling never sends `zeichnet`, because the phone ranks travel above App.
- **Input:** `ProfilSzene.zeichnetGerade(p)` reads the shared `zustand[p]`, not `anzeige(p)`.
  - Why not `anzeige`: a 4 s gesture would kick the scene out of drawing. With this input, the gesture plays inside the drawing scene.
  - It counts only for the own person, or while the partner is here (`partnerDa`). A stale "zeichnet" from a closed app never shows the scene.
- **Background:** the person's home room with its own decor, frames, lights and night dimming. The drawing is the exact `zimmer` layer path, so the Brief R still/moving split is unchanged and there is no new moving layer.
  - `raumOrt` is `.zuhause`, so tapping the scene opens the home room editor.
- **Figure:** `figur(_:)` keeps a live gesture or expression, otherwise it shows `.zeichnet`.
  - A bought pose no longer replaces the drawing pose (`pose ... && zustand != .zeichnet`).
  - The drawing figure runs at 15 fps instead of 30.
- **Together:** both figures show, in the own profile too, like "sleeping together". Both get `FigurExtra.mitzeichnen` (`figurSzene(_:_:)`).
- **Tests:** `Lovea/Tests/ZeichnenSzeneTests.swift` covers:
  - drawing beats home, sleep, gym, work and travel
  - together, and only-the-partner-draws
  - `figur` and `extras`
  - `raumOrt` and `dunkel`
  - the stroke timing: still frame, cycle start and repeat, and which strokes each person draws

## 3. The drawing (sticker style, code only)

- **Full-body `.zeichnet` in `FigurView`**, touched as little as I could:
  - The figure sits (`haltung .sitzen`) on a round knitted pouf (`szeneHinten`).
  - A dark-framed tablet lies on the lap, tilted about 6°. Its bright screen has four colour swatches on the right edge (`vorArmen`, under the arms).
  - The left hand holds the tablet's edge. The right hand holds a white pencil with a dark tip, and the tip runs along the stroke being drawn.
  - A small sparkle pops where a stroke ends (`handRequisite`).
  - Two new stored bits on `Zeichner`: `person`, and the helpers in the new `// MARK: Drawing on the tablet (Brief Z)` block.
- **Doodle timing and geometry** live in the pure `Figuren/ZeichenStriche.swift`, so the hand and the line read the same numbers.
  - The cycle is 8 s: 4 strokes of 1.3 s each, a pause, a 0.8 s fade, then it starts again.
  - Alone: a blue wave, a red heart in two strokes, and a yellow swoosh.
  - Together: one shared picture on both tablets. Annika draws the left half of the heart and a blue squiggle, Ahmed the right half and a yellow squiggle. Each pencil moves only on its own strokes; while the other one draws, it hovers.
  - Both figures run on the same wall clock, so they stay in sync.
- **Reduce Motion and render boards:** the still frame stops mid-doodle, with three strokes done and the fourth under way.
- **Night:** the room dims as before. The figures dim with it through `nachtImZimmer` (brightness -0.1), which includes the screen.
- The half figure (chat, stickers) is unchanged.

## 4. Render board `profil-zeichnen` (`Lovea/Tests/RenderGalerieZeichnenTests.swift`)

The board has 7 cells:
- Annika drawing
- Ahmed drawing
- drawing together
- Annika drawing at night
- Ahmed drawing at night
- two close-ups of the tablet: alone, and together from Ahmed's side

Each person's default home room is used.

## Concerns

1. **"Both drawing" is almost never visible on real devices.** To see it, the viewer has to be in the Profile tab. But leaving the studio (or its tab) ends the viewer's own "zeichnet". So it only shows in the short send debounce, or with a second device logged in as the same person.
   - It is built to the spec and costs little: one extra and a second stroke set.
   - If you want it to mean "the partner is live-drawing in a drawing shared with me", the viewer side knows `LiveZeichnung.shared.partnerDrin`. Say so and it can switch.
2. **The map pin changes too.** The full-body `.zeichnet` pose is global, so the map pin of a drawing person now sits on the pouf with the tablet instead of standing with a phone. Desk states already sit there, so this seemed fine.
3. **A stale `.zeichnet` can still show on the figure.** If an offline partner's last shared state is `.zeichnet` (the app was killed before the background send), `ProfilSzene.geteilterZustand` still hands it to the header figure. The scene itself does not show drawing then. This was possible before this change too.
4. **Chat/map ordering race:** see section 1.
5. **Drawing away from home still shows the home room** (`ponytail`: one room). If wanted, it could use the room of the place they are at (office or classroom).
6. **APIs not used in this repo before:** `GraphicsContext.concatenate(_:)` and `Path.trimmedPath(from:to:)`. Both are standard SwiftUI since iOS 15 / 13. If `concatenate` fails, the fallback is `translateBy(x: 100, y: schulterY + 70)` followed by `rotate(by: .radians(-0.1))`.
7. **Cross-file edits outside the Profile area:**
   - `Lovea/Tests/FigurenTests.swift`: the `FigurExtra.allCases` assertion now includes `mitzeichnen`.
   - `Anwesenheit.swift` and `LiveZeichnung.swift`: the presence fix.
