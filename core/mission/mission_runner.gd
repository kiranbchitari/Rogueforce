class_name MissionRunner
extends Node2D
## Shared mission runtime: builds the world from a MissionDef and provides
## combat services (projectiles, explosions, hurtboxes, spawning, FX) to every
## actor. Format-specific runners (horizontal today; vertical/arena later)
## extend this and override camera and progress rules.

var mission: MissionDef
var env: EnvironmentDef
var terrain: Terrain
var player: Player
var camera: Camera2D
var hud: Hud
var boss: Boss
var custom_logic: Node

var actors: Node2D
var projectiles: Node2D
var fx: Node2D

## "playing", "game_over", "complete"
var state := "playing"
var elapsed := 0.0
var kills := 0
var checkpoint_index := -1
var cam_center := Vector2.ZERO
var camera_lock := Rect2()

var _hurtboxes := {RF.Team.PLAYER: [], RF.Team.ENEMY: []}
var _pending_enemies: Array[Dictionary] = []
var _pending_triggers: Array[Dictionary] = []
var _checkpoints: Array[Dictionary] = []
var _player_start := Vector2(200, 200)
var _boss_marker := {}
var _exit_marker := {}
var _boss_state := "none"
var _wave := {}
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mission = Game.mission
	if mission == null:
		# Running this scene directly from the editor: use the first campaign mission.
		Game.campaign = Game.load_campaign()
		Game.character = Game.campaign.character
		Game.lives = Game.campaign.starting_lives
		mission = Game.campaign.missions[0]
		Game.mission = mission
	env = mission.environment
	_rng.seed = hash(mission.id)
	_build_world()
	_spawn_player()
	_build_camera()
	hud = Hud.new()
	add_child(hud)
	hud.bind(self)
	Audio.play_music(mission.music_id if mission.music_id != &"" else env.music_id)
	Audio.play_ambience(mission.ambience_id if mission.ambience_id != &"" else env.ambience_id)
	if mission.custom_logic:
		custom_logic = Node.new()
		custom_logic.set_script(mission.custom_logic)
		add_child(custom_logic)
		if custom_logic.has_method("mission_started"):
			custom_logic.mission_started(self)
	hud.show_message(("%s\n%s" % [mission.display_name, env.display_name]).to_upper(), 2.5)
	var missing := Assets.missing_ids()
	if not missing.is_empty():
		print("[ROGUEFORCE] Placeholders in use for %d asset ids: %s" % [missing.size(), ", ".join(missing)])


func _build_world() -> void:
	var text := FileAccess.get_file_as_string(mission.layout_file)
	if text == "":
		push_error("Mission %s: layout '%s' is empty or missing." % [mission.id, mission.layout_file])
		text = "P\n" + "#".repeat(40)
	terrain = Terrain.new()
	terrain.build(text, mission.legend, env, _rng)
	add_child(terrain)
	var built := EnvironmentBuilder.build(env, self, terrain.size_px)
	move_child(terrain, -1)
	actors = Node2D.new()
	add_child(actors)
	projectiles = Node2D.new()
	add_child(projectiles)
	fx = Node2D.new()
	fx.z_index = 20
	add_child(fx)
	set_meta("weather", built.weather)
	for m in terrain.markers:
		_add_marker(m)
	_pending_enemies.sort_custom(func(a, b): return a.pos.x < b.pos.x)
	_pending_triggers.sort_custom(func(a, b): return a.x < b.x)
	_checkpoints.sort_custom(func(a, b): return a.pos.x < b.pos.x)
	for i in _checkpoints.size():
		_checkpoints[i].index = i


