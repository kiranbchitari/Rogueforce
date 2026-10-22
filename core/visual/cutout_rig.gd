class_name CutoutRig
extends Node2D
## Makes a single side-view character image walk. The image is split at the
## hips into a torso and two legs (found automatically from the gap between
## the legs); the legs swing in a stride synced to ground speed, the hips dip
## at full stride, and the torso leans toward the aim and kicks on recoil.



var _body: Node2D
var _torso: Node2D
var _front: Node2D
var _back: Node2D
var _frame_h := 1.0
# Hip-to-foot vectors of each leg in the rest pose (texture pixels).
var _back_foot := Vector2.ZERO
var _front_foot := Vector2.ZERO


## `region` is the frame inside `tex` (the whole texture for single images).
## `info` comes from analyze(). Coordinates are centred on the frame.
func build(tex: Texture2D, region: Rect2, info: Dictionary) -> void:
	var size := region.size
	var centre := size * 0.5
	var split: float = info.split_x
	var hip: float = info.hip_y
	var crotch: float = info.crotch_y
	_frame_h = size.y
	_back_foot = _clamp_leg(Vector2(info.back_foot_x - split, size.y - hip), -1.0)
	_front_foot = _clamp_leg(Vector2(info.front_foot_x - split, size.y - hip), 1.0)
	var pivot := Vector2(split, hip) - centre
	_body = Node2D.new()
	add_child(_body)
	_back = _piece(tex, Rect2(region.position + Vector2(0, hip), Vector2(split, size.y - hip)), Vector2(0, hip) - centre, pivot)
	_front = _piece(tex, Rect2(region.position + Vector2(split, hip), Vector2(size.x - split, size.y - hip)), Vector2(split, hip) - centre, pivot)
	var torso_h := minf(hip + size.y * 0.035, size.y)
	_torso = _piece(tex, Rect2(region.position, Vector2(size.x, torso_h)), -centre, pivot)


func _piece(tex: Texture2D, rect: Rect2, local_pos: Vector2, pivot: Vector2) -> Node2D:
	var joint := Node2D.new()
	joint.position = pivot
	_body.add_child(joint)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = rect
	var s := Sprite2D.new()
	s.texture = at
	s.centered = false
	s.position = local_pos - pivot
	joint.add_child(s)
	return joint


## Keeps each leg's splay angle in a range that animates well.
func _clamp_leg(v: Vector2, side: float) -> Vector2:
	var ang := clampf(absf(atan2(v.x, v.y)), 0.2, 0.5) * side
	return Vector2(sin(ang), cos(ang)) * v.length()


## run: 0 = standing, 1 = full stride. Over one cycle each leg swings from its
## drawn pose to the mirror of it and back, so the legs pass each other.
func pose(run: float, phase: float, lean: float, recoil: float, breathe: float) -> void:
	var t := (1.0 - cos(phase)) * 0.43 * run
	var back_rot := 2.0 * atan2(_back_foot.x, _back_foot.y) * t
	var front_rot := 2.0 * atan2(_front_foot.x, _front_foot.y) * t
	_back.rotation = back_rot
	_front.rotation = front_rot
	# Keep the lowest foot on the ground: the body rises as the legs pass.
	var rest := maxf(_back_foot.y, _front_foot.y)
	var lowest := maxf(_back_foot.rotated(back_rot).y, _front_foot.rotated(front_rot).y)
	_body.position.y = rest - lowest
	_torso.rotation = lean
	_torso.position.x = _front.position.x - recoil * _frame_h * 0.05
	_torso.position.y = _front.position.y - breathe * _frame_h * 0.01 * (1.0 - run)


## Finds the hips and the gap between the legs in a frame image.
static func analyze(img: Image) -> Dictionary:
	var used := img.get_used_rect()
	var w := img.get_width()
	var h := img.get_height()
	var min_gap := maxi(2, int(used.size.x * 0.03))
	var crotch := -1
	var gap_mid := used.get_center().x
	var saw_two := false
	var y := used.end.y - 1
	var stop := used.position.y + int(used.size.y * 0.45)
	while y > stop:
		var best_gap := 0
		var best_mid := 0.0
		var in_run := false
		var last_end := -1
		for x in range(used.position.x, used.end.x):
			var opaque := img.get_pixel(x, y).a > 0.4
			if opaque and not in_run:
				if last_end >= 0 and x - last_end > best_gap:
					best_gap = x - last_end
					best_mid = (x + last_end) * 0.5
				in_run = true
			elif not opaque and in_run:
				in_run = false
				last_end = x
		var centre_ok := best_mid > used.position.x + used.size.x * 0.15 and best_mid < used.end.x - used.size.x * 0.15
		if best_gap >= min_gap and centre_ok:
			saw_two = true
			gap_mid = best_mid
		elif saw_two:
			crotch = y
			break
		y -= 2
	if crotch < 0 or crotch > used.position.y + used.size.y * 0.92:
		crotch = used.position.y + int(used.size.y * 0.62)
		gap_mid = used.get_center().x
	var hip := crotch - used.size.y * 0.07
	# Feet: mean x of opaque pixels on each side of the split in the bottom rows.
	var sums := [0.0, 0.0]
	var counts := [0, 0]
	for fy in range(used.end.y - maxi(2, int(used.size.y * 0.06)), used.end.y):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, fy).a > 0.4:
				var side := 0 if x < gap_mid else 1
				sums[side] += x
				counts[side] += 1
	var back_x: float = sums[0] / counts[0] if counts[0] > 0 else gap_mid - used.size.x * 0.15
	var front_x: float = sums[1] / counts[1] if counts[1] > 0 else gap_mid + used.size.x * 0.15
	return {"split_x": gap_mid, "crotch_y": float(crotch), "hip_y": hip, "back_foot_x": back_x, "front_foot_x": front_x, "size": Vector2(w, h)}
