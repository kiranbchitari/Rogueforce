class_name WeakPoint
extends Hurtbox
## A targetable boss part. Highlighted while vulnerable, greyed while armoured,
## scorched once destroyed.

var def: WeakPointDef
var boss: Boss
var hp := 0.0
var destroyed := false
var visual: ActorVisual
var _t := 0.0


func setup(d: WeakPointDef, b: Boss, r: MissionRunner) -> void:
	def = d
	boss = b
	runner = r
	size = d.size
	team = RF.Team.ENEMY
	priority = 10
	damage_multiplier = d.damage_multiplier
	receiver = self
	hp = d.health
	position = d.offset
	if d.visual:
		visual = ActorVisual.new()
		add_child(visual)
		visual.setup(d.visual, d.size)


func set_phase(phase_name: String) -> void:
	enabled = not destroyed and (def.active_phases.is_empty() or phase_name in def.active_phases)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	position = Vector2(def.offset.x * -boss.facing, def.offset.y)
	if visual:
		visual.facing = boss.facing
		visual.visible = not destroyed
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	var boss_has_art := not boss.visual.is_placeholder
	if destroyed:
		draw_rect(r, Color(0.1, 0.08, 0.06, 0.55 if boss_has_art else 0.85))
		draw_rect(r, Color(0.3, 0.2, 0.1), false, 2.0)
		return
	if not visual and not boss_has_art:
		draw_rect(r, def.visual.placeholder_color if def.visual else Color(0.85, 0.55, 0.1))
	elif not visual and enabled and boss.alive:
		draw_rect(r, Color(1.0, 0.3, 0.1, 0.12 + 0.1 * sin(_t * 8.0)))
	if enabled and boss.alive:
		var pulse := 0.5 + 0.5 * sin(_t * 8.0)
		draw_rect(r.grow(3.0 + pulse * 3.0), Color(1.0, 0.85, 0.2, 0.5 + pulse * 0.5), false, 3.0)
		if def.health > 0:
			var f := clampf(hp / float(def.health), 0.0, 1.0)
			draw_rect(Rect2(r.position + Vector2(0, -10), Vector2(r.size.x, 5)), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(r.position + Vector2(0, -10), Vector2(r.size.x * f, 5)), Color(1, 0.8, 0.2))
	elif not boss_has_art:
		draw_rect(r, Color(0.5, 0.5, 0.55, 0.6), false, 2.0)


func receive_hit(amount: float, _hb: Hurtbox, info: Dictionary) -> bool:
	if destroyed or not boss.alive:
		return false
	if boss.invulnerable:
		runner.spawn_ping(info.get("pos", global_position))
		return true
	if def.health > 0:
		hp -= amount / maxf(damage_multiplier, 0.01)
		if hp <= 0.0:
			_destroy()
	boss.receive_hit(amount, self, info)
	return true


func _destroy() -> void:
	destroyed = true
	enabled = false
	runner.spawn_explosion(global_position, 1.6)
	runner.shake(9.0)
	runner.hud.show_message("%s DESTROYED" % (def.display_name if def.display_name != "" else String(def.id)).to_upper(), 1.6)
	if def.destroy_damage > 0:
		boss.apply_damage(def.destroy_damage)
