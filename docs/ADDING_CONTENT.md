# Adding content

All content lives in `content/` as Godot resources. The quickest way to make
something new is to **duplicate a similar `.tres` in the Godot FileSystem dock
and edit it in the Inspector**. Give it a unique `id`; `Content` finds it
automatically by scanning `content/`.

Run the checks after any change:

```bash
godot --headless --path . -s res://tests/compile_all.gd
godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
```

---

## Add a new world (environment)

Example: an arctic world. No code changes.

1. Duplicate `content/environments/desert.tres` to `content/environments/arctic.tres`.
2. Set `id = arctic`, `display_name`, `description`.
3. **Atmosphere:** sky colours, `ambient_tint` (e.g. pale blue), `fog_color`,
   `weather = snow`.
4. **Backgrounds:** edit `parallax_layers`. Each layer has an `asset_id`
   (e.g. `env.arctic.bg_peaks`), `scroll_scale` (0.1 far … 0.6 near, >1
   foreground), `y_offset`, `height`, and a placeholder shape/colour used until
   the art exists (`ice_peaks`, `clouds`, `fog` suit snow).
5. **Terrain:** set `tileset_asset_id = env.arctic.tiles` and the four
   placeholder colours (ground, ground top, platform, block).
6. **Props:** list decorative `VisualDef`s (snowdrifts, antennae…). They never collide.
7. **Hazards:** make `content/hazards/thin_ice.tres` (`respawn_player = true`)
   and `icicle_spikes.tres` (`bounce = true`) and assign them to
   `liquid_hazard` (`~`) and `spike_hazard` (`^`).
8. **Enemies:** optional `default_roster` used by spawn entries without an enemy.
9. **Audio:** `music_id`, `ambience_id`.
10. Add the new asset ids to `assets/asset_manifest.json` (see ASSET_PIPELINE.md).
    Until files exist, placeholders are drawn.

To try it, point any mission's `environment` at it; the layout plays unchanged.

---

## Add a new enemy

Example: a flamethrower trooper. No code changes.

1. Duplicate `content/enemies/infantry.tres` to `flamer.tres`; set `id = flamer`.
2. `visual`: `asset_id = enemy.flamer`, placeholder shape `humanoid`, a colour.
3. Stats: `body_size`, `max_health`, `contact_damage`, `score`, `drop` + `drop_chance`.
4. **Movement** (pick one resource, then tune it):

   | Resource | Use for |
   |---|---|
   | `StationaryMovement` | turrets, snipers, emplacements |
   | `PatrolMovement` | guards, vehicles that drive back and forth |
   | `ChaseMovement` | infantry (`preferred_distance` 300), rushers (0), artillery (450+) |
   | `HoverMovement` | drones, helicopters, flying creatures (set `flying = true`) |
   | `StrafeMovement` | elites/bosses moving between arena waypoints |

5. **Attacks** (any number; the first ready one in range is used):

   | Resource | Use for |
   |---|---|
   | `ShotAttack` | aimed shots, fans (`count` + `spread_deg`), bursts, fixed-angle bombs |
   | `LobAttack` | grenades, mortars that arc onto the player |
   | `ArtilleryAttack` | shells/rocks falling from above onto marked spots |
   | `RadialBurstAttack` | rings and spirals |
   | `SummonAttack` | calling in other enemies |
   | `ChargeAttack` | rams and lunges |

   Shared fields: `cooldown`, `min_range`/`max_range`, `telegraph` +
   `telegraph_time` (always telegraph; it is what makes attacks fair),
   `burst_count`/`burst_interval`, `muzzle_offset`, `projectile`, `sfx_id`.
   For the flamer: `ShotAttack` with a short-lived, slow, wide `ProjectileDef`,
   `count = 4`, `spread_deg = 20`, `burst_count = 8`, `max_range = 260`.
6. Flags: `flying`, `frontal_shield`, `death_explosion_radius/damage`,
   `counts_as_enemy = false` for destructible scenery.
7. Place it: add `"f": "enemy:flamer"` to a mission's `legend` and put `f` in
   the layout, or reference it in a trigger's spawn entry.

### When a new behaviour is genuinely needed

Write one script, not a new enemy system:

```gdscript
class_name BurrowMovement
extends MovementDef

@export var speed := 200.0

func tick(actor: Actor, state: Dictionary, delta: float) -> void:
	# per-actor state lives in `state`; tuning lives in @export vars
	...
```

