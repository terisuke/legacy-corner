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

var _current_item_card: Node = null
var _item_card_scene: PackedScene = null
var _grandma_scene: PackedScene = null
var _result_scene: PackedScene = null
var _grandma_instance: Node = null
var _result_instance: Node = null
var _audit_report: Dictionary = {}

const _ContaminationSystemScript = preload("res://scripts/systems/contamination_system.gd")
var _contamination_system: RefCounted = null


func _ready() -> void:
	_item_card_scene = load("res://scenes/box/item_card.tscn")
	_grandma_scene = load("res://scenes/grandma/grandma_audit.tscn")
	_result_scene = load("res://scenes/ui/result_screen.tscn")
	_contamination_system = _ContaminationSystemScript.new()

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.turn_consumed.connect(_on_turn_consumed)
	GameManager.layer_opened.connect(_on_layer_opened)

	start_button.pressed.connect(_on_start_pressed)
	keep_button.pressed.connect(_on_keep_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	wash_button.pressed.connect(_on_wash_pressed)
	tool_button.pressed.connect(_on_tool_pressed)

	# Tool button disabled until full Wave 3 integration
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
			_show_grandma_audit()
		GameManager.GameState.RESULT:
			_show_result()


func _on_turn_consumed(remaining: int) -> void:
	turn_label.text = "残りターン: %d" % remaining


func _on_layer_opened(layer_index: int) -> void:
	var layers_count: int = GameManager.get_layers_count() if GameManager.has_method("get_layers_count") else 3
	layer_label.text = "層: %d / %d" % [layer_index + 1, layers_count]
	_show_current_item()


func _on_start_pressed() -> void:
	# Clean up previous game instances
	_cleanup_grandma()
	_cleanup_result()
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
	if _current_item_card != null:
		_current_item_card.show_memory()
	_advance_to_next()


func _on_wash_pressed() -> void:
	if not GameManager.use_turn():
		return
	var item: Dictionary = GameManager.get_current_item()
	var success: bool = _contamination_system.attempt_wash(item, GameManager.rng)
	var action: String = "wash_success" if success else "wash_fail"
	ScoreManager.record_decision(item, action, {})
	_advance_to_next()


func _on_tool_pressed() -> void:
	pass


func _advance_to_next() -> void:
	_set_actions_enabled(false)
	GameManager.advance_item()
	if GameManager.current_state == GameManager.GameState.GRANDMA_AUDIT:
		return
	_show_current_item()


# === Wave 4: Grandma Audit ===

func _show_grandma_audit() -> void:
	_show_panel(grandma_panel)

	# Calculate final score
	var unprocessed: int = _count_unprocessed()
	_audit_report = ScoreManager.calculate_final_score(
		GameManager.turns_remaining, unprocessed
	)

	# Instantiate grandma scene into the panel
	_cleanup_grandma()
	_grandma_instance = _grandma_scene.instantiate()
	grandma_panel.add_child(_grandma_instance)
	_grandma_instance.show_audit(_audit_report)
	_grandma_instance.continue_pressed.connect(_on_grandma_continue)


func _on_grandma_continue() -> void:
	GameManager.change_state(GameManager.GameState.RESULT)


func _cleanup_grandma() -> void:
	if _grandma_instance != null:
		_grandma_instance.queue_free()
		_grandma_instance = null


# === Wave 4: Result Screen ===

func _show_result() -> void:
	_show_panel(result_panel)

	_cleanup_result()
	_result_instance = _result_scene.instantiate()
	result_panel.add_child(_result_instance)
	_result_instance.show_result(_audit_report)
	_result_instance.retry_pressed.connect(_on_start_pressed)


func _cleanup_result() -> void:
	if _result_instance != null:
		_result_instance.queue_free()
		_result_instance = null


# === Helpers ===

func _count_unprocessed() -> int:
	var count: int = 0
	for item: Dictionary in GameManager.game_items:
		if item.get("decision", null) == null:
			count += 1
	return count
