extends Node2D
## Renders each biped at six points of its stride to user://captures/rigs.png
## (needs a window):  godot --path . res://tests/rig_preview.tscn

const IDS := ["char.commando", "enemy.infantry", "enemy.heavy", "enemy.grenadier", "enemy.sniper", "enemy.shield_trooper"]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.35, 0.45, 0.4))
	for r in IDS.size():
		for c in 7:
			var vd := VisualDef.new()
			vd.asset_id = IDS[r]
			var v := ActorVisual.new()
			add_child(v)
			v.setup(vd, Vector2(84, 84))
			v.scale = Vector2.ONE * 1.3
			v.position = Vector2(90 + c * 160, 70 + r * 112)
			v.shadow = true
			v.set_process(false)
			v.play("run")
			if v._rig:
				v._rig.pose(0.0 if c == 0 else 1.0, (c - 1) * TAU / 6.0, 0.0, 0.0, 0.0)
	await get_tree().create_timer(0.5).timeout
	DirAccess.make_dir_recursive_absolute("user://captures")
	get_viewport().get_texture().get_image().save_png("user://captures/rigs.png")
	get_tree().quit()
