extends Sprite2D
class_name Enemy

const TILE_SIZE = 16

@export var data: EnemyData  # ▼追加：どの種類の敵かをここで受け取る

var grid_pos: Vector2i
var hp: int  # ▼変更：初期値は決め打ちせず、dataから設定する
var move_tween: Tween

func setup(enemy_data: EnemyData) -> void:  # ▼追加：スポーン時にデータを適用する関数
	data = enemy_data
	hp = data.max_hp
	if data.sprite:
		texture = data.sprite

func set_grid_pos_immediate(pos: Vector2i) -> void:
	grid_pos = pos
	position = Vector2(grid_pos * TILE_SIZE) + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)

func move_to(pos: Vector2i) -> void:
	grid_pos = pos
	var target_screen_pos = Vector2(grid_pos * TILE_SIZE) + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	if move_tween:
		move_tween.kill()
	move_tween = create_tween()
	move_tween.tween_property(self, "position", target_screen_pos, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func take_damage(amount: int) -> bool:
	hp -= amount
	return hp <= 0
