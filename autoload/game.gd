extends Node
## Campaign and mission flow: which mission is running, lives, score,
## checkpoints and scene changes. Missions pick their runner scene by format.

const DEFAULT_CAMPAIGN := "res://content/campaigns/main_campaign.tres"
const TITLE_SCENE := "res://core/ui/title_screen.tscn"
const BRIEFING_SCENE := "res://core/ui/briefing_screen.tscn"
const RESULTS_SCENE := "res://core/ui/results_screen.tscn"
## Runner scene per MissionDef.format. Add an entry when a new format exists.
const FORMAT_RUNNERS := {
	"horizontal": "res://core/mission/horizontal_mission.tscn",
}

var campaign: CampaignDef
var campaign_index := -1
var mission: MissionDef
var character: CharacterDef
var lives := 3
var score := 0
## Checkpoint index the next mission load starts from (-1 = mission start).
var checkpoint := -1
var last_result := {}
var campaign_complete := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()


func load_campaign() -> CampaignDef:
	return load(DEFAULT_CAMPAIGN) as CampaignDef


func start_campaign(c: CampaignDef = null) -> void:
	campaign = c if c else load_campaign()
	character = campaign.character
	lives = campaign.starting_lives
	score = 0
	campaign_complete = false
	campaign_index = 0
	_open_mission(campaign.missions[0])


## Play one mission outside the campaign order (mission select).
func start_single_mission(m: MissionDef) -> void:
	if campaign == null:
		campaign = load_campaign()
	character = campaign.character
	lives = campaign.starting_lives
	score = 0
	campaign_complete = false
	campaign_index = campaign.missions.find(m)
	_open_mission(m)


func _open_mission(m: MissionDef) -> void:
	mission = m
	checkpoint = -1
	get_tree().paused = false
	get_tree().change_scene_to_file(BRIEFING_SCENE)


func runner_scene_for(m: MissionDef) -> String:
	if m.runner_scene:
		return m.runner_scene.resource_path
	return FORMAT_RUNNERS.get(m.format, "")


## Called by the briefing screen.
func launch_mission() -> void:
	var path := runner_scene_for(mission)
	if path == "":
		push_error("No runner for mission format '%s' yet." % mission.format)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func mission_completed(result: Dictionary) -> void:
	last_result = result
	score = result.get("score", score)
	get_tree().paused = false
	get_tree().change_scene_to_file(RESULTS_SCENE)


func has_next_mission() -> bool:
	return campaign and campaign_index >= 0 and campaign_index + 1 < campaign.missions.size()


func next_mission() -> void:
	if has_next_mission():
		campaign_index += 1
		_open_mission(campaign.missions[campaign_index])
	else:
		campaign_complete = true
		to_title()


## Continue after game over: same mission, from the last checkpoint reached.
func continue_from_checkpoint(cp: int) -> void:
	lives = campaign.starting_lives if campaign else 3
	score = 0
	checkpoint = cp
	get_tree().paused = false
	get_tree().reload_current_scene()


func to_title() -> void:
	get_tree().paused = false
	Audio.stop_all()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _register_inputs() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT, JOY_BUTTON_DPAD_LEFT],
		"move_right": [KEY_D, KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT],
		"move_up": [KEY_W, KEY_UP, JOY_BUTTON_DPAD_UP],
		"move_down": [KEY_S, KEY_DOWN, JOY_BUTTON_DPAD_DOWN],
		"jump": [KEY_SPACE, KEY_K, KEY_Z, JOY_BUTTON_A],
		"shoot": [KEY_J, KEY_X, JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER],
		"pause": [KEY_ESCAPE, KEY_P, JOY_BUTTON_START],
		"toggle_labels": [KEY_F3],
		"toggle_fullscreen": [KEY_F11],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for code in map[action]:
			var ev: InputEvent
			# Joypad button ids are all below KEY_SPACE (32).
			if code >= KEY_SPACE:
				ev = InputEventKey.new()
				ev.physical_keycode = code
			else:
				ev = InputEventJoypadButton.new()
				ev.button_index = code
			InputMap.action_add_event(action, ev)
	for pair in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = pair[1]
		m.axis_value = pair[2]
		InputMap.action_add_event(pair[0], m)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_labels"):
		Assets.show_placeholder_labels = not Assets.show_placeholder_labels
	var alt_enter: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and event.alt_pressed
	if event.is_action_pressed("toggle_fullscreen") or alt_enter:
		toggle_fullscreen()


## Fullscreen renders at the display's native resolution (e.g. 3840x2160 on a
## 4K TV); the 1280x720 logical view is scaled up with canvas_items stretch.
func toggle_fullscreen() -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
