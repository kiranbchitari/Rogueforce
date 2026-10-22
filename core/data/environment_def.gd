class_name EnvironmentDef
extends Resource
## A world theme: everything about how a mission looks and sounds, plus the
## hazards and default enemy roster it suggests. It does not own gameplay
## geometry (that is the mission layout) and does not restrict which enemies a
## mission may use.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""

@export_group("Atmosphere")
@export var sky_top_color := Color(0.2, 0.4, 0.6)
@export var sky_bottom_color := Color(0.7, 0.8, 0.8)
## Multiplies the whole world (lighting / time of day).
@export var ambient_tint := Color.WHITE
## Screen-space haze drawn over the world; alpha 0 disables it.
@export var fog_color := Color(0, 0, 0, 0)
@export_enum("none", "rain", "snow", "sand", "embers", "ash", "spores") var weather := "none"
@export var weather_intensity := 1.0

@export_group("Backgrounds")
@export var parallax_layers: Array[ParallaxLayerDef] = []

@export_group("Terrain")
## A "tiles" entry in the asset manifest. Placeholder tiles use the colours below.
@export var tileset_asset_id: StringName
@export var ground_color := Color(0.35, 0.25, 0.15)
@export var ground_top_color := Color(0.3, 0.6, 0.2)
@export var platform_color := Color(0.5, 0.35, 0.2)
@export var block_color := Color(0.4, 0.4, 0.4)

@export_group("Decoration")
## Non-colliding props scattered on the ground and placed with * in layouts.
@export var props: Array[VisualDef] = []
@export_range(0.0, 1.0) var prop_density := 0.12

@export_group("Hazards")
## What ^ means in a layout.
@export var spike_hazard: HazardDef
## What ~ means in a layout.
@export var liquid_hazard: HazardDef

@export_group("Enemies")
## Used when a spawn entry does not name an enemy. Missions may mix freely.
@export var default_roster: Array[EnemyDef] = []

@export_group("Audio")
@export var music_id: StringName
@export var ambience_id: StringName
