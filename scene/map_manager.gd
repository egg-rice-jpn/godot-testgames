extends TileMapLayer
class_name MapManager

enum TileType { FLOOR = 0, WALL = 1 }

@export var current_map_path: String = "res://data/maps/map_01.txt"

var width: int = 0
var height: int = 0
var map_data: Array = []
var enemy_spawn_points: Array = []  # {"pos": 位置, "symbol": "S"や"G"}
var item_spawn_points: Array = []   # {"pos": 位置, "symbol": "I"}

func load_map() -> void:
	var layout = _load_layout(current_map_path)

	map_data.clear()
	enemy_spawn_points.clear()
	item_spawn_points.clear()

	height = layout.size()
	width = layout[0].length()

	for x in range(width):
		map_data.append([])
		for y in range(height):
			map_data[x].append(TileType.FLOOR)

	for y in range(height):
		for x in range(width):
			var symbol = layout[y][x]
			match symbol:
				"#":
					map_data[x][y] = TileType.WALL
				"S", "G":
					enemy_spawn_points.append({"pos": Vector2i(x, y), "symbol": symbol})
				"I":
					item_spawn_points.append({"pos": Vector2i(x, y), "symbol": symbol})

func _load_layout(path: String) -> Array[String]:
	var lines: Array[String] = []
	var file = FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var line = file.get_line()
		if line != "":
			lines.append(line)
	file.close()
	return lines

func draw_map() -> void:
	for x in range(width):
		for y in range(height):
			if map_data[x][y] == TileType.WALL:
				set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
			else:
				set_cell(Vector2i(x, y), 0, Vector2i(0, 1))

# マップの範囲内か
func is_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func is_wall(pos: Vector2i) -> bool:
	return map_data[pos.x][pos.y] == TileType.WALL

# 範囲内で、壁でもない（歩いて行ける）か
func is_walkable(pos: Vector2i) -> bool:
	return is_inside(pos) and not is_wall(pos)
