# Brief S report — Szenen in Einstellungen decorieren

## Status
DONE_WITH_CONCERNS

## Base
Reset to `origin/runde-3` (`ee6c4c6`) before starting, worktree had no own commits yet, per common.md.

## Commits
- `ddb4cbe` Add Szenen settings + gym decor (Brief S)

## What was built

1. **Einstellungen → "Szenen" section** (`Lovea/Sources/Einstellungen/EinstellungenView.swift`): one row per `RaumOrt` (Home, Büro, Klassenzimmer, Gym), each with an SF Symbol (`house.fill` / `briefcase.fill` / `graduationcap.fill` / `dumbbell.fill`) and a small live preview (reuses the existing `ZimmerKachel(art: .raum)` tile, same one the editor's own picker tiles use). Tapping a row pushes `ZimmerEditor(person: person, ort: ort)` for the signed-in person. All four places shown for both people, as instructed.

2. **`RaumOrt.gym` added at the end** (`Lovea/Sources/Profile/ZimmerZeichnung.swift`): home, office and classroom already existed from Brief G; gym decor did not. Added the case, a `titel` ("Gym gestalten") and a `symbol`. Every exhaustive `switch` over `RaumOrt` updated (`Zimmer.init(ort:person:)`, `ZimmerEditor.szene`, `ZimmerKachel.leinwand`) — the compiler enforces the rest.
   - `Zimmer(ort: .gym)` default: `deko: ["lautsprecher"]`, no poster preset (index 5 "Gym Shark" is a drawn poster the picker doesn't offer, so a preset there would be unpickable again if removed — left at 0 instead, user picks their own).
   - `Zimmer.dekoArten` gained a `"g"` flag on `pflanze` and `lautsprecher` only — the mirror already exists as a fixed part of the gym backdrop, so it wasn't turned into a second toggle (kept the diff smaller, avoided a pre-existing "picking the mirror also removes your poster" exclusivity rule from firing in a context where the two don't actually share a wall spot).
   - `SzenenZeichnung.gym(_:_:)` now takes the `Zimmer` and draws `einrichtungGym`: the chosen speaker/plant (reused draw functions, shifted with `translateBy` into free space) and the ordinary right-wall poster spot every non-home place has. Old `profil.raeume` JSON without a "gym" key still decodes fine (falls to `Zimmer(ort: .gym)` defaults, covered by the new test).
   - `ProfilSzene.raumOrt` now maps `.gym → .gym` (was `nil`) so the profile header's own scene actually shows the picked gym decor instead of silently ignoring it — this only required editing `ProfilSzene.swift`, not `ProfileView.swift`.
   - `ZimmerEditor` skips the Möbel/Wand/Boden/Bilder tabs for the gym (fixed backdrop, no bed/desk/frames) and starts on Deko; its preview passes `extras: [.hanteln]` for the gym so the live preview shows the dumbbells like the real header does.

3. **Test**: `ProfilSzeneTests.testGymOrt()` — `RaumOrt.allCases.last == .gym`, the gym's own defaults, `dekoArten(fuer: .gym)` is exactly the two gym-fitting pieces, an unfitting piece ("spiegel") is dropped on tolerant read, old `profil.raeume` missing "gym" falls back to the gym's own defaults (not home's), and `ProfilSzene.gym.raumOrt == .gym`. The existing `testStandardsOhneUeberschneidung` (loops `RaumOrt.allCases` for both people) automatically now also covers the gym default having no deco conflicts.

## Concerns
- The two gym deco positions (`einrichtungGym` in `ZimmerZeichnung.swift`) are hand-picked coordinates around the fixed backdrop's mirror/rack/kettlebell art, not verified in a real renderer (no local Xcode). Marked with a `ponytail:` comment naming the free zones I aimed for; a visual pass in CI's render board or Xcode may want to nudge them a few px — I did not add a `RenderGalerieSzeneTests` entry for the newly-decorated gym since Brief S only asked for the one XCTest, and the existing "Gym Ahmed"/"Gym Annika" render-board cells (owned by Brief G's test file) already exercise the new `SzenenZeichnung.gym(_:_:)` signature with a plain `Zimmer()` and should still render without crashing.
- Did not touch `ProfileView.swift` (not strictly needed, per the brief) and did not touch `Chat/Medien/*` or `Profile/KussSzene.swift`/kiss pose, per the "other agents" note.
