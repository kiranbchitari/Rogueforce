extends ScreenBase
## Title, campaign start and mission select.


func _ready() -> void:
	_build_frame()
	Audio.play_music(&"music.title")
	_main_menu()


func _main_menu() -> void:
	clear()
	add_text("ROGUEFORCE", 84, Color(0.95, 0.72, 0.25))
	add_text("Multi-world run-and-gun", 22, Color(0.75, 0.8, 0.7))
	if Game.campaign_complete:
		add_text("Campaign complete. Final score %d" % Game.score, 22, Color(0.5, 1.0, 0.6))
	add_gap(24)
	var first := add_button("Start campaign", func(): Game.start_campaign())
	add_button("Mission select", _mission_select)
	add_button("Controls", _controls)
	add_button("Toggle fullscreen", Game.toggle_fullscreen)
	add_button("Quit", func(): get_tree().quit())
	first.grab_focus.call_deferred()


func _mission_select() -> void:
	clear()
	add_text("MISSION SELECT", 40, Color(0.95, 0.72, 0.25))
	var campaign := Game.load_campaign()
	var first: Button
	for m in campaign.missions:
		var label := "%s  -  %s  [%s]" % [m.display_name, m.environment.display_name if m.environment else "?", m.format]
		var b := add_button(label, func(): Game.start_single_mission(m))
		if first == null:
			first = b
	add_gap()
	add_button("Back", _main_menu)
	first.grab_focus.call_deferred()


func _controls() -> void:
	clear()
	add_text("CONTROLS", 40, Color(0.95, 0.72, 0.25))
	add_text("Move / aim: A D W S or arrow keys (8 directions; hold up to aim up, down to crouch)\n"
		+ "Jump: Space / K / Z      Shoot (hold): J / X\n"
		+ "Drop through platform: Down + Jump\n"
		+ "Pause: Esc / P      Fullscreen: F11 or Alt+Enter      Placeholder labels: F3\n"
		+ "Gamepad: stick or d-pad, A jump, X or RB shoot, Start pause", 20)
	add_gap()
	add_button("Back", _main_menu).grab_focus.call_deferred()
