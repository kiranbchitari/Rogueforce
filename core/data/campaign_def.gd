class_name CampaignDef
extends Resource

@export var id: StringName
@export var display_name := ""
@export var missions: Array[MissionDef] = []
@export var character: CharacterDef
@export var starting_lives := 3
