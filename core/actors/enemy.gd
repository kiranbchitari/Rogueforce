class_name Enemy
extends Actor
## Generic enemy driven entirely by an EnemyDef.

var def: EnemyDef
var health := 1.0
var hurtbox: Hurtbox
var summoner: Actor


func setup(d: EnemyDef, r: MissionRunner) -> void:
	def = d
	runner = r
	_init_body(d.body_size, d.flying)
	contact_damage = d.contact_damage
	health = d.max_health
	visual = ActorVisual.new()
	add_child(visual)
	visual.setup(d.visual, d.body_size)
	visual.shadow = not d.flying
	hurtbox = Hurtbox.new()
	hurtbox.runner = r
	hurtbox.size = d.body_size
	hurtbox.team = RF.Team.ENEMY
	hurtbox.receiver = self
	add_child(hurtbox)
	attack_runner.configure(d.attacks, "auto", 0.0, d.first_attack_delay)


func _ready() -> void:
	home_position = global_position
	if target():
		face_toward(target().global_position.x)
	set_movement(def.movement)


func receive_hit(amount: float, _hb: Hurtbox, info: Dictionary) -> bool:
	if not alive:
		return false
	if def.frontal_shield and not attacking and signf(info.get("dir", Vector2.ZERO).x) == -facing:
		runner.spawn_ping(info.get("pos", global_position))
		return true
	health -= amount
	flash()
	if health <= 0.0:
		die()
	else:
		Audio.play_sfx(&"sfx.hit", global_position)
	return true


func die() -> void:
	if not alive:
		return
	alive = false
	attack_runner.cancel()
	hurtbox.enabled = false
	runner.on_enemy_killed(self)
	queue_free()
