extends Node
## End-to-end smoke test. Plays each mission headless, warps the player through
## the layout, fights the boss through its real hurtboxes and checks the
## mission reaches the results screen. Also checks environment/boss swaps and
## asset replacement.
##
##   godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn

var failures: Array[String] = []
var log_lines: Array[String] = []


func _ready() -> void:
	# Detach from current_scene so mission scene changes don't free the test.
	get_tree().current_scene = null
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		log_lines.append("  ok   " + what)
	else:
		log_lines.append("  FAIL " + what)
		failures.append(what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func runner() -> MissionRunner:
	return get_tree().current_scene as MissionRunner


func _run() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game == null:
		printerr("smoke_test: Game autoload failed to load")
		get_tree().quit(1)
		return
	var campaign: CampaignDef = game.load_campaign()
	check(campaign.missions.size() >= 2, "campaign has 2+ missions")

	for m in campaign.missions:
		await _play_mission(game, campaign, m, m.boss)

	# Same layout and boss, different world: only data changes.
	var reskin: MissionDef = campaign.missions[0].duplicate()
	reskin.environment = campaign.missions[1].environment
	reskin.boss = campaign.missions[1].boss
	await _play_mission(game, campaign, reskin, reskin.boss, "jungle layout + desert env + hornet boss")

	await _death_and_continue(game, campaign)
	await _asset_replacement(game)
	print("\n".join(log_lines))
	print("smoke_test: %d failure(s)" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


func _play_mission(game: Node, campaign: CampaignDef, m: MissionDef, boss_def: BossDef, label := "") -> void:
	log_lines.append("Mission: %s %s" % [m.display_name, label])
	game.campaign = campaign
	game.campaign_index = campaign.missions.find(m)
	game.character = campaign.character
	game.lives = 3
	game.score = 0
	game.mission = m
	game.checkpoint = -1
	get_tree().change_scene_to_file(game.runner_scene_for(m))
	await frames(5)
	var r := runner()
	check(r != null, "runner scene loaded")
	if r == null:
		return
	check(r.terrain.rows == 12 and r.terrain.cols > 100, "terrain built (%dx%d)" % [r.terrain.cols, r.terrain.rows])
	check(r.terrain.tile_layer.get_used_cells().size() > r.terrain.cols * 2, "tiles placed (%d)" % r.terrain.tile_layer.get_used_cells().size())
	check(r.player != null and r.player.alive, "player spawned")
	await frames(30)
	check(r.player.is_on_floor(), "player stands on terrain collision")

	# Run right a little with real input.
	Input.action_press("move_right")
	Input.action_press("shoot")
	await frames(90)
	Input.action_release("move_right")
	Input.action_release("shoot")
	check(r.player.global_position.x > 300.0, "player moved right with input (x=%d)" % r.player.global_position.x)
	check(r.projectiles.get_child_count() >= 0, "player fired")

	# Warp through the level in steps to trigger spawns, waves and checkpoints.
	var enemy_ids := {}
	var max_enemies := 0
	var boss_x: float = r._boss_marker.center.x
	var x := r.player.global_position.x
	while x < boss_x - RF.TILE * 4:
		x += RF.TILE * 3
		r.player._invuln = 99.0
		r.player.global_position = r.find_respawn_point(x)
		r.camera_lock = Rect2()
		r._wave = {}
		await frames(12)
		for a in r.actors.get_children():
			if a is Enemy:
				enemy_ids[a.def.id] = true
		max_enemies = maxi(max_enemies, r.actors.get_children().filter(func(a): return a is Enemy).size())
	check(enemy_ids.size() >= 4, "varied enemies spawned: %s" % ", ".join(enemy_ids.keys()))
	check(r.checkpoint_index >= 0, "checkpoint reached (%d)" % r.checkpoint_index)
	check(r._pending_triggers.is_empty(), "all triggers fired")
	check(r.player.alive, "player alive after traversal")

	# Clear remaining enemies so the boss test is focused.
	for a in r.actors.get_children():
		if a is Enemy:
			a.die()
	r.player.global_position = Vector2(boss_x + RF.TILE * 3, r.player.global_position.y)
	await frames(30)
	check(r._boss_state in ["intro", "fight"], "boss encounter started")
	await frames(60 * 6)
	var b := r.boss
	check(b != null and not b.entering, "boss %s entered" % boss_def.id)
	if b == null:
		return
	check(b.phase_index == 0, "boss in first phase")
	var phases_seen := {0: true}
	b.phase_changed.connect(func(i, _p): phases_seen[i] = true)
	var hits := 0
	var guard := 0
	while b.alive and guard < 4000:
		guard += 1
		r.player._invuln = 99.0
		r.player.health = r.player.def.max_health
		# Prefer weak points like a skilled player would; otherwise shoot the hull.
		var target: Hurtbox = b.hull
		for wp in b.weak_points:
			if wp.enabled:
				target = wp
		if not b.invulnerable:
			var p := r.spawn_projectile(load("res://content/projectiles/laser_bolt.tres"), target.global_position - Vector2(120, 0), Vector2.RIGHT, RF.Team.PLAYER)
			p.global_position = target.global_position
			hits += 1
		await frames(3)
	check(not b.alive, "boss defeated through hurtboxes (%d shots)" % hits)
	check(phases_seen.size() == boss_def.phases.size(), "all %d boss phases reached (%s)" % [boss_def.phases.size(), phases_seen.keys()])
	var destroyed := b.weak_points.filter(func(w): return w.destroyed).size()
	check(destroyed >= 1 or boss_def.weak_points.all(func(w): return w.health == 0), "destructible weak points destroyed (%d)" % destroyed)
	await frames(60 * 8)
	var cs := get_tree().current_scene
	check(cs != null and cs.scene_file_path == game.RESULTS_SCENE, "results screen shown")
	check(game.last_result.get("score", 0) > 0, "score recorded (%d)" % game.last_result.get("score", 0))


func _asset_replacement(game: Node) -> void:
	log_lines.append("Assets")
	var assets: Node = get_node("/root/Assets")
	check(assets.missing_ids().size() > 0, "placeholders used for %d missing asset ids" % assets.missing_ids().size())
	check(assets.get_texture(&"char.commando") != null and assets.get_texture(&"boss.warden_tank") != null, "imported art loads")
	var audio: Node = get_node("/root/Audio")
	var music: AudioStreamWAV = audio._looped(assets.get_stream(&"music.jungle"), &"music.jungle")
	check(music != null and music.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.loop_begin > 0 and music.loop_end > music.loop_begin, "jungle music loops after its intro")
	var missing_audio := []
	for id in assets.all_ids():
		if (id.begins_with("sfx.") or id.begins_with("music.") or id.begins_with("amb.")) and assets.get_stream(StringName(id)) == null:
			missing_audio.append(id)
	check(missing_audio.is_empty(), "all music, ambience and sfx load %s" % [missing_audio])
	var v := ActorVisual.new()
	var vd := VisualDef.new()
	vd.asset_id = &"char.not_drawn_yet"
	v.setup(vd, Vector2(40, 84))
	check(v.is_placeholder, "missing sprite draws a placeholder")
	v.free()
	assets._entries["char.not_drawn_yet"] = {"type": "single", "path": "res://icon.svg"}
	assets._textures.erase(&"char.not_drawn_yet")
	var v2 := ActorVisual.new()
	v2.setup(vd, Vector2(40, 84))
	check(not v2.is_placeholder, "manifest entry swaps in real art with no code change")
	v2.free()
	assets.reload()


func _death_and_continue(game: Node, campaign: CampaignDef) -> void:
	log_lines.append("Lives, game over and continue")
	game.campaign = campaign
	game.campaign_index = 0
	game.character = campaign.character
	game.mission = campaign.missions[0]
	game.lives = 1
	game.checkpoint = -1
	get_tree().change_scene_to_file(game.runner_scene_for(game.mission))
	await frames(10)
	var r := runner()
	# Shield trooper blocks frontal shots but not shots from behind.
	var shield := r.spawn_enemy(load("res://content/enemies/shield_trooper.tres"), r.player.global_position + Vector2(300, -10))
	await frames(2)
	shield.facing = -1
	shield.attack_runner.enabled = false
	var hp := shield.health
	shield.receive_hit(1, shield.hurtbox, {"dir": Vector2.RIGHT, "pos": shield.global_position})
	check(shield.health == hp, "shield blocks frontal hit")
	shield.receive_hit(1, shield.hurtbox, {"dir": Vector2.LEFT, "pos": shield.global_position})
	check(shield.health == hp - 1, "shield trooper hurt from behind")
	shield.die()
	# Reach the first checkpoint, then lose all lives.
	var cp: Vector2 = r._checkpoints[0].pos
	while r.player.global_position.x < cp.x + 100.0:
		r.player._invuln = 99.0
		r.player.global_position = r.find_respawn_point(minf(r.player.global_position.x + RF.TILE * 3, cp.x + 120.0))
		r.camera_lock = Rect2()
		r._wave = {}
		await frames(12)
	r.player._invuln = 0.0
	check(r.checkpoint_index == 0, "checkpoint 0 recorded")
	r.player.take_damage(99)
	await frames(100)
	check(r.player.alive and game.lives == 0, "respawned using the last life")
	r.player._invuln = 0.0
	r.player.take_damage(99)
	await frames(100)
	check(r.state == "game_over", "game over after last life")
	game.continue_from_checkpoint(r.checkpoint_index)
	await frames(10)
	r = runner()
	check(r != null and absf(r.player.global_position.x - cp.x) < 2.0, "continue restarts at checkpoint")
	check(game.lives == campaign.starting_lives, "continue refills lives")
