extends Control

@onready var title_panel := $TitlePanel
@onready var game_panel := $GamePanel
@onready var grandma_panel := $GrandmaPanel
@onready var result_panel := $ResultPanel
@onready var turn_label := $GamePanel/HUD/TurnLabel
@onready var layer_label := $GamePanel/HUD/LayerLabel
@onready var item_area := $GamePanel/ItemArea
@onready var keep_button := $GamePanel/ActionButtons/KeepButton
@onready var discard_button := $GamePanel/ActionButtons/DiscardButton
@onready var wash_button := $GamePanel/ActionButtons/WashButton
@onready var tool_button := $GamePanel/ToolButton
@onready var start_button := $TitlePanel/VBoxContainer/StartButton
@onready var retry_button := $ResultPanel/VBoxContainer/RetryButton

var _current_item_card: Node = null
var _item_card_scene: PackedScene = null

const _ContaminationSystemScript = preload("res://scripts/systems/contamination_system.gd")
var _contamination_system: RefCounted = null


func _ready() -> void:
	_item_card_scene = load("res://scenes/box/item_card.tscn")
	_contamination_system = _ContaminationSystemScript.new()

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.turn_consumed.connect(_on_turn_consumed)
	GameManager.layer_opened.connect(_on_layer_opened)

	start_button.pressed.connect(_on_start_pressed)
	retry_button.pressed.connect(_on_start_pressed)
	keep_button.pressed.connect(_on_keep_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	wash_button.pressed.connect(_on_wash_pressed)
	tool_button.pressed.connect(_on_tool_pressed)

	# Tool button disabled until Wave 3 integration is complete
	tool_button.disabled = true

	_show_panel(title_panel)


func _show_panel(panel: Control) -> void:
	title_panel.visible = (panel == title_panel)
	game_panel.visible = (panel == game_panel)
	grandma_panel.visible = (panel == grandma_panel)
	result_panel.visible = (panel == result_panel)


func _on_state_changed(
	_old: GameManager.GameState, new_state: GameManager.GameState
) -> void:
	match new_state:
		GameManager.GameState.TITLE:
			_show_panel(title_panel)
		GameManager.GameState.LAYER_OPEN, \
		GameManager.GameState.ITEM_INSPECT, \
		GameManager.GameState.DECISION:
			_show_panel(game_panel)
		GameManager.GameState.GRANDMA_AUDIT:
			_show_panel(grandma_panel)
		GameManager.GameState.RESULT:
			_show_panel(result_panel)


func _on_turn_consumed(remaining: int) -> void:
	turn_label.text = "残りターン: %d" % remaining


func _on_layer_opened(layer_index: int) -> void:
	var layers_count: int = GameManager.get_layers_count() if GameManager.has_method("get_layers_count") else 3
	layer_label.text = "層: %d / %d" % [layer_index + 1, layers_count]
	_show_current_item()


func _on_start_pressed() -> void:
	GameManager.start_game()


func _show_current_item() -> void:
	if _current_item_card != null:
		_current_item_card.queue_free()
		_current_item_card = null

	var item: Dictionary = GameManager.get_current_item()
	if item.is_empty():
		_set_actions_enabled(false)
		return

	_current_item_card = _item_card_scene.instantiate()
	item_area.add_child(_current_item_card)
	_current_item_card.setup(item)

	wash_button.disabled = not item.get("washable", false)
	turn_label.text = "残りターン: %d" % GameManager.turns_remaining
	_set_actions_enabled(true)


func _set_actions_enabled(enabled: bool) -> void:
	keep_button.disabled = not enabled
	discard_button.disabled = not enabled
	wash_button.disabled = (
		not enabled or not GameManager.get_current_item().get("washable", false)
	)
	# tool_button stays disabled until Wave 3


func _on_keep_pressed() -> void:
	if not GameManager.use_turn():
		return
	var item: Dictionary = GameManager.get_current_item()
	ScoreManager.record_decision(item, "keep", {})
	_advance_to_next()


func _on_discard_pressed() -> void:
	if not GameManager.use_turn():
		return
	var item: Dictionary = GameManager.get_current_item()
	ScoreManager.record_decision(item, "discard", {})
	# Always show memory on discard (INV-3: no is_contaminated branch in UI)
	if _current_item_card != null:
		_current_item_card.show_memory()
	_advance_to_next()


func _on_wash_pressed() -> void:
	if not GameManager.use_turn():
		return
	var item: Dictionary = GameManager.get_current_item()
	# Delegate to ContaminationSystem (single authority for wash logic)
	var success: bool = _contamination_system.attempt_wash(item, GameManager.rng)
	var action: String = "wash_success" if success else "wash_fail"
	ScoreManager.record_decision(item, action, {})
	_advance_to_next()


func _on_tool_pressed() -> void:
	# Disabled in MVP — will be enabled in Wave 3 with ContaminationSystem.inspect_item()
	pass


func _advance_to_next() -> void:
	_set_actions_enabled(false)
	GameManager.advance_item()
	if GameManager.current_state == GameManager.GameState.GRANDMA_AUDIT:
		return
	_show_current_item()
