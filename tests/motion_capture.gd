extends Node
## Records the player running in mission 1 as a strip of frames to
## user://captures/motion.png (needs a window):
##   godot --path . --fixed-fps 60 res://tests/motion_capture.tscn


func _ready() -> void:
	get_tree().current_scene = null
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var game := get_node("/root/Game")
	var campaign: CampaignDef = game.load_campaign()
	game.campaign = campaign
	game.character = campaign.character
	game.mission = campaign.missions[0]
	get_tree().change_scene_to_file(game.runner_scene_for(game.mission))
	await _frames(20)
	var r := get_tree().current_scene as MissionRunner
	r.player._invuln = 99.0
	Input.action_press("move_right")
	await _frames(30)
	var strip: Image
	var vp := get_viewport()
	for i in 10:
		await _frames(4)
		var img := vp.get_texture().get_image()
		var k := img.get_width() / 1280.0
		var cam := r.camera_rect()
		var p := (r.player.global_position - cam.position) * k
		var box := Rect2i(int(p.x - 70 * k), int(p.y - 60 * k), int(140 * k), int(110 * k))
		if strip == null:
			strip = Image.create(box.size.x * 10, box.size.y, false, img.get_format())
		strip.blit_rect(img, box, Vector2i(i * box.size.x, 0))
	Input.action_release("move_right")
	DirAccess.make_dir_recursive_absolute("user://captures")
	strip.save_png("user://captures/motion.png")
	get_tree().quit()
