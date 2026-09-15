extends Node2D
@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var player: AnimatedSprite2D = $Player
@onready var hp_label: Label = $CanvasLayer/HPLabel
@onready var inventory_label: Label = $CanvasLayer/InventoryLabel

const EnemyScene = preload("res://scene/enemy.tscn")

@export var slime_data: EnemyData = preload("res://data/enemies/slime_data.tres")
@export var goblin_data: EnemyData = preload("res://data/enemies/goblin_data.tres")
@export var potion_data: ItemData = preload("res://data/items/potion_data.tres")

@export var current_map_path: String = "res://data/maps/map_01.txt"

const TILE_SIZE = 32
enum TileType { FLOOR = 0, WALL = 1 }

var map_layout: Array[String] = []

var MAP_WIDTH: int = 0
var MAP_HEIGHT: int = 0

var map_data: Array = []
var player_grid_pos: Vector2i = Vector2i(2, 2)

var enemies: Array[Enemy] = []
var enemy_spawn_points: Array = []

var item_spawn_points: Array = []
var items_on_ground: Dictionary = {}
var player_inventory: Array[ItemData] = []

var is_moving: bool = false
var move_tween: Tween

var player_hp: int = 5
var player_max_hp: int = 5
var is_game_over: bool = false

func _ready() -> void:
	initialize_map()
	draw_map()
	update_player_position_visual()
	spawn_enemies()
	place_items()
	update_hp_label()
	update_inventory_label()

func load_map_layout(path: String) -> Array[String]:
	var lines: Array[String] = []
	var file = FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var line = file.get_line()
		if line != "":
			lines.append(line)
	file.close()
	return lines

func initialize_map() -> void:
	map_layout = load_map_layout(current_map_path)

	map_data.clear()
	enemy_spawn_points.clear()
	item_spawn_points.clear()

	MAP_HEIGHT = map_layout.size()
	MAP_WIDTH = map_layout[0].length()

	for x in range(MAP_WIDTH):
		map_data.append([])
		for y in range(MAP_HEIGHT):
			map_data[x].append(TileType.FLOOR)

	for y in range(MAP_HEIGHT):
		var row = map_layout[y]
		for x in range(MAP_WIDTH):
			var symbol = row[x]
			match symbol:
				"#":
					map_data[x][y] = TileType.WALL
				"S":
					map_data[x][y] = TileType.FLOOR
					enemy_spawn_points.append({"pos": Vector2i(x, y), "data": slime_data})
				"G":
					map_data[x][y] = TileType.FLOOR
					enemy_spawn_points.append({"pos": Vector2i(x, y), "data": goblin_data})
				"I":
					map_data[x][y] = TileType.FLOOR
					item_spawn_points.append({"pos": Vector2i(x, y), "data": potion_data})
				_:
					map_data[x][y] = TileType.FLOOR

func draw_map() -> void:
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var coords = Vector2i(x, y)
			if map_data[x][y] == TileType.WALL:
				tile_map_layer.set_cell(coords, 0, Vector2i(0, 0))
			else:
				tile_map_layer.set_cell(coords, 0, Vector2i(0, 1))

func spawn_enemies() -> void:
	for entry in enemy_spawn_points:
		var e: Enemy = EnemyScene.instantiate()
		add_child(e)
		e.setup(entry.data)
		e.set_grid_pos_immediate(entry.pos)
		enemies.append(e)

# ▼追加：マップ上のアイテム初期配置を反映
func place_items() -> void:
	items_on_ground.clear()
	for entry in item_spawn_points:
		items_on_ground[entry.pos] = entry.data

func get_enemy_at(pos: Vector2i) -> Enemy:
	for e in enemies:
		if e.grid_pos == pos:
			return e
	return null

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return

	var direction = Vector2i.ZERO
	if event.is_action_pressed("ui_right"): direction = Vector2i.RIGHT
	elif event.is_action_pressed("ui_left"): direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_down"): direction = Vector2i.DOWN
	elif event.is_action_pressed("ui_up"): direction = Vector2i.UP
	if direction != Vector2i.ZERO:
		try_move_player(direction)

