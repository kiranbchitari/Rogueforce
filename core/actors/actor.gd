class_name Actor
extends CharacterBody2D
## Shared base for enemies and bosses: physics, facing, movement behaviour,
## attack runner, contact damage and helpers that behaviours rely on.

var runner: MissionRunner
var visual: ActorVisual
var attack_runner: AttackRunner
var movement: MovementDef
var move_state := {}
var body_size := Vector2(40, 80)
var flying := false
var facing := -1
var alive := true
var attacking := false
## Set by attacks such as charges to take over movement. null = normal.
var motion_override = null
var contact_damage := 1
var home_position := Vector2.ZERO
var arena_rect := Rect2()
var summoned: Array[Actor] = []
var _flash := 0.0


func _init_body(size: Vector2, is_flying: bool) -> void:
	body_size = size
	flying = is_flying
	collision_layer = RF.LAYER_ENEMY
	collision_mask = 0 if flying else RF.LAYER_WORLD | RF.LAYER_PLATFORM
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	attack_runner = AttackRunner.new()
	attack_runner.actor = self
	add_child(attack_runner)


func set_movement(m: MovementDef) -> void:
	movement = m
	move_state = {}
	if movement:
		movement.setup(self, move_state)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if motion_override != null:
		velocity.x = motion_override.x
		if flying:
			velocity.y = motion_override.y
	elif attacking:
		velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
		if flying:
			velocity.y = move_toward(velocity.y, 0.0, 1800.0 * delta)
	elif movement:
		movement.tick(self, move_state, delta)
	if not flying:
		velocity.y = minf(velocity.y + RF.GRAVITY * delta, 1400.0)
	move_and_slide()
	var p := runner.player
	if contact_damage > 0 and p and p.alive and get_hit_rect().grow(-6.0).intersects(p.get_hit_rect()):
		p.take_damage(contact_damage, {"dir": Vector2(signf(p.global_position.x - global_position.x), 0), "pos": global_position})
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			visual.modulate = Color.WHITE
	_update_visual()


func _update_visual() -> void:
	visual.facing = facing
	visual.move_speed = absf(velocity.x)
	visual.velocity = velocity
	visual.grounded = is_on_floor()
	var t := target()
	if t:
		visual.aim = (t.global_position - global_position).normalized()
	if absf(velocity.x) > 10.0 and not flying:
		visual.play("run")
	elif attacking:
		visual.play("attack")
	else:
		visual.play("idle")


func flash() -> void:
	_flash = 0.07
	visual.modulate = Color(2.2, 2.2, 2.2)


func target() -> Player:
	var p := runner.player if runner else null
	return p if p and p.alive else null


func distance_to_target() -> float:
	var t := target()
	return global_position.distance_to(t.global_position) if t else INF


func face_toward(x: float) -> void:
	if absf(x - global_position.x) > 4.0:
		facing = 1 if x > global_position.x else -1


func view_rect() -> Rect2:
	return runner.camera_rect()


func can_attack() -> bool:
	return target() != null and view_rect().grow(-24.0).has_point(global_position)


func ledge_ahead(dir: int) -> bool:
	var probe := global_position + Vector2(dir * (body_size.x * 0.5 + 6.0), body_size.y * 0.5 + 8.0)
	return not runner.terrain.is_ground_at(probe)


func get_hit_rect() -> Rect2:
	return Rect2(global_position - body_size * 0.5, body_size)


func live_summons() -> int:
	summoned = summoned.filter(func(s): return is_instance_valid(s) and s.alive)
	return summoned.size()
