class_name Projectile
extends Node2D
## Bullets, shells, grenades. Hits are resolved against the mission's hurtbox
## registry and terrain grid, so priorities (weak point over hull) are exact.

var def: ProjectileDef
var team := RF.Team.PLAYER
var velocity := Vector2.ZERO
var runner: MissionRunner
var _age := 0.0
var _hit := {}
var _sprite: Sprite2D


func setup(d: ProjectileDef, v: Vector2, t: int, r: MissionRunner) -> void:
	def = d
	velocity = v
	team = t
	runner = r
	rotation = v.angle()
	z_index = 8
	var tex := Assets.get_texture(d.asset_id)
	if tex:
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		var target_h := maxf(d.radius * 2.0, 8.0)
		_sprite.scale = Vector2.ONE * target_h / float(tex.get_height())
		add_child(_sprite)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > def.lifetime:
		queue_free()
		return
	velocity.y += def.gravity * delta
	var steps := 1 + int(velocity.length() * delta / 14.0)
	for s in steps:
		position += velocity * delta / float(steps)
		if _check_hits():
			return
	rotation = velocity.angle()
	if not runner.camera_rect().grow(320.0).has_point(global_position):
		queue_free()


func _check_hits() -> bool:
	if def.hits_world and runner.terrain.blocks_projectile(global_position, velocity.y > 0.0 and def.gravity > 0.0):
		_impact()
		return true
	var r := Rect2(global_position - Vector2.ONE * def.radius, Vector2.ONE * def.radius * 2.0)
	var best: Hurtbox
	for hb in runner.hurtboxes_against(team):
		if hb.enabled and not _hit.has(hb) and hb.get_rect().intersects(r):
			if best == null or hb.priority > best.priority:
				best = hb
	if best:
		_hit[best] = true
		var absorbed := best.take_hit(def.damage, {"dir": velocity.normalized(), "pos": global_position, "team": team})
		if absorbed and not def.pierce:
			_impact()
			return true
	return false


func _impact() -> void:
	if def.explode_radius > 0.0:
		runner.explode(global_position, def.explode_radius, def.explode_damage, team)
	else:
		runner.spawn_spark(global_position, def.color)
	queue_free()


func _draw() -> void:
	if _sprite:
		return
	if def.length > 0.0:
		draw_line(Vector2(-def.length, 0), Vector2.ZERO, Color(def.color, 0.5), def.radius * 1.4)
	draw_circle(Vector2.ZERO, def.radius, def.color)
	draw_circle(Vector2.ZERO, def.radius * 0.5, Color(1, 1, 1, 0.9))
