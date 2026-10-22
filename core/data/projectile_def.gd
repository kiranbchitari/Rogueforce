class_name ProjectileDef
extends Resource
## A bullet, shell, grenade, missile or beam segment. Shared by player weapons
## and enemy/boss attacks.

@export var speed := 900.0
@export var damage := 1
@export var gravity := 0.0
@export var lifetime := 2.0
@export var radius := 5.0
## Greater than zero draws the placeholder as a streak of this length.
@export var length := 0.0
@export var color := Color(1, 0.9, 0.4)
@export var asset_id: StringName
@export var pierce := false
@export var hits_world := true
@export var explode_radius := 0.0
@export var explode_damage := 0
