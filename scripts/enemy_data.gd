extends Resource
class_name EnemyData

@export var display_name: String = ""
@export var max_hp: int = 3
@export var sprite: Texture2D
@export_enum("chase", "stay", "wander") var move_pattern: String = "chase"
@export var attack_windup: int = 1  # 攻撃前に何ターン隙を見せるか
