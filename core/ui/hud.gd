class_name Hud
extends CanvasLayer
## In-mission HUD: lives, health, weapon, score, messages, boss bar, pause and
## game-over overlays. Built in code so it works with any mission runner.

var runner: MissionRunner
var _status: Label
var _score: Label
var _health: HBoxContainer
var _message: Label
var _banner: Label
var _boss_panel: Control
var _boss_name: Label
var _boss_bar: BossBar
var _overlay: PanelContainer
var _overlay_box: VBoxContainer
var _msg_tween: Tween


func bind(r: MissionRunner) -> void:
	runner = r
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The viewport is a fixed logical size (stretch mode canvas_items), so
	# absolute positions are used instead of anchors.
	var root := Control.new()
	root.size = RF.VIEW_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_status = _label(root, Vector2(24, 16), 22)
	_health = HBoxContainer.new()
	_health.position = Vector2(24, 50)
	_health.add_theme_constant_override("separation", 6)
	root.add_child(_health)
	_score = _label(root, Vector2(0, 16), 26)
	_score.position = Vector2(RF.VIEW_SIZE.x - 340, 16)
	_score.size = Vector2(316, 40)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_message = _label(root, Vector2.ZERO, 34)
	_message.position = Vector2(RF.VIEW_SIZE.x * 0.5 - 500, 150)
	_message.size = Vector2(1000, 100)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0

	_banner = _label(root, Vector2.ZERO, 64)
	_banner.position = RF.VIEW_SIZE * 0.5 - Vector2(600, 110)
	_banner.size = Vector2(1200, 220)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.visible = false

	_boss_panel = Control.new()
	_boss_panel.position = Vector2(RF.VIEW_SIZE.x * 0.5 - 420, RF.VIEW_SIZE.y - 78)
	_boss_panel.size = Vector2(840, 60)
	_boss_panel.visible = false
	root.add_child(_boss_panel)
	_boss_name = _label(_boss_panel, Vector2(0, -6), 20)
	_boss_bar = BossBar.new()
	_boss_bar.position = Vector2(0, 24)
	_boss_bar.size = Vector2(840, 22)
	_boss_panel.add_child(_boss_bar)

	_overlay = PanelContainer.new()
	_overlay.position = RF.VIEW_SIZE * 0.5 - Vector2(220, 150)
	_overlay.size = Vector2(440, 300)
	_overlay.visible = false
	root.add_child(_overlay)
	_overlay_box = VBoxContainer.new()
	_overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_box.add_theme_constant_override("separation", 14)
	_overlay.add_child(_overlay_box)

	r.player.health_changed.connect(func(_c, _m): refresh())
	r.player.weapon_changed.connect(func(_w): refresh())
	refresh()


func _label(parent: Control, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func refresh() -> void:
	if runner == null or runner.player == null:
		return
	var p := runner.player
	var wname: String = p.weapon.display_name if p.weapon else "-"
	_status.text = "LIVES x%d    %s" % [Game.lives, wname.to_upper()]
	if p.weapon:
		_status.add_theme_color_override("font_color", p.weapon.hud_color)
	_score.text = "SCORE %07d" % Game.score
	for c in _health.get_children():
		c.queue_free()
	for i in p.def.max_health:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(26, 14)
		pip.color = Color(0.2, 0.95, 0.35) if i < p.health else Color(0.25, 0.25, 0.25, 0.8)
		_health.add_child(pip)


func show_message(text: String, seconds := 1.5) -> void:
	_message.text = text
	if _msg_tween:
		_msg_tween.kill()
	_message.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(seconds)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.4)


func show_go() -> void:
	show_message("GO  >>>", 1.6)


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	_banner.add_theme_color_override("font_color", Color(1, 0.85, 0.25))


func show_warning(boss_def: BossDef) -> void:
	_banner.text = "WARNING\n%s" % boss_def.display_name.to_upper()
	_banner.add_theme_color_override("font_color", Color(1, 0.2, 0.15))
	_banner.visible = true
	var tw := create_tween().set_loops(5)
	tw.tween_property(_banner, "modulate:a", 0.2, 0.22)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.22)
	tw.finished.connect(func(): _banner.visible = false)


func show_boss(b: Boss) -> void:
	_boss_panel.visible = true
	_boss_name.text = "%s   %s" % [b.def.display_name.to_upper(), b.def.title.to_upper()]
	_boss_bar.setup(b.def)
	b.health_changed.connect(func(cur, mx): _boss_bar.set_value(cur / mx))
	b.phase_changed.connect(func(i, _p): _boss_bar.phase = i)


func hide_boss() -> void:
	_boss_panel.visible = false


func show_game_over() -> void:
	_show_overlay("GAME OVER", [
		["Continue from checkpoint", func(): Game.continue_from_checkpoint(runner.checkpoint_index)],
		["Quit to title", Game.to_title],
	])


func _show_overlay(title: String, buttons: Array) -> void:
	for c in _overlay_box.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	_overlay_box.add_child(t)
	var first: Button
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(320, 46)
		btn.pressed.connect(b[1])
		_overlay_box.add_child(btn)
		if first == null:
			first = btn
	_overlay.visible = true
	first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and runner.state == "playing":
		get_viewport().set_input_as_handled()
		if get_tree().paused:
			_resume()
		else:
			get_tree().paused = true
			_show_overlay("PAUSED", [
				["Resume", _resume],
				["Restart from checkpoint", func(): Game.continue_from_checkpoint(runner.checkpoint_index)],
				["Quit to title", Game.to_title],
			])


func _resume() -> void:
	_overlay.visible = false
	get_tree().paused = false
