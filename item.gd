extends Sprite2D
class_name ItemVisual

const TILE_SIZE = 32

var data: ItemData

func setup(item_data: ItemData) -> void:
	data = item_data
	if data.icon:
		texture = data.icon

func set_grid_pos(pos: Vector2i) -> void:
	position = Vector2(pos * TILE_SIZE) + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