func try_move_player(direction: Vector2i) -> void:
	if is_moving:
		return

	if direction.x > 0:
		player.flip_h = false
	elif direction.x < 0:
		player.flip_h = true

	var target_pos = player_grid_pos + direction

	if target_pos.x >= 0 and target_pos.x < MAP_WIDTH and target_pos.y >= 0 and target_pos.y < MAP_HEIGHT:
		if map_data[target_pos.x][target_pos.y] == TileType.WALL:
			print("壁にぶつかりました（データ上で判定）")
			return

		var target_enemy = get_enemy_at(target_pos)
		if target_enemy:
			attack_enemy(target_enemy)
			return

		player_grid_pos = target_pos
		update_player_position_visual()

		# ▼追加：移動先にアイテムがあれば拾う
		if items_on_ground.has(player_grid_pos):
			pick_up_item(player_grid_pos)

		call_enemy_turn()

func attack_enemy(target_enemy: Enemy) -> void:
	var died = target_enemy.take_damage(1)
	print("敵に攻撃！ 残りHP: ", target_enemy.hp)

	if died:
		print("敵を倒した！")
		enemies.erase(target_enemy)
		target_enemy.queue_free()

	call_enemy_turn()

# ▼追加：アイテムを拾う処理
func pick_up_item(pos: Vector2i) -> void:
	var item: ItemData = items_on_ground[pos]
	player_inventory.append(item)
	items_on_ground.erase(pos)
	print("拾った: ", item.display_name)
	update_inventory_label()

func update_player_position_visual() -> void:
	var target_screen_pos = Vector2(player_grid_pos * TILE_SIZE) + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	is_moving = true

	player.play("walk")

	if move_tween:
		move_tween.kill()
	move_tween = create_tween()
	move_tween.tween_property(player, "position", target_screen_pos, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.finished.connect(func():
		is_moving = false
		player.play("default")
	)

func call_enemy_turn() -> void:
	for e in enemies:
		move_enemy_toward_player(e)
		if is_game_over:
			return

func move_enemy_toward_player(e: Enemy) -> void:
	match e.data.move_pattern:
		"stay":
			var diff = player_grid_pos - e.grid_pos
			if abs(diff.x) + abs(diff.y) == 1:
				player_take_damage(1)
			return
		"chase", _:
			pass

	var diff = player_grid_pos - e.grid_pos

	var move_dir = Vector2i.ZERO
	if abs(diff.x) > abs(diff.y):
		move_dir = Vector2i(sign(diff.x), 0)
	elif diff.y != 0:
		move_dir = Vector2i(0, sign(diff.y))
	elif diff.x != 0:
		move_dir = Vector2i(sign(diff.x), 0)

	if move_dir == Vector2i.ZERO:
		return

	var target_pos = e.grid_pos + move_dir

	if target_pos.x < 0 or target_pos.x >= MAP_WIDTH or target_pos.y < 0 or target_pos.y >= MAP_HEIGHT:
		return
	if map_data[target_pos.x][target_pos.y] == TileType.WALL:
		return

	if target_pos == player_grid_pos:
		player_take_damage(1)
		return

	if get_enemy_at(target_pos) != null:
		return

	e.move_to(target_pos)

func player_take_damage(amount: int) -> void:
	player_hp -= amount
	print("プレイヤーが攻撃を受けた！ 残りHP: ", player_hp)
	update_hp_label()

	if player_hp <= 0:
		game_over()

func update_hp_label() -> void:
	hp_label.text = "HP: %d / %d" % [player_hp, player_max_hp]

# ▼追加：インベントリ表示の更新
func update_inventory_label() -> void:
	if player_inventory.is_empty():
		inventory_label.text = "持ち物: なし"
		return
	var names: Array[String] = []
	for item in player_inventory:
		names.append(item.display_name)
	inventory_label.text = "持ち物: " + ", ".join(names)

func game_over() -> void:
	is_game_over = true
	print("ゲームオーバー...")
	hp_label.text = "GAME OVER"
