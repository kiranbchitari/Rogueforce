class_name RadialBurstAttack
extends AttackDef
## A ring of projectiles; rotating each burst makes spirals.

@export var count := 12
@export var rotation_per_burst_deg := 10.0
## Limit the ring to an arc (degrees, centred on straight down). 360 = full ring.
@export var arc_deg := 360.0


func fire(actor: Actor, _ctx: Dictionary, shot_index: int) -> void:
	if projectile == null:
		return
	var origin := muzzle_position(actor)
	var start := PI * 0.5 - deg_to_rad(arc_deg) * 0.5 + deg_to_rad(rotation_per_burst_deg * shot_index)
	var step := deg_to_rad(arc_deg) / float(count if arc_deg >= 360.0 else maxi(count - 1, 1))
	for i in count:
		actor.runner.spawn_projectile(projectile, origin, Vector2.from_angle(start + step * i), RF.Team.ENEMY)
