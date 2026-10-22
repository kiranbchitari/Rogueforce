class_name WeaponDef
extends Resource

@export var id: StringName
@export var display_name := ""
@export var projectile: ProjectileDef
## Seconds between shots while the fire button is held.
@export var fire_interval := 0.16
@export var count := 1
@export var spread_deg := 0.0
@export var jitter_deg := 0.0
@export var muzzle_color := Color(1, 0.85, 0.4)
@export var sfx_id: StringName = &"sfx.shot"
@export var hud_color := Color.WHITE
