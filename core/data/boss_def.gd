class_name BossDef
extends Resource
## A boss encounter. Bosses share one framework (phases, weak points,
## telegraphed attacks, health bar) but movement and attacks are fully
## configurable per phase, so each boss can play differently.

@export var id: StringName
@export var display_name := ""
@export var title := ""
@export var visual: VisualDef
@export var body_size := Vector2(200, 120)
@export var max_health := 200
@export var contact_damage := 1
@export var flying := false
@export_enum("drop_in", "enter_right", "rise") var entrance := "enter_right"
## Where the boss starts inside the arena (0..1 of the arena rectangle).
@export var start_position := Vector2(0.78, 0.5)
@export var weak_points: Array[WeakPointDef] = []
@export var phases: Array[BossPhaseDef] = []
@export_enum("segmented", "single") var health_bar_style := "segmented"
@export var health_bar_color := Color(0.9, 0.2, 0.15)
@export var defeat_duration := 2.6
@export var score := 5000
@export var music_id: StringName
