class_name CharacterDef
extends Resource
## A playable character. Tuning lives here so new heroes are data, not code.

@export var id: StringName
@export var display_name := ""
@export var visual: VisualDef
@export var body_size := Vector2(40, 84)
@export var crouch_height := 50.0
@export var run_speed := 340.0
@export var jump_velocity := 860.0
@export var gravity := 2300.0
@export var max_health := 3
@export var invulnerable_time := 1.6
@export var default_weapon: WeaponDef
