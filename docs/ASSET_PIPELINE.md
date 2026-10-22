# Asset pipeline (Gemini art)

Gameplay never references image paths. Every visual is a **stable asset id**
(`enemy.sniper`, `env.jungle.bg_canopy_far`, `boss.warden_tank.cannon`) and
`assets/asset_manifest.json` maps ids to files. If a file is missing, the game
draws a labelled placeholder (press F3 to hide labels) and lists missing ids in
the console at mission start. All 56 ids the current content uses are already
declared in the manifest with their intended paths: that list is the art
to-do list.

## 4K displays

The game's logical view is 1280x720. With the `canvas_items` stretch mode it
is rendered at the display's real resolution, so on a 4K TV (F11 or Alt+Enter
for fullscreen) everything is drawn at 3x. Text, HUD, projectiles and effects
are vector-drawn and stay sharp at any size. Art stays sharp because of
how it is stored:

- **Sprites are stored at about 4x their on-screen size** (nearest-neighbour
  enlarged so pixel edges stay hard). The game always *shrinks* them to fit
  `VisualDef.size` and uses mipmaps, so they are sharp at 4K and smooth at
  1080p. Never ship a sprite smaller than its on-screen size x 3.
- **Tiles are 256x256** for a 64x64 world cell, with a 16 px gutter
  (`margin` / `separation` in the manifest) so mipmaps don't bleed.
- **Painted 1280x720 backgrounds** use `"filter": "nearest"` and are shown at
  720 px tall: exactly 3x on 4K, so they stay crisp instead of blurring.
  Painted art at 3840x2160 would be better still. Use the default (smooth)
  filter for it.
- Placeholders are drawn at 2-4x for the same reason.

## Importing the Jungle Assault concept pack

`tools/concept_pack/` re-creates every sprite in `assets/` from the concept
boards, so you can re-run it, or adapt the coordinates when a new board
arrives:

```bash
python3 tools/concept_pack/extract.py ~/Downloads/Jungle_Assault_Complete_Asset_Concept_Pack /tmp/cut
python3 tools/concept_pack/env_art.py ~/Downloads/Jungle_Assault_Complete_Asset_Concept_Pack /tmp/cut
```

