class_name SpawnEntryDef
extends Resource

## Leave empty to pick randomly from the environment's default roster.
@export var enemy: EnemyDef
@export var count := 1
@export var interval := 0.7
@export var delay := 0.0
@export_enum("right", "left", "both", "top") var side := "right"
