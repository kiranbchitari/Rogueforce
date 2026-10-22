# Architecture

ROGUEFORCE separates **what the game plays like** (data) from **how it runs**
(a small set of reusable systems). Nothing in `core/` knows about jungles,
tanks or any particular mission.

```
autoload/      Global services
  game.gd        campaign, lives, score, checkpoints, scene flow, input map
  content.gd     indexes every .tres under content/ by type and id
  assets.gd      asset id -> file registry (asset_manifest.json), placeholders
  audio.gd       music / ambience / sfx by id, synthesised stand-in sfx
core/
  data/          Resource classes: the "schema" of all content
  behaviors/     Reusable movement and attack resources (strategy objects)
  actors/        Player, Enemy, Boss, WeakPoint, Projectile, Pickup, Hurtbox
  world/         Terrain (ASCII -> TileMapLayer + markers), EnvironmentBuilder
  mission/       MissionRunner (shared) + HorizontalMission (format runner)
  visual/        ActorVisual: sprite sheet, single image or placeholder
  fx/            Effects and attack telegraphs
  ui/            HUD, boss bar, title / briefing / results screens
content/       All game data (.tres + layout .txt)
assets/        Art and audio, referenced only through asset_manifest.json
tools/         inspect_asset.gd (classify incoming images), check_scripts.sh
tests/         compile_all, smoke_test, capture
```

## Data model

| Resource | Owns | References |
|---|---|---|
| `CampaignDef` | mission order, starting lives | `MissionDef[]`, `CharacterDef` |
| `MissionDef` | name, format, layout file, legend, triggers, goal, audio override | `EnvironmentDef`, `BossDef`, `MissionTriggerDef[]` |
| `EnvironmentDef` | sky, tint, haze, weather, parallax, tile colours/tileset, props, hazards, default roster, audio | `ParallaxLayerDef[]`, `HazardDef`, `EnemyDef[]` |
| `EnemyDef` | stats, body, flags (flying, shield, explodes) | `MovementDef`, `AttackDef[]`, `VisualDef`, `PickupDef` |
| `BossDef` | stats, entrance, bar style, defeat | `WeakPointDef[]`, `BossPhaseDef[]`, `VisualDef` |
| `BossPhaseDef` | entry condition, attack order, hull armour, summons, tint | `MovementDef`, `AttackDef[]` |
| `WeaponDef` / `PickupDef` / `ProjectileDef` | shooting and items | |
| `VisualDef` | asset id + placeholder shape/colour/size | asset manifest |

**Key decoupling rules**

1. *Environment is not geometry.* Collision comes only from the mission layout
   (`Terrain`). Backgrounds are `Parallax2D` sprites with no collision. Any
   layout can be shown with any environment (the smoke test runs the jungle
   layout with the desert environment and the gunship boss).
2. *Environment is not a faction.* An environment suggests a `default_roster`
   for random spawns, but a mission layout legend and triggers can use any enemy.
3. *Gameplay never names files.* Everything visual or audible is an asset id.
   Missing ids render placeholders (labelled with the id; F3 toggles labels).
4. *Behaviour is composition.* Enemies and boss phases pick a `MovementDef`
   and a list of `AttackDef`s. One `Enemy` script and one `Boss` script run
   every enemy and boss.

## Runtime flow

```
TitleScreen -> Game.start_campaign() -> BriefingScreen -> Game.launch_mission()
  -> runner scene for MissionDef.format (FORMAT_RUNNERS in game.gd)
     MissionRunner._ready():
       Terrain.build(layout, legend, environment)   tiles, hazards, props, markers
       EnvironmentBuilder.build(environment)         sky, parallax, tint, haze, weather
       markers -> player start, checkpoints, enemies (spawned when near view),
                  pickups, triggers (digits), boss arena (B), exit (E)
     _physics_process: camera, enemy activation, checkpoints, triggers, hazards, waves
     boss arena -> WARNING -> Boss.begin_entrance() -> phases -> defeated
  -> MissionRunner.complete() -> ResultsScreen -> Game.next_mission()
```

## Combat

- `Hurtbox` rectangles register with the runner per team. `Projectile`
  resolves hits against them each physics step and against the terrain grid,
  picking the highest-priority hurtbox (weak points = 10, hulls = 0). This makes
  "shoot the weak point, not the armour" exact.
- `receive_hit()` on the owner decides the outcome: shields block frontal hits,
  bosses ping while invulnerable, weak points take their own damage and forward
  multiplied damage to the boss.
- `MissionRunner.explode()` does area damage; `source_team = -1` (barrels,
  vehicles) hurts both sides.

## Attacks and telegraphs

`AttackRunner` plays every attack the same way:
`telegraph -> begin -> fire x burst_count -> active_time -> end -> recovery -> cooldown`.
Telegraph kinds are `flash` (outline + "!"), `aim_line` (laser sight to the
captured aim point) and `ground_marker` (impact markers, computed in
`prepare()` so the markers are exactly where shells land). Bosses use the
same runner with `sequence` or `random` order.

## Mission formats

`MissionDef.format` selects a runner scene through `Game.FORMAT_RUNNERS`.
Only `horizontal` exists today. `MissionRunner` contains everything shared;
`HorizontalMission` only overrides the camera (leads the player, no
backtracking). A vertical/elevator runner would override `_update_camera()`
and `progress_of()` (use `-y`), and an arena runner would lock the camera from
the start. `MissionDef.runner_scene` lets a single mission use a bespoke scene,
and `MissionDef.custom_logic` attaches a script with hooks
(`mission_started`, `trigger_fired`, `boss_defeated`) for one-off scripting.
