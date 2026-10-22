class_name StrafeMovement
extends MovementDef
## Travels between waypoints given as fractions of the arena (0..1), pausing
## at each. Ground units only use the x of each waypoint.

@export var waypoints: PackedVector2Array = [Vector2(0.75, 0.5), Vector2(0.25, 0.5)]
@export var speed := 160.0
@export var pause := 0.8
@export var face_target := true
@export var random_order := false


func setup(_actor: Actor, state: Dictionary) -> void:
	state.index = 0
	state.wait = pause


func tick(actor: Actor, state: Dictionary, delta: float) -> void:
	if waypoints.is_empty():
		return
	var area := actor.arena_rect if actor.arena_rect.has_area() else Rect2(actor.home_position - Vector2(300, 200), Vector2(600, 400))
	var wp: Vector2 = waypoints[state.index % waypoints.size()]
	var goal := area.position + wp * area.size
	var to_goal := goal - actor.global_position
	if not actor.flying:
		to_goal.y = 0.0
	if to_goal.length() < 10.0:
		actor.velocity.x = 0.0
		if actor.flying:
			actor.velocity.y = 0.0
		state.wait -= delta
		if state.wait <= 0.0:
			state.wait = pause
			state.index = randi() % waypoints.size() if random_order else state.index + 1
	else:
		var v := to_goal.normalized() * speed
		actor.velocity.x = v.x
		if actor.flying:
			actor.velocity.y = v.y
		if not face_target:
			actor.facing = 1 if v.x > 0.0 else -1
	if face_target and actor.target():
		actor.face_toward(actor.target().global_position.x)
