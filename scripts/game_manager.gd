extends Node2D
@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var player: AnimatedSprite2D = $Player
@onready var facing_arrow: Polygon2D = $Player/FacingArrow
@onready var hp_label: Label = $CanvasLayer/HPLabel
@onready var inventory_label: Label = $CanvasLayer/InventoryLabel

const EnemyScene = preload("res://scene/enemy.tscn")
const ItemScene = preload("res://scene/item.tscn")

@export var slime_data: EnemyData = preload("res://data/enemies/slime_data.tres")
@export var goblin_data: EnemyData = preload("res://data/enemies/goblin_data.tres")
@export var potion_data: ItemData = preload("res://data/items/potion_data.tres")

@export var current_map_path: String = "res://data/maps/map_01.txt"

const TILE_SIZE = 32
const DODGE_TURNS = 3
enum TileType { FLOOR = 0, WALL = 1 }

var map_layout: Array[String] = []

var MAP_WIDTH: int = 0
var MAP_HEIGHT: int = 0

var map_data: Array = []
var player_grid_pos: Vector2i = Vector2i(2, 2)
var player_facing: Vector2i = Vector2i.DOWN

var enemies: Array[Enemy] = []
var enemy_spawn_points: Array = []

var item_spawn_points: Array = []
var items_on_ground: Dictionary = {}
var item_visuals: Dictionary = {}
var player_inventory: Array[ItemData] = []

var is_moving: bool = false
var move_tween: Tween

var player_hp: int = 20  # TODO: テスト後に5へ戻す
var player_max_hp: int = 20  # TODO: テスト後に5へ戻す
var is_game_over: bool = false



func _ready() -> void:
	initialize_map()
	draw_map()
	update_player_position_visual()
	spawn_enemies()
	place_items()
	update_hp_label()
	update_inventory_label()
	update_facing_visual()

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

func place_items() -> void:
	items_on_ground.clear()
	item_visuals.clear()
	for entry in item_spawn_points:
		items_on_ground[entry.pos] = entry.data
		var iv: ItemVisual = ItemScene.instantiate()
		add_child(iv)
		iv.setup(entry.data)
		iv.set_grid_pos(entry.pos)
		item_visuals[entry.pos] = iv

func get_enemy_at(pos: Vector2i) -> Enemy:
	for e in enemies:
		if e.grid_pos == pos:
			return e
	return null

# 攻撃者が対象の背後にいるか（対象の向いている方向に攻撃者→対象の向きが一致すれば背後）
func is_backstab(attacker_pos: Vector2i, target_pos: Vector2i, target_facing: Vector2i) -> bool:
	var attack_dir = target_pos - attacker_pos
	return attack_dir == target_facing

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return

	var direction = Vector2i.ZERO
	if event.is_action_pressed("ui_right"): direction = Vector2i.RIGHT
	elif event.is_action_pressed("ui_left"): direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_down"): direction = Vector2i.DOWN
	elif event.is_action_pressed("ui_up"): direction = Vector2i.UP
	if direction != Vector2i.ZERO:
		if Input.is_key_pressed(KEY_SHIFT):
			try_dodge_roll(direction)
		else:
			try_move_player(direction)

func try_move_player(direction: Vector2i) -> void:
	if is_moving:
		return

	player_facing = direction
	update_facing_visual()

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

		if items_on_ground.has(player_grid_pos):
			pick_up_item(player_grid_pos)

		call_enemy_turn()

# ドッジロール：2マス先へ移動。間のマスは敵がいても飛び越えられる
func try_dodge_roll(direction: Vector2i) -> void:
	if is_moving:
		return

	var mid_pos = player_grid_pos + direction
	var land_pos = player_grid_pos + direction * 2

	if land_pos.x < 0 or land_pos.x >= MAP_WIDTH or land_pos.y < 0 or land_pos.y >= MAP_HEIGHT:
		print("そちらにはドッジロールできません")
		return
	if map_data[mid_pos.x][mid_pos.y] == TileType.WALL:
		print("壁があってドッジロールできません")
		return
	if map_data[land_pos.x][land_pos.y] == TileType.WALL:
		print("着地点が壁でドッジロールできません")
		return
	if get_enemy_at(land_pos) != null:
		print("着地点に敵がいてドッジロールできません")
		return

	# ロール開始時にプレイヤーへ隣接している敵を記録しておく
	var adjacent_enemies: Array[Enemy] = []
	for e in enemies:
		var diff = e.grid_pos - player_grid_pos
		if abs(diff.x) + abs(diff.y) == 1:
			adjacent_enemies.append(e)

	player_facing = direction
	update_facing_visual()
	if direction.x > 0:
		player.flip_h = false
	elif direction.x < 0:
		player.flip_h = true

	player_grid_pos = land_pos
	update_player_position_visual(0.25)

	if items_on_ground.has(player_grid_pos):
		pick_up_item(player_grid_pos)

	print("ドッジロール！")
	call_enemy_turn_dodge(adjacent_enemies)

