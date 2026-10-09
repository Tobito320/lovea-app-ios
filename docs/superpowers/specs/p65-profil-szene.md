# p65 Profil-Szene: spec

Source: vault note "Lovea - p65 Profil-Szene Redesign Plan" (Ahmed, Build 114 screenshots).
Base: `origin/runde-3` (Build 114). `main` is 871 commits behind and has no profile scene, so the PR targets `runde-3` like every PR of this round.

## Problems seen on Build 114

1. Calendar, string lights, pictures, lamp, "Annika ist online" and the gear sit above the visible area; they show only when the page is pulled. Cause: the header is a 430 pt scroll header with `ignoresSafeArea(.top)`, the toolbar gear sits in the (hidden) nav bar.
2. The record player stands over the pictures. Cause: overlays (`ZimmerLebenTippen`, `ZimmerExtras`, wall pieces) place themselves independently in the same 390 x 430 space.
3. Sitting people are the half figure (head and chest) at x of about 360, partly beyond the screen edge, cut by the sofa cushion.
4. Ahmed can wear women's clothes (crop top, tank top, tops tagged neutral). Brand pieces look unreal.

## Goals and decisions

### A. Scene
- The scene is fixed at the top of the profile (no scroll header, no stretch). It is fully visible without pulling. Wall colour runs under the status bar; all items sit below the safe area.
- Panorama: design space grows from 390 to 890 units (2.28 screens). Zones: Schlaf (x -250..0), Wohn (0..390, the existing room, unchanged coordinates), Regal (390..640). Horizontal paging with snap, wall layer scrolls slower than furniture (parallax via `visualEffect`). Zone dots under the scene, tappable.
- One slot table (`ProfilSlots`) is the only source for object rectangles. Drawing, tap areas and tests read it. Unit tests: no two slots overlap, minimum gap, every tap area is at least 44 x 44 pt at the smallest supported scale, every slot lies in its zone.
- Tap objects: bed (lies down), sofa (sits), TV and record player (music), fridge, gift, clock. Floating inside the visible scene: "Annika ist online" (top left), gear (top right).
- Below the scene: calm: date, days together, coins, then three labelled buttons: Profil, Zimmer, Kleidung.
- One avatar only: the round head image in the room is removed together with the pair avatars at the bottom (`ProfilPaarAvatare` stays as the name row, small).
- Scene height is a pure function of width, height and safe-area inset (`ProfilPanoramaLayout`), tested at two device sizes.

### B. Figures
- Whole body always. Pose logic is pure (`FigurPose`, `FigurPoseLogik`): place -> pose, anchor points (hip height, head top, width), bounds. Tests: sitting head top inside the scene, seat height of the sofa matches the sitting hip height for all three body sizes.
- Poses: stehen, gehen, sitzenSofa, sitzenBettkante, liegen, winken. Hug and kiss reuse `PaarPose`/`KussPaar`.
- `FigurView` gets `pose: FigurPose?` (default nil: nothing changes for the 20+ existing callers). Sitting reuses the articulated body (neck, torso, upper/lower arms, thighs, lower legs, feet). Thighs foreshortened, lower legs hang in front of the sofa base. Lying = the standing figure rotated 90 degrees around the hips (frame becomes 2:1).
- Layers on the sofa: back (backrest, arms) behind, figure, throw pillow in front. No cutting.
- Existing faces untouched. Idle (breathing, blink, sway) is the existing clock; no new timers (battery rules of the stage stay).
- Render gallery: one board per person with every pose.

### C. Figure and clothes
- Settings: new entry "Meine Figur" (face, skin, hair, eyes, body form) using `FigurEditor` limited to body tabs. Clothing leaves the editor.
- Profile button "Kleidung": wardrobe with Oberteile, Hosen, Schuhe, Jacken, Accessoires.
- Clothing is per person: `FigurAussehen.erlaubt(...)` already gates by gender; the neutral tags on crop top (11), tank (6), Top (4) and similar are fixed to `.w`. Test over every list and the shop catalog: Ahmed's allowed set contains no item of the women's list.
- Migration: `FigurAussehen.mitGueltigerKleidung(_, person)` resets only gender-invalid parts to the person's default piece. Parts currently shop-gated but worn or owned are kept (grandfathered). Existing outfits load unchanged.

### D. Shop and brands
- Free basic kit per person is small (about 5 pieces: top, bottom, shoes, jacket, accessory incl. the current standard look: Ahmed 32/18/15, Annika 4/1/1). All else is bought for coins. List indices never change or shrink (synced data); only the `*Shop` sets and gender tags change.
- Names are short real names ("Baggy Jeans schwarz", "Slim Fit Hemd weiss", "Denim Jacke", "Hoodie pink", "Strickpullover creme", "Mantel schwarz"). No fantasy names.
- Brand pieces (Nike, Adidas, Jordan, The North Face, Ralph Lauren, Carhartt): cut, colours and logo placement close to the real piece; name or logo visible on the piece. Shoes: Air Force 1 white, Jordan 1, Nike Dunk, Adidas Samba.
- All drawing is vector (`Path`/`Canvas`), logos are vector paths. No raster upscaling.
- Annika: own women's catalog of the same quality (elegant, streetwear, dresses, skirts, tops, shoes), brands visible.
- One switch `MarkenLogos.an` (one file). Legal note in `docs/marken-logos.md`: real logos are fine for a private TestFlight app with two users; before any public App Store release they must be removed (switch off) or licensed.

## Out of scope
- No new network sync fields. No change to ChatView, Karte, Snaps.
- Real brand photos are not used; everything is drawn.

## Acceptance
Scene fully visible without pulling; panorama swipe with parallax; no overlaps (tested); both figures whole body, sit on the sofa, no cut head; figure in Settings, clothing in the profile; Ahmed has no women's items and at most about 5 free pieces; brand pieces show logo and look sharp; Annika's new clothes have the same quality. Test list for the phone: vault `19 Bastelprojekte/Lovea - p65 Profil-Szene Testliste.md`.
Code is verified by CI only (no local Xcode): reports say "nicht kompiliert, CI offen" until the run is green.
