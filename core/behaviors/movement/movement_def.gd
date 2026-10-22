class_name MovementDef
extends Resource
## Base class for reusable movement behaviours. The resource holds tuning
## only; anything that changes per actor goes in `state`, so one .tres can be
## shared by every enemy that uses it.
##
## To add a behaviour: extend this class, override tick(), and reference the
## new resource from an EnemyDef or BossPhaseDef. No core code changes.


func setup(_actor: Actor, _state: Dictionary) -> void:
	pass


## Set actor.velocity (and actor.facing). Gravity and move_and_slide() are
## applied by the actor afterwards.
func tick(_actor: Actor, _state: Dictionary, _delta: float) -> void:
	pass
