class_name HoverMovement
extends MovementDef
## Flies to a point above and beside the player and bobs there (drones,
## helicopters, floating creatures).

@export var speed := 260.0
@export var height_above_target := 220.0
@export var side_offset := 200.0
@export var bob_amplitude := 14.0
@export var bob_speed := 3.0
## Seconds between switching sides of the player. 0 = never.
@export var switch_side_every := 4.0


func setup(actor: Actor, state: Dictionary) -> void:
	state.side = -1.0 if actor.global_position.x < (actor.target().global_position.x if actor.target() else 0.0) else 1.0
	state.t = randf() * TAU
	state.switch = switch_side_every


func tick(actor: Actor, state: Dictionary, delta: float) -> void:
	state.t += delta
	var t := actor.target()
	if t == null:
		actor.velocity = actor.velocity.move_toward(Vector2.ZERO, speed * delta)
		return
	if switch_side_every > 0.0:
		state.switch -= delta
		if state.switch <= 0.0:
			state.switch = switch_side_every
			state.side = -state.side
	var goal: Vector2 = t.global_position + Vector2(side_offset * state.side, -height_above_target)
	goal.y += sin(state.t * bob_speed) * bob_amplitude
	var view := actor.view_rect().grow(-40.0)
	goal.y = clampf(goal.y, view.position.y + 30.0, view.end.y)
	var to_goal := goal - actor.global_position
	var desired := to_goal.limit_length(speed) if to_goal.length() > 8.0 else Vector2.ZERO
	actor.velocity = actor.velocity.lerp(desired, clampf(4.0 * delta, 0.0, 1.0))
	actor.face_toward(t.global_position.x)
