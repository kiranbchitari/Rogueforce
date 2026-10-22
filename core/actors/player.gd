class_name Player
extends CharacterBody2D
## The player commando. Tuning comes from a CharacterDef; weapons from WeaponDefs.

signal health_changed(current: int, maximum: int)
signal weapon_changed(weapon: WeaponDef)
signal died

var def: CharacterDef
var runner: MissionRunner
var weapon: WeaponDef
var visual: ActorVisual
var hurtbox: Hurtbox
var health := 3
var alive := true
var facing := 1
var aim := Vector2.RIGHT
var crouching := false
var control_enabled := true
var body_size := Vector2(40, 84)
var last_safe_position := Vector2.ZERO

var _shape: CollisionShape2D
var _rect: RectangleShape2D
var _invuln := 0.0
var _fire_cd := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _drop_timer := 0.0
var _hazard_cd := 0.0


func setup(d: CharacterDef, r: MissionRunner) -> void:
	def = d
	runner = r
	body_size = d.body_size
	health = d.max_health
	collision_layer = RF.LAYER_PLAYER
	collision_mask = RF.LAYER_WORLD | RF.LAYER_PLATFORM
	_shape = CollisionShape2D.new()
	_rect = RectangleShape2D.new()
	_rect.size = body_size
	_shape.shape = _rect
	add_child(_shape)
	visual = ActorVisual.new()
	add_child(visual)
	visual.setup(d.visual, body_size)
	visual.z_index = 5
	visual.shadow = true
	hurtbox = Hurtbox.new()
	hurtbox.runner = r
	hurtbox.team = RF.Team.PLAYER
	hurtbox.receiver = self
	hurtbox.size = body_size * Vector2(0.7, 0.85)
	add_child(hurtbox)
	set_weapon(d.default_weapon)


func set_weapon(w: WeaponDef) -> void:
	weapon = w
	weapon_changed.emit(w)


func is_invulnerable() -> bool:
	return _invuln > 0.0


func _physics_process(delta: float) -> void:
	if not alive:
		velocity.y = minf(velocity.y + def.gravity * delta, 1400.0)
		position += velocity * delta
		visual.rotation += delta * 8.0 * -facing
		return
	_tick_timers(delta)
	var ix := Input.get_axis("move_left", "move_right") if control_enabled else 0.0
	var up := control_enabled and Input.is_action_pressed("move_up")
	var down := control_enabled and Input.is_action_pressed("move_down")
	var on_floor := is_on_floor()
	_coyote = 0.1 if on_floor else _coyote - delta

	_set_crouch(on_floor and down and absf(ix) < 0.1)
	velocity.x = 0.0 if crouching else ix * def.run_speed
	if absf(ix) > 0.1:
		facing = 1 if ix > 0.0 else -1
	_update_aim(ix, up, down, on_floor)

	if control_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.12
	if _jump_buffer > 0.0:
		if down and on_floor and _on_platform():
			set_collision_mask_value(2, false)
			_drop_timer = 0.25
			_jump_buffer = 0.0
		elif _coyote > 0.0:
			velocity.y = -def.jump_velocity
			_jump_buffer = 0.0
			_coyote = 0.0
			Audio.play_sfx(&"sfx.jump", global_position)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45
	velocity.y = minf(velocity.y + def.gravity * delta, 1500.0)
	move_and_slide()
	runner.clamp_to_view(self)

	if on_floor and runner.is_safe_ground(global_position, body_size):
		last_safe_position = global_position
	if control_enabled and Input.is_action_pressed("shoot") and _fire_cd <= 0.0:
		_fire()
	if global_position.y > runner.terrain.size_px.y + 160.0:
		hit_pit()
	_update_visual(on_floor, ix)


func _tick_timers(delta: float) -> void:
	_fire_cd -= delta
	_jump_buffer -= delta
	_hazard_cd -= delta
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(2, true)
	if _invuln > 0.0:
		_invuln -= delta
		visual.visible = _invuln <= 0.0 or fmod(_invuln, 0.12) > 0.05


func _set_crouch(on: bool) -> void:
	if on == crouching:
		return
	crouching = on
	var h := def.crouch_height if on else body_size.y
	_rect.size = Vector2(body_size.x, h)
	_shape.position.y = (body_size.y - h) * 0.5
	hurtbox.size = Vector2(body_size.x * 0.7, h * 0.85)
	hurtbox.position.y = _shape.position.y


