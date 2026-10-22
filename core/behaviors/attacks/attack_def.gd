class_name AttackDef
extends Resource
## Base class for reusable attacks. The AttackRunner drives every attack the
## same way: telegraph -> begin -> fire x burst_count -> active_time -> end ->
## recovery -> cooldown. Subclasses only decide what "fire" does.
##
## `ctx` is a per-use Dictionary: ctx.target is the aim point captured when the
## telegraph starts, ctx.points can hold extra positions (e.g. shell impacts).

@export var label := ""
@export var cooldown := 2.0
@export var min_range := 0.0
@export var max_range := 800.0
@export_enum("none", "flash", "aim_line", "ground_marker") var telegraph := "flash"
@export var telegraph_time := 0.35
@export var burst_count := 1
@export var burst_interval := 0.12
## Time spent after the last shot before recovery (used by charges).
@export var active_time := 0.0
@export var recovery := 0.35
@export var stop_moving := true
## Muzzle offset from the actor centre when facing right (x mirrors with facing).
@export var muzzle_offset := Vector2(28, -12)
@export var projectile: ProjectileDef
@export var sfx_id: StringName = &"sfx.enemy_shot"


func muzzle_position(actor: Actor) -> Vector2:
	return actor.global_position + Vector2(muzzle_offset.x * actor.facing, muzzle_offset.y)


## Fill ctx before the telegraph is shown (e.g. choose impact points).
func prepare(_actor: Actor, _ctx: Dictionary) -> void:
	pass


func begin(_actor: Actor, _ctx: Dictionary) -> void:
	pass


func fire(_actor: Actor, _ctx: Dictionary, _shot_index: int) -> void:
	pass


func end(_actor: Actor, _ctx: Dictionary) -> void:
	pass
