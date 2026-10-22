class_name VisualDef
extends Resource
## How something is drawn. Points at a stable asset id in
## res://assets/asset_manifest.json. When that asset has not been made yet the
## placeholder fields draw a labelled stand-in, so missing art never crashes.

@export var asset_id: StringName
## On-screen size in world pixels; sprites are scaled to fit it.
## Zero means "use the owner's body size".
@export var size := Vector2.ZERO
@export var offset := Vector2.ZERO
@export_enum("humanoid", "drone", "turret", "tank", "heli", "creature", "mech", "crate", "barrel", "capsule", "orb", "plant", "rock", "structure") var placeholder_shape := "humanoid"
@export var placeholder_color := Color(0.6, 0.6, 0.6)