func _add_marker(m: Dictionary) -> void:
	var meaning: String = m.meaning
	var parts := meaning.split(":", true, 1)
	match parts[0]:
		"player":
			_player_start = m.foot
		"checkpoint":
			var flag := CheckpointFlag.new()
			flag.position = m.foot
			terrain.add_child(flag)
			_checkpoints.append({"pos": m.foot, "flag": flag, "index": 0})
		"boss":
			_boss_marker = m
		"exit":
			_exit_marker = m
			var flag := CheckpointFlag.new()
			flag.is_exit = true
			flag.position = m.foot
			terrain.add_child(flag)
		"trigger":
			var idx := int(parts[1])
			if idx < mission.triggers.size():
				_pending_triggers.append({"x": m.center.x, "index": idx})
			else:
				push_warning("Layout trigger %d has no MissionTriggerDef." % (idx + 1))
		"enemy":
			var def := Content.enemy(parts[1])
			if def:
				_pending_enemies.append({"def": def, "pos": m.center if def.flying else m.foot - Vector2(0, def.body_size.y * 0.5)})
			else:
				push_warning("Unknown enemy id '%s' in layout." % parts[1])
		"pickup":
			var pd := Content.pickup(parts[1])
			if pd:
				spawn_pickup(pd, m.center, false)
			else:
				push_warning("Unknown pickup id '%s' in layout." % parts[1])
		"prop":
			pass
		_:
			push_warning("Unknown marker meaning '%s'." % meaning)


func _spawn_player() -> void:
	player = Player.new()
	player.setup(Game.character, self)
	var start := _player_start
	checkpoint_index = mini(Game.checkpoint, _checkpoints.size() - 1)
	if checkpoint_index >= 0:
		start = _checkpoints[checkpoint_index].pos
		for i in checkpoint_index + 1:
			_checkpoints[i].flag.reached = true
		_pending_enemies = _pending_enemies.filter(func(e): return e.pos.x > start.x + RF.VIEW_SIZE.x * 0.5)
		_pending_triggers = _pending_triggers.filter(func(t): return t.x > start.x)
	player.position = start - Vector2(0, player.body_size.y * 0.5 + 2.0)
	player.last_safe_position = player.position
	actors.add_child(player)
	player.died.connect(_on_player_died)


func _build_camera() -> void:
	camera = Camera2D.new()
	add_child(camera)
	cam_center = _clamp_camera(player.global_position)
	camera.global_position = cam_center
	camera.make_current()
	var weather: Node2D = get_meta("weather")
	if weather:
		camera.add_child(weather)


# --- Per-frame -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_camera(delta)
	if state != "playing":
		return
	elapsed += delta
	_activate_enemies()
	_check_progress()
	_check_hazards()
	_check_wave()


## Override in format runners. Default: follow the player inside the level.
func _update_camera(delta: float) -> void:
	var goal := camera_lock.get_center() if camera_lock.has_area() else player.global_position
	cam_center = _clamp_camera(cam_center.lerp(goal, clampf(6.0 * delta, 0.0, 1.0)))
	_apply_camera(delta)


func _apply_camera(delta: float) -> void:
	camera.global_position = cam_center
	_shake = maxf(_shake - 30.0 * delta, 0.0)
	camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))


func _clamp_camera(p: Vector2) -> Vector2:
	var half := RF.VIEW_SIZE * 0.5
	return Vector2(
		clampf(p.x, half.x, maxf(half.x, terrain.size_px.x - half.x)),
		clampf(p.y, half.y, maxf(half.y, terrain.size_px.y - half.y)))


## How far through the mission a position is. Horizontal missions use x.
func progress_of(p: Vector2) -> float:
	return p.x


func camera_rect() -> Rect2:
	return Rect2(cam_center - RF.VIEW_SIZE * 0.5, RF.VIEW_SIZE)


func clamp_to_view(body: Node2D) -> void:
	var r := camera_rect()
	var half: float = body.body_size.x * 0.5
	body.global_position.x = clampf(body.global_position.x, r.position.x + half, r.end.x - half)


func _activate_enemies() -> void:
	var view := camera_rect().grow(140.0)
	while not _pending_enemies.is_empty() and _pending_enemies[0].pos.x < view.end.x:
		var e: Dictionary = _pending_enemies.pop_front()
		if e.pos.x > view.position.x:
			spawn_enemy(e.def, e.pos)
	var behind := camera_rect().position.x - 500.0
	for a in actors.get_children():
		if a is Enemy and a.global_position.x < behind and not _wave_has(a):
			a.queue_free()


