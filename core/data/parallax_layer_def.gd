class_name ParallaxLayerDef
extends Resource
## One background or foreground layer. Purely visual: it never creates
## collision. Terrain comes from the mission layout, not from this artwork.

@export var asset_id: StringName
## 0 = fixed to the screen, 1 = moves with the world, >1 = foreground.
@export var scroll_scale := 0.5
## Vertical offset from the bottom of the level, in pixels (negative = up).
@export var y_offset := 0.0
@export var foreground := false
@export var modulate := Color.WHITE
## Pixels per second of automatic drift (clouds, sandstorm haze).
@export var autoscroll := 0.0
## Display height in pixels. Artwork is scaled to this height and tiled sideways.
@export var height := 360
@export_group("Placeholder")
@export_enum("mountains", "hills", "jungle_canopy", "trees", "dunes", "mesa", "buildings", "clouds", "ice_peaks", "stalactites", "fog", "foliage") var placeholder_shape := "hills"
@export var placeholder_color := Color(0.3, 0.4, 0.3)
@export var placeholder_seed := 1
