class_name PatrolMovement
extends MovementDef
## Walks back and forth, turning at walls and ledges. Stops to face the
## player once they come within engage_range.

@export var speed := 90.0
@export var turn_at_ledges := true
## 0 = never stops patrolling.
@export var engage_range := 420.0


func setup(actor: Actor, state: Dictionary) -> void:
	state.dir = actor.facing


func tick(actor: Actor, state: Dictionary, _delta: float) -> void:
	var t := actor.target()
	if t and engage_range > 0.0 and actor.global_position.distance_to(t.global_position) < engage_range:
		actor.velocity.x = 0.0
		actor.face_toward(t.global_position.x)
		return
	if actor.is_on_wall() or (turn_at_ledges and actor.is_on_floor() and actor.ledge_ahead(state.dir)):
		state.dir = -state.dir
	actor.velocity.x = speed * state.dir
	actor.facing = state.dir