func _check_progress() -> void:
	var px := progress_of(player.global_position)
	for cp in _checkpoints:
		if not cp.flag.reached and px >= progress_of(cp.pos):
			cp.flag.reached = true
			checkpoint_index = cp.index
			hud.show_message("CHECKPOINT", 1.4)
			Audio.play_sfx(&"sfx.checkpoint")
	while not _pending_triggers.is_empty() and px >= _pending_triggers[0].x:
		_fire_trigger(_pending_triggers.pop_front().index)
	if _boss_state == "none" and mission.boss and not _boss_marker.is_empty() and px >= _boss_marker.center.x + RF.TILE * 2:
		_start_boss()
	if mission.completion == "reach_exit" and not _exit_marker.is_empty() and px >= _exit_marker.center.x:
		complete()


func _check_hazards() -> void:
	if not player.alive:
		return
	var h := terrain.hazard_at(player.get_hit_rect())
	if h:
		player.touch_hazard(h)


func is_safe_ground(pos: Vector2, body: Vector2) -> bool:
	var feet := pos.y + body.y * 0.5 + 6.0
	if not (terrain.is_ground_at(Vector2(pos.x - body.x * 0.5, feet)) and terrain.is_ground_at(Vector2(pos.x + body.x * 0.5, feet))):
		return false
	return terrain.hazard_at(Rect2(pos - body * 0.5, body).grow(RF.TILE)) == null


## A safe standing spot inside the current view, as close to prefer_x as possible.
func find_respawn_point(prefer_x: float) -> Vector2:
	var view := camera_rect()
	var half := player.body_size
	var x0 := clampf(prefer_x, view.position.x + 80.0, view.end.x - 80.0)
	for step in 30:
		for s in [1, -1]:
			var x: float = x0 + s * step * RF.TILE * 0.5
			if x < view.position.x + 40.0 or x > view.end.x - 40.0:
				continue
			var gy := terrain.ground_y_at(x, view.position.y)
			var p := Vector2(x, gy - half.y * 0.5 - 2.0)
			if gy < terrain.size_px.y and is_safe_ground(p, half):
				return p
	return _player_start - Vector2(0, half.y * 0.5 + 2.0)


func ground_y_at(x: float, from_y: float) -> float:
	return terrain.ground_y_at(x, from_y)


# --- Triggers, waves and bosses --------------------------------------------

func _fire_trigger(index: int) -> void:
	var t: MissionTriggerDef = mission.triggers[index]
	if t.message != "":
		hud.show_message(t.message, 2.0)
	if t.music_id != &"":
		Audio.play_music(t.music_id)
	if t.shake > 0.0:
		shake(t.shake)
	if t.lock_camera:
		camera_lock = camera_rect()
		_wave = {"remaining": 0, "enemies": []}
	for entry in t.spawns:
		if t.lock_camera:
			_wave.remaining += entry.count * (2 if entry.side == "both" else 1)
		_run_spawn_entry(entry, t.lock_camera)
	if custom_logic and custom_logic.has_method("trigger_fired"):
		custom_logic.trigger_fired(self, index)


func _run_spawn_entry(entry: SpawnEntryDef, in_wave: bool) -> void:
	if entry.delay > 0.0:
		await get_tree().create_timer(entry.delay, false).timeout
	for i in entry.count:
		var sides: Array = ["left", "right"] if entry.side == "both" else [entry.side]
		for side in sides:
			if state != "playing":
				return
			var def := entry.enemy
			if def == null and not env.default_roster.is_empty():
				def = env.default_roster[_rng.randi() % env.default_roster.size()]
			if in_wave and not _wave.is_empty():
				_wave.remaining -= 1
			if def == null:
				continue
			var e := spawn_enemy(def, _edge_spawn_point(def, side))
			if in_wave and not _wave.is_empty():
				_wave.enemies.append(e)
		if i < entry.count - 1:
			await get_tree().create_timer(entry.interval, false).timeout


