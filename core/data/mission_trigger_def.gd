class_name MissionTriggerDef
extends Resource
## A scripted moment, placed in a layout with a digit (1 = first trigger).
## Fires once when the player passes that column.

@export var message := ""
## Hold the screen until every spawned enemy is dead (ambushes, mini arenas).
@export var lock_camera := false
@export var spawns: Array[SpawnEntryDef] = []
@export var music_id: StringName
@export var shake := 0.0
