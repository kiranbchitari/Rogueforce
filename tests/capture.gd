extends Node
## Renders screenshots of each mission at a few points along the layout (needs
## a window, not --headless):  godot --path . res://tests/capture.tscn
## Images go to user://captures/.

const POINTS := [0.0, 0.25, 0.45, 0.7]


func _ready() -> void:
	get_tree().current_scene = null
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var game := get_node("/root/Game")
	var campaign: CampaignDef = game.load_campaign()
	DirAccess.make_dir_recursive_absolute("user://captures")
	for m in campaign.missions:
		game.campaign = campaign
		game.character = campaign.character
		game.mission = m
		game.lives = 3
		get_tree().change_scene_to_file(game.runner_scene_for(m))
		await _frames(10)
		var r := get_tree().current_scene as MissionRunner
		for f in POINTS:
			var x: float = lerpf(200.0, r._boss_marker.center.x - 400.0, f)
			r.player._invuln = 99.0
			r.player.global_position = r.find_respawn_point(x)
			r.camera_lock = Rect2()
			await _frames(70)
			r.player._invuln = 0.0
			r.player.visual.visible = true
			Input.action_press("shoot")
			await _frames(8)
			Input.action_release("shoot")
			await _frames(2)
			_save("%s_%02d" % [m.id, int(f * 100)])
		r.player._invuln = 99.0
		r.player.global_position = Vector2(r._boss_marker.center.x + RF.TILE * 3, r.player.global_position.y)
		await _frames(60 * 6)
		_save("%s_boss" % m.id)
		await _frames(60 * 3)
		_save("%s_boss2" % m.id)
	get_tree().change_scene_to_file(game.TITLE_SCENE)
	await _frames(10)
	_save("title")
	get_tree().quit()


func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://captures/%s.png" % name)
	print("captured ", ProjectSettings.globalize_path("user://captures/%s.png" % name))
