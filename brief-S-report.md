# Brief S report — Szenen in Einstellungen decorieren

## Status
DONE_WITH_CONCERNS

## Base
Reset to `origin/runde-3` (`ee6c4c6`) before starting, worktree had no own commits yet, per common.md.

## Commits
- `ddb4cbe` Add Szenen settings + gym decor (Brief S)
- `c9b0f57` Address review: sheet nav, poster/text overlap, speaker spot, test style

## What was built

1. **Einstellungen → "Szenen" section** (`Lovea/Sources/Einstellungen/EinstellungenView.swift`): one row per `RaumOrt` (Home, Büro, Klassenzimmer, Gym), each with an SF Symbol (`house.fill` / `briefcase.fill` / `graduationcap.fill` / `dumbbell.fill`) and a small live preview (reuses the existing `ZimmerKachel(art: .raum)` tile). Tapping a row presents `ZimmerEditor(person: person, ort: ort)` for the signed-in person as a `.sheet(item:)`, the same pattern the existing "Orte" row uses — a plain `NavigationLink` push was tried first but reverted after review: `ZimmerEditor` has its own "Abbrechen" toolbar button built for sheet presentation, which would have doubled up with the pushed screen's back button. `RaumOrt` gained `Identifiable` for this. All four places shown for both people, as instructed. The gear icon that reaches Einstellungen is gated on `person == session.person` in `ProfileView.swift` (unchanged, verified), so `person` here is always the own person, never the partner's.

2. **`RaumOrt.gym` added at the end** (`Lovea/Sources/Profile/ZimmerZeichnung.swift`): home, office and classroom already existed from Brief G; gym decor did not. Added the case, a `titel` ("Gym gestalten") and a `symbol`. Every exhaustive `switch` over `RaumOrt` updated (`Zimmer.init(ort:person:)`, `ZimmerEditor.szene`, `ZimmerKachel.leinwand`) — the compiler enforces the rest.
   - `Zimmer(ort: .gym)` default: `deko: ["lautsprecher"]`, no poster preset (index 5 "Gym Shark" is a drawn poster the picker doesn't offer, so a preset there would be unpickable again if removed — left at 0, user picks their own).
   - `Zimmer.dekoArten` gained a `"g"` flag on `pflanze` and `lautsprecher` only — the mirror already exists as a fixed part of the gym backdrop, so it wasn't turned into a second toggle (avoids the pre-existing "picking the mirror also removes your poster" exclusivity rule firing where the two don't actually share a wall spot).
   - `SzenenZeichnung.gym(_:_:)` now takes the `Zimmer` and draws `einrichtungGym`: the chosen speaker (shifted right, off the centred figure) and plant (shifted onto free floor), plus a poster on the free left wall. The left wall also carries the drawn "LOVEA GYM" lettering, so that now only draws when no poster is picked (fixed after review — they used to overlap). Old `profil.raeume` JSON without a "gym" key still decodes fine (falls to `Zimmer(ort: .gym)` defaults, covered by the new test).
   - `ProfilSzene.raumOrt` now maps `.gym → .gym` (was `nil`) so the profile header's own scene actually shows the picked gym decor instead of silently ignoring it — this only required editing `ProfilSzene.swift`, not `ProfileView.swift`.
   - `ZimmerEditor` skips the Möbel/Wand/Boden/Bilder tabs for the gym (fixed backdrop, no bed/desk/frames) and starts on Deko; its preview passes `extras: [.hanteln]` for the gym so the live preview shows the dumbbells like the real header does.

3. **Test**: `ProfilSzeneTests.testGymOrt()` — `RaumOrt.allCases.last == .gym`, the gym's own defaults, `dekoArten(fuer: .gym)` is exactly the two gym-fitting pieces, an unfitting piece ("spiegel") is dropped on tolerant read, old `profil.raeume` missing "gym" falls back to the gym's own defaults (not home's), and `ProfilSzene.gym.raumOrt == .gym`. The existing `testStandardsOhneUeberschneidung` (loops `RaumOrt.allCases` for both people) now also automatically covers the gym default having no deco conflicts. Touched `Lovea/Tests/RenderGalerieSzeneTests.swift` (Brief G's file) minimally — only the two "Gym" cells' data, to exercise the new decor coordinates on Brief G's own render board rather than adding a second board.

## Concerns
- The gym deco positions in `einrichtungGym` are hand-picked coordinates around the fixed backdrop's mirror/rack/kettlebell/plate art, not verified in a real renderer (no local Xcode). Marked with a `ponytail:` comment naming the free zones aimed for; the render board (`profil-szenen`, CI artifact) now shows both an undecorated and a decorated gym cell for a visual check, may still want a few px of nudging.
- Did not touch `Chat/Medien/*` or `Profile/KussSzene.swift`/kiss pose, per the "other agents" note.
