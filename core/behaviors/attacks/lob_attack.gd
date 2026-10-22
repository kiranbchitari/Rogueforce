class_name LobAttack
extends AttackDef
## Throws gravity projectiles in an arc that lands on the player (grenades,
## mortars). Impact points are chosen up front so the ground_marker telegraph
## shows exactly where they will land.

@export var count := 1
@export var scatter := 60.0
@export var flight_time := 0.9


func prepare(actor: Actor, ctx: Dictionary) -> void:
	var pts := PackedVector2Array()
	for i in count:
		var x: float = ctx.target.x + (randf_range(-scatter, scatter) if i > 0 or count > 1 else 0.0)
		pts.append(Vector2(x, actor.runner.ground_y_at(x, ctx.target.y - 40.0)))
	ctx.points = pts


func fire(actor: Actor, ctx: Dictionary, shot_index: int) -> void:
	if projectile == null:
		return
	var origin := muzzle_position(actor)
	var g := projectile.gravity
	for i in ctx.points.size():
		if burst_count > 1 and i != shot_index % ctx.points.size():
			continue
		var p: Vector2 = ctx.points[i]
		var v := Vector2((p.x - origin.x) / flight_time, (p.y - origin.y - 0.5 * g * flight_time * flight_time) / flight_time)
		actor.runner.spawn_projectile(projectile, origin, v, RF.Team.ENEMY, true)
