class_name AttackRunner
extends Node
## Plays an actor's attacks with telegraphs, bursts, recovery and cooldowns.
## Shared by every enemy and boss.

var actor: Actor
var attacks: Array[AttackDef] = []
## "auto": first ready attack whose range fits. "sequence"/"random" for bosses.
var order := "auto"
var pause_between := 0.0
var enabled := true
var busy := false

var _cooldowns := {}
var _pause := 0.0
var _index := 0
var _token := 0
var _current: AttackDef
var _ctx := {}


func configure(list: Array[AttackDef], attack_order := "auto", pause := 0.0, initial_delay := 0.0) -> void:
	cancel()
	attacks = list
	order = attack_order
	pause_between = pause
	_index = 0
	_cooldowns.clear()
	_pause = initial_delay


func _physics_process(delta: float) -> void:
	for a in _cooldowns:
		_cooldowns[a] -= delta
	if busy or not enabled or attacks.is_empty() or not actor.alive:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	if not actor.can_attack():
		return
	var choice := _choose()
	if choice:
		_run(choice)


func _choose() -> AttackDef:
	var dist := actor.distance_to_target()
	match order:
		"sequence":
			for i in attacks.size():
				var a := attacks[(_index + i) % attacks.size()]
				if _is_ready(a, dist):
					_index = (_index + i + 1) % attacks.size()
					return a
		"random":
			var candidates := attacks.filter(func(a): return _is_ready(a, dist))
			if not candidates.is_empty():
				return candidates.pick_random()
		_:
			for a in attacks:
				if _is_ready(a, dist):
					return a
	return null


func _is_ready(a: AttackDef, dist: float) -> bool:
	return _cooldowns.get(a, 0.0) <= 0.0 and dist >= a.min_range and dist <= a.max_range


func _wait(seconds: float, token: int) -> bool:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, false, true).timeout
	return token == _token and is_instance_valid(actor) and actor.alive


func _run(a: AttackDef) -> void:
	busy = true
	_current = a
	var token := _token
	actor.attacking = a.stop_moving
	var t := actor.target()
	_ctx = {"target": t.global_position if t else actor.global_position + Vector2(actor.facing * 300, 0)}
	actor.face_toward(_ctx.target.x)
	a.prepare(actor, _ctx)
	if a.telegraph != "none" and a.telegraph_time > 0.0:
		actor.runner.show_telegraph(a.telegraph, actor, a, _ctx, a.telegraph_time)
	if not await _wait(a.telegraph_time, token):
		return
	a.begin(actor, _ctx)
	for i in a.burst_count:
		a.fire(actor, _ctx, i)
		if a.projectile:
			actor.visual.kick()
		if a.sfx_id != &"":
			Audio.play_sfx(a.sfx_id, actor.global_position)
		if i < a.burst_count - 1 and not await _wait(a.burst_interval, token):
			return
	if not await _wait(a.active_time, token):
		return
	a.end(actor, _ctx)
	actor.attacking = false
	if not await _wait(a.recovery, token):
		return
	_cooldowns[a] = a.cooldown
	_pause = pause_between
	_current = null
	busy = false


## Abort whatever is running (stagger, phase change, death).
func cancel() -> void:
	_token += 1
	if _current and is_instance_valid(actor):
		_current.end(actor, _ctx)
		_cooldowns[_current] = _current.cooldown * 0.5
	_current = null
	busy = false
	if is_instance_valid(actor):
		actor.attacking = false
