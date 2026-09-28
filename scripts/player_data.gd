extends Resource
class_name PlayerData

@export var max_hp: int = 5
@export var attack_damage: int = 1
@export var backstab_multiplier: int = 3  # 背後攻撃の倍率（プレイヤー・敵の両方に適用）
@export var dodge_turns: int = 3  # ドッジロール中、隣接していない敵が行動する回数
