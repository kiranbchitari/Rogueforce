class_name PickupDef
extends Resource

@export var id: StringName
@export var display_name := ""
@export_enum("weapon", "health", "life", "score") var kind := "weapon"
@export var weapon: WeaponDef
@export var amount := 1
## Letter drawn on the placeholder capsule.
@export var label := "?"
@export var visual: VisualDef
