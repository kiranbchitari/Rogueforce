class_name Boss
extends Actor
## Generic boss driven by a BossDef: entrance, phases, weak points, armoured
## hull, telegraphed attacks and a defeat sequence.

signal health_changed(current: float, maximum: float)
signal phase_changed(index: int, phase: BossPhaseDef)
signal defeated

var def: BossDef
var health := 1.0
var phase_index := -1
var phase: BossPhaseDef
var hull: Hurtbox
var weak_points: Array[WeakPoint] = []
var invulnerable := true
var entering := true
var _transition := 0.0


func setup(d: BossDef, r: MissionRunner, arena: Rect2) -> void:
	def = d
	runner = r
	arena_rect = arena
	_init_body(d.body_size, d.flying)
	collision_layer = 0
	contact_damage = d.contact_damage
	health = d.max_health
	visual = ActorVisual.new()
	add_child(visual)
	visual.setup(d.visual, d.body_size)
	visual.shadow = not d.flying
	hull = Hurtbox.new()
	hull.runner = r
	hull.size = d.body_size * 0.9
	hull.team = RF.Team.ENEMY
	hull.receiver = self
	add_child(hull)
	for wd in d.weak_points:
		var wp := WeakPoint.new()
		wp.setup(wd, self, r)
		add_child(wp)
		weak_points.append(wp)
	attack_runner.enabled = false


## Call after the boss is in the tree. Plays the entrance, then starts phase 1.
func begin_entrance() -> void:
	var start := arena_rect.position + def.start_position * arena_rect.size
	if not flying:
		start.y = runner.ground_y_at(start.x, arena_rect.position.y) - body_size.y * 0.5
	home_position = start
	var from := start
	var tw := create_tween()
	match def.entrance:
		"drop_in":
			from.y = arena_rect.position.y - body_size.y
			tw.tween_property(self, "global_position", start, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.tween_callback(runner.shake.bind(14.0))
		"rise":
			from.y = arena_rect.end.y + body_size.y
			tw.tween_property(self, "global_position", start, 1.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_:
			from.x = arena_rect.end.x + body_size.x
			tw.tween_property(self, "global_position", start, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	global_position = from
	tw.tween_interval(0.5)
	tw.tween_callback(_start_fight)


func _start_fight() -> void:
	entering = false
	invulnerable = false
	attack_runner.enabled = true
	_enter_phase(0)


func _physics_process(delta: float) -> void:
	if entering:
		_update_visual()
		return
	super(delta)
	if not alive:
		return
	if _transition > 0.0:
		_transition -= delta
		if _transition <= 0.0:
			invulnerable = false
	_check_phase()


func _check_phase() -> void:
	for i in range(def.phases.size() - 1, phase_index, -1):
		var p := def.phases[i]
		if health <= def.max_health * p.enter_at_health or _all_destroyed(p.enter_when_destroyed):
			_enter_phase(i)
			return


func _all_destroyed(ids: PackedStringArray) -> bool:
	if ids.is_empty():
		return false
	for id in ids:
		var found := false
		for wp in weak_points:
			if String(wp.def.id) == id and wp.destroyed:
				found = true
		if not found:
			return false
	return true


func _enter_phase(i: int) -> void:
	phase_index = i
	phase = def.phases[i]
	attack_runner.cancel()
	motion_override = null
	set_movement(phase.movement)
	attack_runner.configure(phase.attacks, phase.attack_order, phase.pause_between_attacks, phase.transition_time if i > 0 else 0.8)
	hull.damage_multiplier = phase.hull_damage_multiplier
	for wp in weak_points:
		wp.set_phase(phase.name)
	visual.tint = phase.tint
	if i > 0:
		_transition = phase.transition_time
		invulnerable = true
		runner.shake(10.0)
		for k in 3:
			runner.spawn_explosion(global_position + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)) * body_size, 1.0)
	if phase.message != "":
		runner.hud.show_message(phase.message, 2.0)
	for e in phase.summon:
		runner.spawn_enemy(e, global_position + Vector2(randf_range(-140.0, 140.0), -body_size.y * 0.5 - 30.0), self)
	phase_changed.emit(i, phase)


func receive_hit(amount: float, _hb: Hurtbox, info: Dictionary) -> bool:
	if not alive:
		return false
	if invulnerable or entering or amount <= 0.0:
		runner.spawn_ping(info.get("pos", global_position))
		return true
	apply_damage(amount)
	Audio.play_sfx(&"sfx.hit", global_position)
	return true


func apply_damage(amount: float) -> void:
	if not alive:
		return
	health = maxf(health - amount, 0.0)
	flash()
	health_changed.emit(health, float(def.max_health))
	if health <= 0.0:
		_defeat()


func get_hit_rect() -> Rect2:
	return Rect2(global_position - body_size * 0.4, body_size * 0.8)


func _defeat() -> void:
	alive = false
	attack_runner.cancel()
	hull.enabled = false
	for wp in weak_points:
		wp.enabled = false
	runner.hud.show_message("TARGET NEUTRALISED", 2.5)
	var steps := int(def.defeat_duration / 0.18)
	for k in steps:
		runner.spawn_explosion(global_position + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) * body_size, randf_range(0.8, 1.6))
		runner.shake(5.0)
		await get_tree().create_timer(0.18, false).timeout
	runner.spawn_explosion(global_position, 3.0)
	runner.shake(18.0)
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.0, 0.6)
	await tw.finished
	defeated.emit()
