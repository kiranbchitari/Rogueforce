class_name WeakPointDef
extends Resource
## A separately targetable part of a boss: a turret, engine, eye or core.

@export var id: StringName
@export var display_name := ""
## Offset from the boss centre when facing left (mirrored when facing right).
@export var offset := Vector2.ZERO
@export var size := Vector2(48, 48)
## Damage dealt to the boss is multiplied by this when this part is hit.
@export var damage_multiplier := 2.0
## Greater than zero makes the part destructible with its own health.
@export var health := 0
## Bonus damage dealt to the boss when this part is destroyed.
@export var destroy_damage := 0
## Phase names where this part can be hit. Empty means every phase.
@export var active_phases: PackedStringArray = []
@export var visual: VisualDef
