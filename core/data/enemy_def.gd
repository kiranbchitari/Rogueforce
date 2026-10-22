class_name EnemyDef
extends Resource
## One enemy type. Behaviour is composed from a movement resource and a list of
## attack resources, so a new enemy is usually just a new .tres file.

@export var id: StringName
@export var display_name := ""
@export_enum("infantry", "heavy", "sniper", "grenadier", "shielded", "drone", "helicopter", "vehicle", "turret", "robot", "creature", "elite", "object") var category := "infantry"
## Informational grouping (e.g. "iron_legion", "wildlife"). Never restricts where it appears.
@export var faction: StringName
@export var visual: VisualDef
@export var body_size := Vector2(40, 80)
@export var max_health := 2
@export var contact_damage := 1
@export var flying := false
@export var movement: MovementDef
@export var attacks: Array[AttackDef] = []
## Seconds before the first attack after the enemy appears on screen.
@export var first_attack_delay := 0.6
## Blocks player shots that hit it from the front.
@export var frontal_shield := false
@export var score := 100
@export var drop: PickupDef
@export_range(0.0, 1.0) var drop_chance := 0.0
## Blows up when destroyed (barrels, vehicles). Hurts the player and enemies.
@export var death_explosion_radius := 0.0
@export var death_explosion_damage := 0
## False for scenery like barrels: it does not hold ambush waves open.
@export var counts_as_enemy := true