It cuts each item out of its board (flood-fills the panel colour, keeps
only that item's pieces, strips painted floor shadows) and enlarges it 4x. It
builds the jungle ground tiles from the cliff painted in `screen_01.jpg`, and
blends five screens into one backdrop. These are concept boards, so most
characters are single poses about 80 px tall. The player has idle, a 5-frame
run, jump, crouch, hurt and death; enemies have one pose with a small stride bob.
For smoother animation, generate proper sheets (see the prompting tips).

### Depth and readability

`tools/concept_pack/depth_layers.py` turns the flat painted backdrop into
three parallax layers. A flat painting reads as one wall, and painted paths
compete with the real one.

| Layer | Scroll | Treatment |
|---|---|---|
| `bg_far` | 0.12 | sky, mountains, falls: blurred, desaturated, hazed |
| `bg_near` | 0.37 | cliffs, towers, bridges cut out by colour, hazed, fading into river mist at the base so painted walkways recede |
| tiles | 1.0 | the playable ground: dark, saturated body with a bright grass lip, clearly not part of the painting |
| `fg_leaves` | 1.35 | blurred dark palms passing in front |

The same rule applies when you generate new worlds: keep the background
lighter, hazier and lower in contrast than anything the player can stand on
or shoot. Ask Gemini for separate layers (sky, far, mid, near foreground)
instead of one finished scene.

## 1. Inspect every incoming image first

Do not assume an image is a sprite sheet. Run:

```bash
godot --headless --path . -s res://tools/inspect_asset.gd -- ~/Downloads/gemini_mech.png --id boss.mech
```

It reports one of:

| Verdict | Meaning | What to do |
|---|---|---|
| background / single illustration | opaque image | parallax layer or briefing art (`type: single`) |
| tile sheet | opaque, strong seams on a grid | `type: tiles`, name tiles by [column, row] |
| single sprite | one object on transparency | `type: single` (props, pickups, boss parts, still enemies) |
| sprite sheet | equal objects on a regular grid | `type: sheet`, it suggests `frame_size` and rows |
| catalog | several different objects | split with `--split out_dir`, register each piece |

It prints a suggested manifest entry. Always eyeball the result: generated
sheets often have uneven spacing, which the tool reports as a catalog.

## 2. Put the file in the right folder

```
assets/characters/   playable characters
assets/enemies/      enemy sprites and sheets
assets/bosses/       boss bodies and separate weak-point parts
assets/environments/<world>/   parallax layers, tiles.png, props
assets/environments/hazards/   spikes, liquids (tiled horizontally)
assets/pickups/  assets/weapons/  assets/fx/  assets/props/  assets/ui/
assets/audio/music|ambience|sfx/
```

Open the project in the Godot editor once so it imports the file (the game
can also load un-imported PNGs directly while developing).

## 3. Register it in `asset_manifest.json`

```json
"enemy.sniper": {
  "type": "sheet",
  "path": "res://assets/enemies/sniper_sheet.png",
  "frame_size": [128, 128],
  "animations": {
    "idle":   {"row": 0, "frames": 4, "fps": 6},
    "run":    {"row": 1, "frames": 6, "fps": 12},
    "attack": {"row": 2, "frames": 2, "fps": 10}
  }
}
```

| Field | Types | Meaning |
|---|---|---|
| `type` | all | `single`, `sheet`, `tiles`, `audio` |
| `path` | all | `res://` path |
| `frame_size` | sheet | cell size in pixels |
| `animations` | sheet | name → `row`, `frames`, optional `start`, `fps`, `loop` |
| `fit` | single, sheet | `height` (default), `width`, `contain`: scale art into the gameplay size |
| `scale` | single, sheet | fixed scale instead of `fit` |
| `offset` | single, sheet | `[x, y]` pixel nudge so feet sit on the ground |
| `faces_left` | single, sheet | art drawn facing left (default is facing right) |
| `filter` | any image | `nearest` for pixel-art shown at whole-number scales; default is smooth + mipmaps |
| `margin`, `separation` | tiles | transparent gutter around / between tiles in the atlas |
| `rig` | single, sheet | `biped`: split at the hips and walked procedurally (legs swing, body bobs, torso leans to aim and kicks on recoil); `vehicle`: engine rumble; `hover`: banks into turns |
| `rig_frame` | sheet | `[column, row]` of the standing frame used for the biped rig |
| `loop`, `loop_start`, `loop_end` | audio | loop music after an intro (seconds) |
| `volume_db` | audio | per-sound mix level |

### Walking without drawn walk cycles

Art from the concept boards has one pose per enemy. Entries marked
`"rig": "biped"` are animated by `core/visual/cutout_rig.gd`. It finds the
hips and the gap between the legs in the image, and each leg swings from its
drawn pose to the mirror of it. Stride speed follows ground speed and the
lowest foot stays on the ground, so characters walk instead of sliding. It
needs the legs to be visible and apart in the image. Characters whose legs are
hidden (shield trooper) or crouched (heavy gunner) are better left without a
rig. They get a stride bob. When you have proper sheets with a `run` row, the
sheet animation is used for jumps/crouch/hurt/death, and the rig still runs
idle/run. Remove `rig` to use the drawn `run` frames instead.

## Music and sound

`tools/audio/make_audio.py` composes the original 8-bit style soundtrack
(jungle, boss, desert, victory), the sound effects and the rain/wind
ambience, and writes WAVs into `assets/audio`:

```bash
python3 tools/audio/make_audio.py assets/audio
```

It uses classic arcade instruments (two pulse leads, a 4-bit triangle bass,
LFSR noise drums). Melodies and sequencing are plain lists in the script, so
they can be re-composed. To use commissioned or licensed music instead, put
the file in `assets/audio/music/` and point the id (`music.jungle`,
`music.boss`, ...) at it in the manifest.
| `tile_size`, `tiles` | tiles | cell size and named tiles: `ground_top`, `ground_fill`, `platform`, `block` |

Animation names the game requests: player `idle`, `run`, `jump`, `crouch`;
enemies and bosses `idle`, `run`, `attack`. Missing names fall back to `idle`.
Effects use `fx.<kind>` sheets (e.g. `fx.explosion`) and play once.

Art is scaled to the size gameplay asks for (`VisualDef.size` or the body
size), so Gemini output at any resolution works. Collision never comes from
art: hitboxes are `body_size` / weak point `size` in the `.tres` files.

## Prompting tips for Gemini

- Ask for the final size up front: characters at least **256 px tall**,
  bosses 512+ px, backgrounds **3840x2160**. Small art can't be enlarged
  later without becoming blocky or blurry.
- Ask for **transparent background PNG**, **side view**, **facing right**,
  consistent lighting, and no ground shadow baked in.
- Sheets: "N frames in one row, evenly spaced on a grid of equal cells, same
  scale in every frame". Generate one animation per row or per image.
- Parallax layers: wide images (at least 2:1) whose **left and right edges
  tile**, transparent above the silhouette for every layer except the farthest.
- Tiles: square, opaque, edges that tile with themselves; a ground-top tile
  and a fill tile at minimum.
- Bosses with weak points: generate the body and each weak point as separate
  images so parts can be highlighted and destroyed.