or `extends AttackDef` and override `prepare()` / `begin()` / `fire()` / `end()`.
It then appears in the Inspector for every enemy and boss phase.

---

## Add a unique boss

Bosses share one framework (`core/actors/boss.gd`) but each is defined by
data: body, entrance, weak points, and phases with their own movement and
attacks. The two included bosses play differently:

- **Warden** (ground tank): armoured hull (only 20% damage), a destructible
  main gun that forces phase 2, an engine weak point only exposed in later
  phases, artillery with ground markers, a telegraphed ram, a summon phase.
- **Hornet** (gunship): flies between arena waypoints, two destructible
  missile pods, then hovers over the player for bombing runs and drone
  launches, then exposes its rotor and fires flak spirals.

Steps:

1. Duplicate `content/bosses/warden_tank.tres`, set `id`, `display_name`, `title`.
2. `visual`, `body_size`, `max_health`, `flying`, `entrance`
   (`enter_right`, `drop_in`, `rise`), `start_position` (0..1 of the arena).
3. **Weak points** (`WeakPointDef`): `offset` from the centre *when facing
   left*, `size`, `damage_multiplier`, optional own `health` (destructible) and
   `destroy_damage`, `active_phases` (empty = always targetable).
4. **Phases** (`BossPhaseDef`), in order:
   - Entry: `enter_at_health` (fraction) and/or `enter_when_destroyed`
     (weak point ids). The boss jumps to the latest phase whose condition holds.
   - `movement`, `attacks`, `attack_order` (`sequence`/`random`),
     `pause_between_attacks`, `hull_damage_multiplier` (0 = fully armoured).
   - On enter: `message`, `summon`, `tint`, `transition_time` (invulnerable).
5. Presentation: `health_bar_style` (`segmented` shows phase thresholds),
   `health_bar_color`, `defeat_duration`, `music_id`, `score`.
6. Assign it to a mission's `boss` and put `B` in the layout where the arena
   starts. The arena is one screen wide from that column, so leave 20 columns of
   floor (and ideally a wall) after `B`.

Mechanics that no combination of behaviours can express (e.g. a boss that
rides a conveyor) are a new `MovementDef`/`AttackDef` script as above, or a
`custom_logic` script on the mission.

---

## Add a new mission

1. Create `content/missions/m03_arctic_base/layout.txt` (see symbols below).
2. Duplicate a `mission.tres` into the folder and set `id`, `display_name`,
   `codename`, `description`, `environment`, `layout_file`, `legend`,
   `triggers`, `completion` (`defeat_boss` or `reach_exit`), `boss`, `par_time`.
3. Add it to `content/campaigns/main_campaign.tres` → `missions`.
   It also appears in Mission Select.
4. If you export the game, add `*.txt` to the export preset's
   *non-resource files to export* filter (layouts are plain text).

### Layout symbols

Each character is one 64×64 cell. 12 rows is one screen tall; ground is
usually rows 9-11. The player jumps about 2.5 tiles high.

| Symbol | Meaning |
|---|---|
| `.` or space | empty |
| `#` | solid ground (top/fill tile chosen automatically) |
| `%` | solid block (bunkers, crates, structures) |
| `=` | one-way platform (jump up through, Down+Jump to drop) |
| `^` | environment spike hazard |
| `~` | environment liquid hazard |
| `P` | player start |
| `C` | checkpoint |
| `B` | boss arena starts at this column |
| `E` | exit (for `completion = reach_exit`) |
| `*` | random environment prop |
| `1`-`9` | trigger N from `MissionDef.triggers` (fires when the player passes the column) |
| anything else | looked up in `MissionDef.legend`: `"enemy:<id>"` or `"pickup:<id>"` |

Ground enemies stand on the cell below their symbol; flying enemies spawn at
the symbol. Enemies activate when they come near the screen.

### Triggers

A `MissionTriggerDef` can show a `message`, `shake` the screen, change music,
and spawn `SpawnEntryDef`s (`enemy` or empty for the environment roster,
`count`, `interval`, `delay`, `side`: right/left/both/top). With
`lock_camera = true` it becomes an ambush: the screen holds until those
enemies are dead, then "GO >>>" appears.

### Different formats

`format` is `horizontal` for now. Vertical, arena, vehicle, boss-only,
survival and set-piece formats are reserved: add a runner scene extending
`MissionRunner`, register it in `Game.FORMAT_RUNNERS`, and existing content
(enemies, bosses, environments) works unchanged. For one unusual mission, set
`runner_scene` and/or `custom_logic` instead.
