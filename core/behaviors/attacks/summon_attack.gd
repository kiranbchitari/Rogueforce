class_name SummonAttack
extends AttackDef
## Calls in reinforcements next to the actor (drone bays, troop drops).

@export var enemies: Array[EnemyDef] = []
@export var count := 2
## No summon if this many of the actor's summons are still alive.
@export var max_alive := 3
@export var spawn_offset := Vector2(0, -40)


func fire(actor: Actor, _ctx: Dictionary, _shot_index: int) -> void:
	if enemies.is_empty() or actor.live_summons() >= max_alive:
		return
	for i in count:
		var def: EnemyDef = enemies[i % enemies.size()]
		var off := Vector2(spawn_offset.x * actor.facing + (i - (count - 1) * 0.5) * 70.0, spawn_offset.y)
		actor.runner.spawn_enemy(def, actor.global_position + off, actor)
