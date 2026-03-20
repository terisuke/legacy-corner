extends PanelContainer

@onready var layer_title := $VBoxContainer/LayerTitle
@onready var items_container := $VBoxContainer/ItemsContainer

var _layer_index: int = 0


func setup(layer_index: int, items: Array) -> void:
	_layer_index = layer_index
	layer_title.text = "第%d層" % (layer_index + 1)

	# Clear existing children
	for child in items_container.get_children():
		child.queue_free()

	# Note: item_card instances are added by main.gd
	# This scene just provides the container structure


func get_items_container() -> HBoxContainer:
	return items_container
