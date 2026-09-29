extends Node2D
@onready var map: MapManager = $TileMapLayer   # 元の tile_map_layer の行と差し替え
@onready var player: AnimatedSprite2D = $Player
@onready var facing_arrow: Polygon2D = $Player/FacingArrow
@onready var hud: Hud = $CanvasLayer

const EnemyScene = preload("res://scene/enemy.tscn")
const ItemScene = preload("res://scene/item.tscn")

@export var slime_data: EnemyData = preload("res://data/enemies/slime_data.tres")
@export var goblin_data: EnemyData = preload("res://data/enemies/goblin_data.tres")
@export var potion_data: ItemData = preload("res://data/items/potion_data.tres")
@export var player_data: PlayerData



const TILE_SIZE = 32




var player_grid_pos: Vector2i = Vector2i(2, 2)
var player_facing: Vector2i = Vector2i.DOWN

var enemies: Array[Enemy] = []
var items_on_ground: Dictionary = {}
var item_visuals: Dictionary = {}
var player_inventory: Array[ItemData] = []

var is_moving: bool = false
var move_tween: Tween

var player_hp: int = 0
var is_game_over: bool = false



func _ready() -> void:
	if player_data == null:
		player_data = PlayerData.new()  # 未設定でも初期値で動くようにしておく
	player_hp = player_data.max_hp

	map.load_map()   # initialize_map() の代わり
	map.draw_map()   # draw_map() の代わり
	update_player_position_visual()
	spawn_enemies()
	place_items()
	update_hp_label()
	update_inventory_label()
	update_facing_visual()

func spawn_enemies() -> void:
	for entry in map.enemy_spawn_points:
		var data: EnemyData = slime_data if entry.symbol == "S" else goblin_data
		var e: Enemy = EnemyScene.instantiate()
		add_child(e)
		e.setup(data)
		e.set_grid_pos_immediate(entry.pos)
		enemies.append(e)

func place_items() -> void:
	items_on_ground.clear()
	item_visuals.clear()
	for entry in map.item_spawn_points:
		items_on_ground[entry.pos] = potion_data
		var iv: ItemVisual = ItemScene.instantiate()
		add_child(iv)
		iv.setup(potion_data)
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

	if not map.is_inside(target_pos):
		return
	if map.is_wall(target_pos):
		print("壁にぶつかりました")
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

	if not map.is_inside(land_pos):
		print("そちらにはドッジロールできません")
		return
	if map.is_wall(mid_pos):
		print("壁があってドッジロールできません")
		return
	if map.is_wall(land_pos):
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
	var damage = player_data.attack_damage
	if is_backstab(player_grid_pos, target_enemy.grid_pos, target_enemy.facing):
		damage *= player_data.backstab_multiplier
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
	for turn_index in range(player_data.dodge_turns):
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

	if not map.is_walkable(target_pos):
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
		if not map.is_walkable(target_pos):
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
		damage *= player_data.backstab_multiplier
		print("敵に背後を取られた！ 大ダメージ！")
	player_take_damage(damage)

func player_take_damage(amount: int) -> void:
	player_hp -= amount
	print("プレイヤーが攻撃を受けた！ 残りHP: ", player_hp)
	update_hp_label()

	if player_hp <= 0:
		game_over()

func update_hp_label() -> void:
	hud.update_hp(player_hp, player_data.max_hp)

func update_inventory_label() -> void:
	hud.update_inventory(player_inventory)



func game_over() -> void:
	is_game_over = true
	hud.show_game_over()   # hp_label.text = "GAME OVER" の代わり
