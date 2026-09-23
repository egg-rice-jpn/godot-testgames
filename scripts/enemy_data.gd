# enemy_data.gd
extends Resource
class_name EnemyData

@export var display_name: String = ""
@export var max_hp: int = 3
@export var sprite: Texture2D
@export_enum("chase", "stay", "wander") var move_pattern: String = "chase" # 今後の拡張用（今は使わないがデータ構造として先に置いておく）
