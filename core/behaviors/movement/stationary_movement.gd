class_name StationaryMovement
extends MovementDef
## Holds position (turrets, snipers, emplacements).

@export var track_target := true


func tick(actor: Actor, _state: Dictionary, delta: float) -> void:
	actor.velocity.x = move_toward(actor.velocity.x, 0.0, 2000.0 * delta)
	if actor.flying:
		actor.velocity.y = move_toward(actor.velocity.y, 0.0, 2000.0 * delta)
	if track_target and actor.target():
		actor.face_toward(actor.target().global_position.x)
