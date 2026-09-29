extends CanvasLayer
class_name Hud

@onready var hp_label: Label = $HPLabel
@onready var inventory_label: Label = $InventoryLabel

func update_hp(current: int, max_hp: int) -> void:
	hp_label.text = "HP: %d / %d" % [current, max_hp]

func update_inventory(items: Array[ItemData]) -> void:
	if items.is_empty():
		inventory_label.text = "持ち物: なし"
		return
	var names: Array[String] = []
	for item in items:
		names.append(item.display_name)
	inventory_label.text = "持ち物: " + ", ".join(names)

func show_game_over() -> void:
	hp_label.text = "GAME OVER"
