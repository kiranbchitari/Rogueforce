class_name MissionDef
extends Resource
## Everything that makes a mission: which world it is set in, its layout,
## scripted triggers, boss and win condition. Adding a mission is normally a
## layout .txt plus one of these.

@export var id: StringName
@export var display_name := ""
@export var codename := ""
@export_multiline var description := ""
## Only "horizontal" has a runner today. Others are reserved for future runners.
@export_enum("horizontal", "vertical", "arena", "vehicle", "boss_only", "survival", "set_piece") var format := "horizontal"
@export var environment: EnvironmentDef

@export_group("Layout")
## ASCII layout. See docs/ADDING_CONTENT.md for the symbol table.
@export_file("*.txt") var layout_file := ""
## Extra symbols for this mission, e.g. "a": "enemy:infantry", "S": "pickup:spread".
@export var legend: Dictionary[String, String] = {}
## Triggers referenced by digits 1-9 in the layout.
@export var triggers: Array[MissionTriggerDef] = []

@export_group("Goal")
@export_enum("defeat_boss", "reach_exit") var completion := "defeat_boss"
@export var boss: BossDef
@export var par_time := 240.0

@export_group("Audio")
## Overrides the environment's music/ambience when set.
@export var music_id: StringName
@export var ambience_id: StringName

@export_group("Advanced")
## Replaces the format's default runner scene (for one-off geometry/mechanics).
@export var runner_scene: PackedScene
## Optional script (extends Node) with hooks: mission_started(runner),
## trigger_fired(runner, index), boss_defeated(runner).
@export var custom_logic: Script