func attack_enemy(target_enemy: Enemy) -> void:
	var damage = 1
	if is_backstab(player_grid_pos, target_enemy.grid_pos, target_enemy.facing):
		damage = 3
		print("背後を取った！ 大ダメージ！")

	var died = target_enemy.take_damage(damage)
	print("敵に攻撃！ 残りHP: ", target_enemy.hp)

	if died:
		print("敵を倒した！")
		enemies.erase(target_enemy)
		target_enemy.queue_free()

	call_enemy_turn()

func pick_up_item(pos: Vector2i) -> void:
	var item: ItemData = items_on_ground[pos]
	player_inventory.append(item)
	items_on_ground.erase(pos)

	if item_visuals.has(pos):
		item_visuals[pos].queue_free()
		item_visuals.erase(pos)

	print("拾った: ", item.display_name)
	update_inventory_label()

func update_player_position_visual(duration: float = 0.15) -> void:
	var target_screen_pos = Vector2(player_grid_pos * TILE_SIZE) + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	is_moving = true

	player.play("walk")

	if move_tween:
		move_tween.kill()
	move_tween = create_tween()
	move_tween.tween_property(player, "position", target_screen_pos, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.finished.connect(func():
		is_moving = false
		player.play("default")
	)

# 矢印は上向きの三角形を基準に回転させる
func update_facing_visual() -> void:
	var angle = 0.0
	if player_facing == Vector2i.UP:
		angle = 0.0
	elif player_facing == Vector2i.DOWN:
		angle = PI
	elif player_facing == Vector2i.RIGHT:
		angle = PI / 2
	elif player_facing == Vector2i.LEFT:
		angle = -PI / 2

	facing_arrow.rotation = angle

func call_enemy_turn() -> void:
	for e in enemies:
		enemy_act(e)
		if is_game_over:
			return

# ドッジロール用：隣接していた敵は1回、それ以外の敵は DODGE_TURNS 回行動する
func call_enemy_turn_dodge(adjacent_enemies: Array[Enemy]) -> void:
	for turn_index in range(DODGE_TURNS):
		for e in enemies:
			if turn_index > 0 and e in adjacent_enemies:
				continue
			enemy_act(e)
			if is_game_over:
				return

func enemy_act(e: Enemy) -> void:
	if e.is_winding_up:
		process_windup(e)
	else:
		move_enemy_toward_player(e)
		if is_game_over:
			return

# 攻撃の予備動作を開始する（今のプレイヤーの位置を狙う）
func start_enemy_attack(e: Enemy) -> void:
	e.begin_windup(player_grid_pos, e.data.attack_windup)

# 予備動作の進行。終わったら狙っていたマスを攻撃する
func process_windup(e: Enemy) -> void:
	e.windup_counter -= 1
	if e.windup_counter > 0:
		return

	var target = e.windup_target
	e.end_windup()
	if player_grid_pos == target:
		attack_player_from(e)
	else:
		print("敵の攻撃は空振りした！")

func move_enemy_toward_player(e: Enemy) -> void:
	match e.data.move_pattern:
		"stay":
			var diff = player_grid_pos - e.grid_pos
			if abs(diff.x) + abs(diff.y) == 1:
				start_enemy_attack(e)
			return
		"wander":
			wander_enemy(e)
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
		start_enemy_attack(e)
		return

	if get_enemy_at(target_pos) != null:
		return

	e.move_to(target_pos)

func wander_enemy(e: Enemy) -> void:
	var diff = player_grid_pos - e.grid_pos
	if abs(diff.x) + abs(diff.y) == 1:
		start_enemy_attack(e)
		return

	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	directions.shuffle()

	for dir in directions:
		var target_pos = e.grid_pos + dir
		if target_pos.x < 0 or target_pos.x >= MAP_WIDTH or target_pos.y < 0 or target_pos.y >= MAP_HEIGHT:
			continue
		if map_data[target_pos.x][target_pos.y] == TileType.WALL:
			continue
		if target_pos == player_grid_pos:
			continue
		if get_enemy_at(target_pos) != null:
			continue

		e.move_to(target_pos)
		return

func attack_player_from(e: Enemy) -> void:
	var damage = 1
	if is_backstab(e.grid_pos, player_grid_pos, player_facing):
		damage = 3
		print("敵に背後を取られた！ 大ダメージ！")
	player_take_damage(damage)

func player_take_damage(amount: int) -> void:
	player_hp -= amount
	print("プレイヤーが攻撃を受けた！ 残りHP: ", player_hp)
	update_hp_label()

	if player_hp <= 0:
		game_over()

func update_hp_label() -> void:
	hp_label.text = "HP: %d / %d" % [player_hp, player_max_hp]

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
