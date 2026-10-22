class_name HorizontalMission
extends MissionRunner
## Side-scrolling mission: the camera leads the player to the right and never
## scrolls back, like classic run-and-guns.

const LOOK_AHEAD := 140.0

var _max_x := 0.0
var _look := 0.0


func _update_camera(delta: float) -> void:
	if camera_lock.has_area():
		cam_center = cam_center.lerp(camera_lock.get_center(), clampf(5.0 * delta, 0.0, 1.0))
	else:
		_look = lerpf(_look, player.facing * LOOK_AHEAD, clampf(2.5 * delta, 0.0, 1.0))
		var goal := Vector2(player.global_position.x + _look, player.global_position.y - 90.0)
		var c := cam_center.lerp(goal, clampf(6.0 * delta, 0.0, 1.0))
		c.x = maxf(c.x, _max_x)
		cam_center = _clamp_camera(c)
		_max_x = cam_center.x
	_apply_camera(delta)


func _build_camera() -> void:
	super()
	_max_x = cam_center.x
