# Mythlings Art Briefs

Ready-to-run generation prompts for the storefront art (the largest
remaining launch gap). Written for an AI image service such as
Higgsfield; equally usable as a commission brief for an artist.

House style: vibrant stylised fantasy, saturated colours, soft rim
lighting, family-friendly, no text baked into images unless stated.
No em dashes in any overlaid copy; UK English.

## 1. Game icon (512x512, also export 1024x1024)

> A large cracked glowing fantasy egg in the centre, warm golden light
> spilling from the cracks, a single curious creature eye visible
> inside the crack, arena flames rising behind the egg, dark indigo
> background, vibrant stylised cartoon game art, high contrast, no
> text, square composition with the egg filling 70 percent of frame.

Acceptance: readable at 64x64; the eye and cracks must survive
downscale; avoid fine detail at the edges.

## 2. Thumbnail A: the hatch moment (1920x1080)

> A burst of golden light as a fantasy egg hatches, revealing the
> silhouette of a small dragon-like creature, confetti of six elemental
> colours (orange flame, blue tide, green terra, yellow storm, purple
> shadow, white radiant), excited cartoon style, dramatic low camera
> angle, wide 16:9 composition with space on the right third for a
> text overlay.

Overlay copy (added in an editor, not generated): "1 in 111!"

## 3. Thumbnail B: the arena (1920x1080)

> Two teams of three small stylised fantasy creatures facing off on a
> floating stone arena platform, energy abilities mid-cast (a flame
> bolt meeting a water surge), dramatic rim lighting, cheering crowd
> silhouettes far below, vibrant cartoon game art, 16:9.

Overlay copy: "3v3 Ranked Battles"

## 4. Thumbnail C: home and collection (1920x1080)

> A cosy decorated garden plot at golden hour with five cute fantasy
> creatures lounging among furniture (a fountain, lanterns, a shade
> tree), one creature sparkling with a rainbow shiny effect, a castle
> themed house in the background, warm inviting cartoon style, 16:9.

Overlay copy: "Collect. Breed. Shinies!"

## 5. In-game model commissions (3D, not generated images)

Per-species briefs derive from `MythlingConfig`: 33 species across six
elements and six rarities, four growth stages each (use one mesh with
scale steps 0.6 / 0.85 / 1.1 / 1.35 per `StatConfig.StageScales`).
Drop-in points, no logic changes needed:

- `MythlingSpawnService.buildActor` (follower models)
- `BattleService.buildArena` (arena set dressing)
- `HousingService.renderPlot` / `renderFurniture` (plot themes and
  furniture meshes per `HousingConfig`)
- Egg models per tier for the shop and hatch reveal.
