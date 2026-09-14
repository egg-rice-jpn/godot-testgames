# item_data.gd
extends Resource
class_name ItemData

@export var display_name: String = ""
@export var icon: Texture2D
@export var effect_type: String = "heal"
@export var effect_value: int = 1
