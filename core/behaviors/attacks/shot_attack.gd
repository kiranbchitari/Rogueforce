class_name ShotAttack
extends AttackDef
## Fires one or more projectiles: aimed shots, fans, machine-gun bursts,
## missiles, dropped bombs.

@export_enum("aimed", "facing", "fixed") var aim := "aimed"
## For "fixed": 0 = forward, 90 = straight down, -90 = up. Mirrors with facing.
@export var angle_deg := 0.0
@export var count := 1
@export var spread_deg := 0.0
@export var jitter_deg := 0.0
## Re-aim at the player for every shot of a burst instead of the telegraphed point.
@export var track_during_burst := false


func fire(actor: Actor, ctx: Dictionary, _shot_index: int) -> void:
	if projectile == null:
		return
	var origin := muzzle_position(actor)
	var target: Vector2 = ctx.target
	if track_during_burst and actor.target():
		target = actor.target().global_position
	var base := 0.0
	match aim:
		"aimed":
			base = (target - origin).angle()
		"facing":
			base = 0.0 if actor.facing > 0 else PI
		"fixed":
			base = deg_to_rad(angle_deg)
			if actor.facing < 0:
				base = PI - base
	for i in count:
		var a := base
		if count > 1:
			a += deg_to_rad(spread_deg) * (float(i) / float(count - 1) - 0.5)
		a += deg_to_rad(randf_range(-jitter_deg, jitter_deg))
		actor.runner.spawn_projectile(projectile, origin, Vector2.from_angle(a), RF.Team.ENEMY)
