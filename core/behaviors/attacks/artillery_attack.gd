class_name ArtilleryAttack
extends AttackDef
## Shells or bombs fall from above the screen onto marked spots around the
## player (mortar barrages, air strikes, falling rocks).

@export var count := 4
@export var spacing := 150.0
## Spread impacts evenly across the arena instead of around the player.
@export var cover_arena := false
@export var drop_speed := 700.0


func prepare(actor: Actor, ctx: Dictionary) -> void:
	var pts := PackedVector2Array()
	var view := actor.view_rect()
	for i in count:
		var x: float
		if cover_arena:
			x = view.position.x + view.size.x * (float(i) + 0.5) / float(count)
		else:
			x = ctx.target.x + (float(i) - (count - 1) * 0.5) * spacing + randf_range(-20.0, 20.0)
		x = clampf(x, view.position.x + 20.0, view.end.x - 20.0)
		pts.append(Vector2(x, actor.runner.ground_y_at(x, view.position.y)))
	ctx.points = pts


func fire(actor: Actor, ctx: Dictionary, shot_index: int) -> void:
	if projectile == null:
		return
	var top := actor.view_rect().position.y - 40.0
	for i in ctx.points.size():
		if burst_count > 1 and i % burst_count != shot_index:
			continue
		var p: Vector2 = ctx.points[i]
		actor.runner.spawn_projectile(projectile, Vector2(p.x, top), Vector2(0, drop_speed), RF.Team.ENEMY, true)
