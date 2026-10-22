class_name ChargeAttack
extends AttackDef
## Rams toward the player at high speed for active_time seconds.

@export var speed := 650.0


func prepare(actor: Actor, ctx: Dictionary) -> void:
	ctx.dir = signf(ctx.target.x - actor.global_position.x)
	if ctx.dir == 0.0:
		ctx.dir = float(actor.facing)


func begin(actor: Actor, ctx: Dictionary) -> void:
	actor.facing = int(ctx.dir)
	actor.motion_override = Vector2(speed * ctx.dir, 0.0)
	actor.runner.shake(4.0)


func end(actor: Actor, _ctx: Dictionary) -> void:
	actor.motion_override = null