func _edge_spawn_point(def: EnemyDef, side: String) -> Vector2:
	var view := camera_rect()
	var x := view.end.x + 40.0
	if side == "left":
		x = view.position.x - 40.0
	elif side == "top":
		x = _rng.randf_range(view.position.x + 120.0, view.end.x - 120.0)
	if def.flying:
		var y := view.position.y - 40.0 if side == "top" else view.position.y + _rng.randf_range(90.0, 240.0)
		return Vector2(x, y)
	if side == "top":
		return Vector2(x, view.position.y - def.body_size.y)
	# Walk inward until there is ground to stand on.
	for k in 12:
		var gx := x + (k * RF.TILE * (1 if side == "left" else -1))
		var gy := terrain.ground_y_at(gx, view.position.y)
		if gy < terrain.size_px.y:
			return Vector2(gx, gy - def.body_size.y * 0.5 - 2.0)
	return Vector2(x, view.position.y)


func _wave_has(a: Node) -> bool:
	return not _wave.is_empty() and _wave.enemies.has(a)


func _check_wave() -> void:
	if _wave.is_empty() or _wave.remaining > 0:
		return
	for e in _wave.enemies:
		if is_instance_valid(e) and e.alive and e.def.counts_as_enemy:
			return
	_wave = {}
	if _boss_state != "fight":
		camera_lock = Rect2()
		hud.show_go()


func _start_boss() -> void:
	_boss_state = "intro"
	var x0: float = _boss_marker.cell.x * RF.TILE
	x0 = clampf(x0, 0.0, terrain.size_px.x - RF.VIEW_SIZE.x)
	var cy := _clamp_camera(Vector2(x0 + RF.VIEW_SIZE.x * 0.5, player.global_position.y - 60.0)).y
	camera_lock = Rect2(Vector2(x0, cy - RF.VIEW_SIZE.y * 0.5), RF.VIEW_SIZE)
	_wave = {}
	Audio.stop_all()
	Audio.play_sfx(&"sfx.boss_warning")
	hud.show_warning(mission.boss)
	await get_tree().create_timer(2.4, false).timeout
	if state != "playing":
		return
	boss = Boss.new()
	boss.setup(mission.boss, self, camera_lock)
	actors.add_child(boss)
	boss.begin_entrance()
	boss.defeated.connect(_on_boss_defeated)
	hud.show_boss(boss)
	if mission.boss.music_id != &"":
		Audio.play_music(mission.boss.music_id)
	_boss_state = "fight"


func _on_boss_defeated() -> void:
	_boss_state = "defeated"
	add_score(mission.boss.score, boss.global_position)
	hud.hide_boss()
	for a in actors.get_children():
		if a is Enemy and a.alive:
			a.die()
	if custom_logic and custom_logic.has_method("boss_defeated"):
		custom_logic.boss_defeated(self)
	if mission.completion == "defeat_boss":
		complete()
	else:
		camera_lock = Rect2()


func complete() -> void:
	if state != "playing":
		return
	state = "complete"
	player.control_enabled = false
	hud.show_banner("MISSION COMPLETE")
	Audio.play_music(&"music.victory")
	await get_tree().create_timer(3.0, false).timeout
	var time_bonus := maxi(0, int((mission.par_time - elapsed) * 20.0))
	Game.mission_completed({
		"mission": mission.display_name,
		"score": Game.score + time_bonus,
		"time": elapsed,
		"time_bonus": time_bonus,
		"kills": kills,
		"lives": Game.lives,
	})


func _on_player_died() -> void:
	await get_tree().create_timer(1.3, false).timeout
	if state != "playing":
		return
	if Game.lives > 0:
		Game.lives -= 1
		hud.refresh()
		player.respawn(find_respawn_point(cam_center.x - RF.VIEW_SIZE.x * 0.25))
	else:
		state = "game_over"
		hud.show_game_over()


# --- Combat services used by actors and behaviours -------------------------

func register_hurtbox(hb: Hurtbox) -> void:
	_hurtboxes[hb.team].append(hb)


