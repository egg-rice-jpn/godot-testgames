extends Sprite2D
class_name Enemy

const TILE_SIZE = 32

@export var data: EnemyData

@onready var eye_icon: Sprite2D = $EyeIcon

var grid_pos: Vector2i
var hp: int
var move_tween: Tween

var facing: Vector2i = Vector2i.DOWN

# 予備動作（隙）の状態
var is_winding_up: bool = false
var windup_counter: int = 0
var windup_target: Vector2i = Vector2i.ZERO

func _ready() -> void:
	update_facing_visual()

func setup(enemy_data: EnemyData) -> void:
	data = enemy_data
	hp = data.max_hp
	if data.sprite:
		texture = data.sprite

func set_grid_pos_immediate(pos: Vector2i) -> void:
	grid_pos = pos
	position = Vector2(grid_pos * TILE_SIZE) + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)

func move_to(pos: Vector2i) -> void:
	var direction = pos - grid_pos
	if direction != Vector2i.ZERO:
		facing = direction
		update_facing_visual()

	grid_pos = pos
	var target_screen_pos = Vector2(grid_pos * TILE_SIZE) + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	if move_tween:
		move_tween.kill()
	move_tween = create_tween()
	move_tween.tween_property(self, "position", target_screen_pos, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# 予備動作の開始：狙うマスの方を向き、赤く光らせる
func begin_windup(target: Vector2i, turns: int) -> void:
	is_winding_up = true
	windup_counter = turns
	windup_target = target

	var dir = target - grid_pos
	if abs(dir.x) >= abs(dir.y):
		facing = Vector2i(sign(dir.x), 0)
	else:
		facing = Vector2i(0, sign(dir.y))
	update_facing_visual()
	modulate = Color(1.0, 0.4, 0.4)

func end_windup() -> void:
	is_winding_up = false
	modulate = Color(1, 1, 1)

# 左右は画像を反転、上下は目アイコンの位置で表現する
func update_facing_visual() -> void:
	if facing.x > 0:
		flip_h = false
	elif facing.x < 0:
		flip_h = true

	if facing == Vector2i.UP:
		eye_icon.position = Vector2(0, -10)
	elif facing == Vector2i.DOWN:
		eye_icon.position = Vector2(0, 10)
	else:
		eye_icon.position = Vector2(0, 0)

func take_damage(amount: int) -> bool:
	hp -= amount
	return hp <= 0
