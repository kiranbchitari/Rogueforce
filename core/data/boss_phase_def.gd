class_name BossPhaseDef
extends Resource
## One stage of a boss fight. The boss moves to the first later phase whose
## entry condition is met.

@export var name := "phase"
@export_group("Enter when")
## Boss health fraction at or below which this phase starts (1.0 = immediately).
@export_range(0.0, 1.0) var enter_at_health := 1.0
## Also start this phase as soon as all of these weak points are destroyed.
@export var enter_when_destroyed: PackedStringArray = []
@export_group("Behaviour")
@export var movement: MovementDef
@export var attacks: Array[AttackDef] = []
@export_enum("sequence", "random") var attack_order := "sequence"
@export var pause_between_attacks := 0.6
## Damage multiplier for hits on the main body. 0 = armoured (only weak points work).
@export var hull_damage_multiplier := 1.0
@export_group("On enter")
@export var message := ""
@export var summon: Array[EnemyDef] = []
@export var tint := Color.WHITE
@export var transition_time := 1.2
