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

const _DecisionSystemScript = preload("res://scripts/systems/decision_system.gd")
const _ContaminationSystemScript = preload("res://scripts/systems/contamination_system.gd")
var _decision_system: RefCounted = null


func _ready() -> void:
	_item_card_scene = load("res://scenes/box/item_card.tscn")
	_grandma_scene = load("res://scenes/grandma/grandma_audit.tscn")
	_result_scene = load("res://scenes/ui/result_screen.tscn")
	_decision_system = _DecisionSystemScript.new()

	# Connect DecisionSystem signals for UI feedback
	_decision_system.regret_triggered.connect(_on_regret_triggered)

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.turn_consumed.connect(_on_turn_consumed)
	GameManager.layer_opened.connect(_on_layer_opened)

	start_button.pressed.connect(_on_start_pressed)
	keep_button.pressed.connect(_on_keep_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	wash_button.pressed.connect(_on_wash_pressed)
	tool_button.pressed.connect(_on_tool_pressed)

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
	var layers_count: int = GameManager.get_layers_count()
	layer_label.text = "層: %d / %d" % [layer_index + 1, layers_count]
	_show_current_item()


func _on_start_pressed() -> void:
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
	GameManager.change_state(GameManager.GameState.ITEM_INSPECT)


func _set_actions_enabled(enabled: bool) -> void:
	keep_button.disabled = not enabled
	discard_button.disabled = not enabled
	wash_button.disabled = (
		not enabled or not GameManager.get_current_item().get("washable", false)
	)
	tool_button.disabled = not enabled


# === Decision handlers — all delegate to DecisionSystem ===

func _on_keep_pressed() -> void:
	GameManager.change_state(GameManager.GameState.DECISION)
	var item: Dictionary = GameManager.get_current_item()
	if not GameManager.use_turn():
		return
	var result: Dictionary = _decision_system.execute_decision(item, "keep", GameManager.rng)
	if not result.get("success", false):
		return
	_advance_to_next()


func _on_discard_pressed() -> void:
	GameManager.change_state(GameManager.GameState.DECISION)
	var item: Dictionary = GameManager.get_current_item()
	if not GameManager.use_turn():
		return
	var result: Dictionary = _decision_system.execute_decision(item, "discard", GameManager.rng)
	if not result.get("success", false):
		return
	# If regret was triggered, delay advancement so player can see memory text
	var res: Dictionary = result.get("result", {})
	if res.get("triggered_regret", false):
		_set_actions_enabled(false)
		await get_tree().create_timer(1.5).timeout
	_advance_to_next()


func _on_wash_pressed() -> void:
	GameManager.change_state(GameManager.GameState.DECISION)
	var item: Dictionary = GameManager.get_current_item()
	if not item.get("washable", false):
		return
	if not GameManager.use_turn():
		return
	var result: Dictionary = _decision_system.execute_decision(item, "wash", GameManager.rng)
	if not result.get("success", false):
		return
	_advance_to_next()


func _on_tool_pressed() -> void:
	if not GameManager.use_turn():
		return
	var item: Dictionary = GameManager.get_current_item()
	var mvp_tools: Array = DataLoader.get_mvp_tools()
	if mvp_tools.is_empty():
		return
	var tool_data: Dictionary = mvp_tools[0]
	var cs = _ContaminationSystemScript.new()
	var result: Dictionary = cs.inspect_item(item, tool_data, GameManager.rng)
	item["inspection_result"] = result
	var display_text: String = ""
	match result.get("displayed_result", ""):
		"contaminated":
			display_text = "⚠ 汚染あり"
		"clean":
			display_text = "✅ 汚染なし"
		"inconclusive":
			display_text = "❓ 判定不能"
	if _current_item_card != null:
		_current_item_card.show_tool_result(display_text)
	turn_label.text = "残りターン: %d" % GameManager.turns_remaining


func _on_regret_triggered(_item_data: Dictionary) -> void:
	if _current_item_card != null:
		_current_item_card.show_memory()


func _advance_to_next() -> void:
	_set_actions_enabled(false)
	GameManager.advance_item()
	if GameManager.current_state == GameManager.GameState.GRANDMA_AUDIT:
		return
	_show_current_item()


# === Wave 4: Grandma Audit ===

func _show_grandma_audit() -> void:
	_show_panel(grandma_panel)

	var unprocessed: int = _count_unprocessed()
	_audit_report = ScoreManager.calculate_final_score(
		GameManager.turns_remaining, unprocessed
	)

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
