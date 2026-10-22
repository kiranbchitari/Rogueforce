class_name HazardDef
extends Resource
## A damaging area (spikes, swamp, quicksand, lava, live wires...).
## Environments choose which hazard the layout symbols ^ and ~ mean.

@export var id: StringName
@export var display_name := ""
@export var damage := 1
@export var tick_interval := 0.6
## Liquids: the player is pulled out and put back on safe ground after a hit.
@export var respawn_player := false
## Spikes: the player is bounced upward on contact.
@export var bounce := false
@export var damages_enemies := false
@export var color := Color(0.8, 0.2, 0.2, 0.8)
@export var surface_color := Color(1, 0.5, 0.4)
@export var asset_id: StringName
