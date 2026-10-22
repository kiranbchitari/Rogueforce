class_name Hurtbox
extends Node2D
## A rectangle that projectiles and explosions can hit. Hits are forwarded to
## `receiver.receive_hit(amount, hurtbox, info)`. When several hurtboxes
## overlap a projectile, the highest priority wins (weak points over hulls).

var size := Vector2(32, 32)
var team := RF.Team.ENEMY
var priority := 0
var damage_multiplier := 1.0
var enabled := true
var receiver: Object
var runner: MissionRunner


func _enter_tree() -> void:
	if runner:
		runner.register_hurtbox(self)


func _exit_tree() -> void:
	if runner:
		runner.unregister_hurtbox(self)


func get_rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


## Returns true when the hit is absorbed (the projectile should stop).
func take_hit(amount: float, info: Dictionary) -> bool:
	if not enabled or receiver == null:
		return false
	return receiver.receive_hit(amount * damage_multiplier, self, info)
