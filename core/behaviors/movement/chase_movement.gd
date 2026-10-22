class_name ChaseMovement
extends MovementDef
## Closes to a preferred distance from the player, backing off if too close.
## Covers rushers (distance 0), riflemen (~300) and grenadiers (~450).

@export var speed := 150.0
@export var preferred_distance := 300.0
@export var tolerance := 60.0
@export var retreat := true
@export var avoid_ledges := true
## Greater than zero lets the enemy hop over low walls.
@export var jump_velocity := 0.0


func tick(actor: Actor, _state: Dictionary, _delta: float) -> void:
	var t := actor.target()
	if t == null:
		actor.velocity.x = 0.0
		return
	var dx := t.global_position.x - actor.global_position.x
	actor.face_toward(t.global_position.x)
	var dist := absf(dx)
	var dir := 0.0
	if dist > preferred_distance + tolerance:
		dir = signf(dx)
	elif retreat and dist < preferred_distance - tolerance:
		dir = -signf(dx)
	if dir != 0.0 and avoid_ledges and actor.is_on_floor() and actor.ledge_ahead(int(dir)):
		dir = 0.0
	actor.velocity.x = speed * dir
	if jump_velocity > 0.0 and dir != 0.0 and actor.is_on_floor() and actor.is_on_wall():
		actor.velocity.y = -jump_velocity
