extends PanelContainer
class_name ItemCard

signal card_selected

const YEARS_LABEL_TEMPLATE: String = "放置: %d年"

@onready var _item_name_label: Label = $VBoxContainer/ItemName
@onready var _years_label: Label = $VBoxContainer/YearsLabel
@onready var _tool_result_label: Label = $VBoxContainer/ToolResult
@onready var _memory_text_label: Label = $VBoxContainer/MemoryText

var _item_data: Dictionary = {}


func setup(item_data: Dictionary) -> void:
	_item_data = item_data
	_item_name_label.text = item_data.get("name", "") as String
	_years_label.text = YEARS_LABEL_TEMPLATE % int(item_data.get("years_old", 0))
	hide_overlays()


func show_tool_result(result: String) -> void:
	_tool_result_label.text = result
	_tool_result_label.show()


func show_memory() -> void:
	_memory_text_label.text = _item_data.get("memory_text", "") as String
	_memory_text_label.show()


func hide_overlays() -> void:
	_tool_result_label.hide()
	_memory_text_label.hide()
