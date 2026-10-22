extends ScreenBase
## Shows the mission briefing and launches the mission runner.


func _ready() -> void:
	var m := Game.mission
	var env := m.environment
	_build_frame(env.sky_top_color.darkened(0.7), env.ground_color.darkened(0.5))
	add_text("MISSION %d" % (Game.campaign_index + 1) if Game.campaign_index >= 0 else "SINGLE MISSION", 20, Color(0.7, 0.75, 0.7))
	add_text(m.display_name.to_upper(), 52, Color(0.95, 0.72, 0.25))
	if m.codename != "":
		add_text("Codename: %s" % m.codename, 20, Color(0.8, 0.8, 0.7))
	add_text("Theatre: %s" % env.display_name, 22, env.ground_top_color.lightened(0.4))
	add_gap(6)
	add_text(m.description, 20)
	var goal := "Destroy %s" % m.boss.display_name if m.completion == "defeat_boss" and m.boss else "Reach the extraction point"
	add_text("Objective: %s" % goal, 22, Color(1, 0.85, 0.5))
	add_text("Lives: %d      Score: %d" % [Game.lives, Game.score], 18, Color(0.7, 0.75, 0.7))
	add_gap(16)
	if Game.runner_scene_for(m) == "":
		add_text("The '%s' mission format has no runner yet." % m.format, 20, Color(1, 0.4, 0.3))
		add_button("Back", Game.to_title).grab_focus.call_deferred()
	else:
		add_button("Deploy", Game.launch_mission).grab_focus.call_deferred()
		add_button("Abort", Game.to_title)