func _update_aim(ix: float, up: bool, down: bool, on_floor: bool) -> void:
	var sx := signf(ix)
	if up:
		aim = Vector2(sx, -1).normalized() if sx != 0.0 else Vector2.UP
	elif down and not on_floor:
		aim = Vector2(sx, 1).normalized() if sx != 0.0 else Vector2.DOWN
	elif down and sx != 0.0:
		aim = Vector2(sx, 1).normalized()
	else:
		aim = Vector2(facing, 0)


func _on_platform() -> bool:
	return runner.terrain.is_platform_at(global_position + Vector2(0, body_size.y * 0.5 + 6.0))


func muzzle_position() -> Vector2:
	var base := global_position + Vector2(0, 18 if crouching else -14)
	return base + aim * 34.0


func _fire() -> void:
	if weapon == null or weapon.projectile == null:
		return
	_fire_cd = weapon.fire_interval
	var origin := muzzle_position()
	var base := aim.angle()
	for i in weapon.count:
		var a := base
		if weapon.count > 1:
			a += deg_to_rad(weapon.spread_deg) * (float(i) / float(weapon.count - 1) - 0.5)
		a += deg_to_rad(randf_range(-weapon.jitter_deg, weapon.jitter_deg))
		runner.spawn_projectile(weapon.projectile, origin, Vector2.from_angle(a), RF.Team.PLAYER)
	runner.spawn_muzzle_flash(origin, weapon.muzzle_color)
	visual.kick()
	Audio.play_sfx(weapon.sfx_id, origin)


func _update_visual(on_floor: bool, ix: float) -> void:
	visual.facing = facing
	visual.aim = aim
	visual.move_speed = absf(velocity.x)
	visual.grounded = on_floor
	if not on_floor:
		visual.play("jump")
	elif crouching:
		visual.play("crouch")
	elif absf(ix) > 0.1:
		visual.play("run")
	else:
		visual.play("idle")


func get_hit_rect() -> Rect2:
	return hurtbox.get_rect()


func receive_hit(amount: float, _hb: Hurtbox, info: Dictionary) -> bool:
	if not alive or _invuln > 0.0:
		return false
	take_damage(int(ceil(amount)), info)
	return true


func take_damage(amount: int, info := {}) -> void:
	if not alive or _invuln > 0.0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, def.max_health)
	runner.shake(6.0)
	Audio.play_sfx(&"sfx.hurt", global_position)
	if health <= 0:
		_die()
		return
	_invuln = def.invulnerable_time
	var dir: Vector2 = info.get("dir", Vector2(-facing, 0))
	velocity = Vector2(signf(dir.x) * 260.0 if dir.x != 0.0 else -facing * 260.0, -380.0)


## Hazard contact (spikes, swamp, lava...).
func touch_hazard(h: HazardDef) -> void:
	if not alive or _hazard_cd > 0.0:
		return
	_hazard_cd = h.tick_interval
	if h.bounce:
		velocity.y = -def.jump_velocity * 0.7
	if _invuln <= 0.0:
		take_damage(h.damage, {"dir": Vector2(-facing, 0)})
	if alive and h.respawn_player:
		_return_to_safety()


func hit_pit() -> void:
	if not alive:
		return
	_invuln = 0.0
	take_damage(1)
	if alive:
		_return_to_safety()


func _return_to_safety() -> void:
	global_position = runner.find_respawn_point(last_safe_position.x)
	velocity = Vector2.ZERO
	_invuln = def.invulnerable_time


func _die() -> void:
	alive = false
	hurtbox.enabled = false
	_invuln = 0.0
	visual.visible = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2(-facing * 200.0, -600.0)
	runner.spawn_explosion(global_position, 0.8)
	Audio.play_sfx(&"sfx.death", global_position)
	died.emit()


## Bring the player back after losing a life.
func respawn(at: Vector2, full_health := true) -> void:
	global_position = at
	velocity = Vector2.ZERO
	visual.rotation = 0.0
	alive = true
	hurtbox.enabled = true
	collision_layer = RF.LAYER_PLAYER
	collision_mask = RF.LAYER_WORLD | RF.LAYER_PLATFORM
	if full_health:
		health = def.max_health
	health_changed.emit(health, def.max_health)
	_invuln = 2.4
	set_weapon(def.default_weapon)


func heal(amount: int) -> void:
	health = mini(health + amount, def.max_health)
	health_changed.emit(health, def.max_health)
