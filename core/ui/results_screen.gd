extends ScreenBase
## Mission results and the way on to the next mission.


func _ready() -> void:
	_build_frame()
	var r := Game.last_result
	add_text("MISSION COMPLETE", 52, Color(0.95, 0.72, 0.25))
	add_text(r.get("mission", ""), 26)
	add_gap()
	add_text("Time  %s" % _fmt_time(r.get("time", 0.0)), 24)
	add_text("Enemies destroyed  %d" % r.get("kills", 0), 24)
	add_text("Time bonus  %d" % r.get("time_bonus", 0), 24)
	add_text("Score  %d" % r.get("score", 0), 30, Color(1, 0.9, 0.4))
	add_gap(18)
	if Game.has_next_mission():
		add_button("Next mission", Game.next_mission).grab_focus.call_deferred()
		add_button("Quit to title", Game.to_title)
	else:
		Game.campaign_complete = Game.campaign_index >= 0
		add_text("CAMPAIGN COMPLETE" if Game.campaign_complete else "", 28, Color(0.5, 1, 0.6))
		add_button("Return to title", Game.to_title).grab_focus.call_deferred()


func _fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
