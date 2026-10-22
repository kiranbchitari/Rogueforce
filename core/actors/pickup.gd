class_name Pickup
extends Node2D
## A floating or dropped item. Applies its PickupDef when the player touches it.

var def: PickupDef
var runner: MissionRunner
var velocity := Vector2.ZERO
var falling := false
var _t := 0.0
var _visual: ActorVisual
var _life := -1.0


func setup(d: PickupDef, r: MissionRunner, dropped := false) -> void:
	def = d
	runner = r
	falling = dropped
	if dropped:
		velocity = Vector2(randf_range(-60, 60), -420)
		_life = 12.0
	_visual = ActorVisual.new()
	add_child(_visual)
	var vd := d.visual
	if vd == null:
		vd = VisualDef.new()
		vd.placeholder_shape = "capsule"
		vd.placeholder_color = Color(0.85, 0.2, 0.2)
	_visual.setup(vd, Vector2(48, 32))
	_visual.label_text = d.label
	z_index = 6


func _physics_process(delta: float) -> void:
	_t += delta
	if falling:
		velocity.y += RF.GRAVITY * 0.6 * delta
		position += velocity * delta
		var gy := runner.ground_y_at(global_position.x, global_position.y - 20.0)
		if velocity.y > 0.0 and global_position.y + 18.0 >= gy:
			global_position.y = gy - 18.0
			falling = false
	else:
		_visual.position.y = sin(_t * 3.0) * 4.0
	if _life > 0.0:
		_life -= delta
		_visual.visible = _life > 3.0 or fmod(_life, 0.25) > 0.1
		if _life <= 0.0:
			queue_free()
			return
	var p := runner.player
	if p and p.alive and p.get_hit_rect().grow(8.0).intersects(Rect2(global_position - Vector2(24, 18), Vector2(48, 36))):
		_apply(p)


func _apply(p: Player) -> void:
	match def.kind:
		"weapon":
			if def.weapon:
				p.set_weapon(def.weapon)
		"health":
			p.heal(def.amount)
		"life":
			Game.lives += def.amount
			runner.hud.refresh()
		"score":
			runner.add_score(def.amount)
	runner.hud.show_message(def.display_name.to_upper(), 1.2)
	Audio.play_sfx(&"sfx.pickup", global_position)
	queue_free()