func unregister_hurtbox(hb: Hurtbox) -> void:
	_hurtboxes[hb.team].erase(hb)


## Hurtboxes a projectile from `team` can damage.
func hurtboxes_against(team: int) -> Array:
	return _hurtboxes[RF.Team.ENEMY if team == RF.Team.PLAYER else RF.Team.PLAYER]


## `dir` is a unit direction, or the full velocity when raw_velocity is true.
func spawn_projectile(def: ProjectileDef, origin: Vector2, dir: Vector2, team: int, raw_velocity := false) -> Projectile:
	var p := Projectile.new()
	p.setup(def, dir if raw_velocity else dir.normalized() * def.speed, team, self)
	p.position = origin
	projectiles.add_child(p)
	return p


func spawn_enemy(def: EnemyDef, pos: Vector2, summoner: Actor = null) -> Enemy:
	var e := Enemy.new()
	e.setup(def, self)
	e.position = pos
	if summoner:
		e.summoner = summoner
		summoner.summoned.append(e)
	actors.add_child(e)
	return e


func spawn_pickup(def: PickupDef, pos: Vector2, dropped := true) -> void:
	var p := Pickup.new()
	p.setup(def, self, dropped)
	p.position = pos
	actors.add_child(p)


func on_enemy_killed(e: Enemy) -> void:
	var d := e.def
	if d.counts_as_enemy:
		kills += 1
	add_score(d.score, e.global_position)
	spawn_explosion(e.global_position, clampf(e.body_size.length() / 90.0, 0.5, 2.5))
	if d.death_explosion_radius > 0.0:
		explode(e.global_position, d.death_explosion_radius, d.death_explosion_damage, -1)
	if d.drop and _rng.randf() < d.drop_chance:
		spawn_pickup.call_deferred(d.drop, e.global_position)


## Area damage. source_team -1 hurts both sides (barrels, fuel tanks).
func explode(pos: Vector2, radius: float, damage: int, source_team: int) -> void:
	spawn_explosion(pos, radius / 60.0)
	shake(radius / 12.0)
	var teams := [RF.Team.PLAYER, RF.Team.ENEMY] if source_team < 0 else [RF.Team.ENEMY if source_team == RF.Team.PLAYER else RF.Team.PLAYER]
	for team in teams:
		for hb in _hurtboxes[team].duplicate():
			if not is_instance_valid(hb) or not hb.enabled:
				continue
			var r: Rect2 = hb.get_rect()
			var closest := Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))
			if closest.distance_to(pos) <= radius:
				hb.take_hit(damage, {"dir": (r.get_center() - pos).normalized(), "pos": closest, "team": source_team})


func add_score(amount: int, at := Vector2.INF) -> void:
	Game.score += amount
	hud.refresh()
	if at != Vector2.INF and amount > 0:
		var e := Effect.new()
		e.setup("popup")
		e.text = str(amount)
		e.position = at - Vector2(0, 40)
		fx.add_child(e)


func spawn_explosion(pos: Vector2, size := 1.0) -> void:
	var e := Effect.new()
	e.setup("explosion", size)
	e.position = pos
	fx.add_child(e)
	Audio.play_sfx(&"sfx.explosion", pos)


func spawn_spark(pos: Vector2, color := Color(1, 0.9, 0.5)) -> void:
	var e := Effect.new()
	e.setup("spark", 1.0, color)
	e.position = pos
	fx.add_child(e)


func spawn_ping(pos: Vector2) -> void:
	var e := Effect.new()
	e.setup("ping")
	e.position = pos
	fx.add_child(e)
	Audio.play_sfx(&"sfx.ping", pos)


func spawn_muzzle_flash(pos: Vector2, color: Color) -> void:
	var e := Effect.new()
	e.setup("muzzle", 1.0, color)
	e.position = pos
	fx.add_child(e)


func show_telegraph(kind: String, actor: Actor, attack: AttackDef, ctx: Dictionary, duration: float) -> void:
	var t := Telegraph.new()
	t.setup(kind, actor, attack, ctx, duration)
	fx.add_child(t)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)
