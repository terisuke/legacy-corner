extends Node
## GameManager — Main state machine and turn manager for Legacy Corner.
## Autoload singleton that controls game flow, layer progression, and turn budget.

enum GameState { TITLE, LAYER_OPEN, ITEM_INSPECT, DECISION, GRANDMA_AUDIT, RESULT }

signal state_changed(old_state: GameState, new_state: GameState)
signal turn_consumed(remaining: int)
signal layer_opened(layer_index: int)
signal decision_made(item_id: String, action: String, result: Dictionary)
signal game_ended(end_reason: String)

var current_state: GameState = GameState.TITLE
var current_layer: int = 0
var current_item_index: int = 0
var turns_remaining: int = 0
var game_items: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _max_turns: int = 0
var _layers_count: int = 0
var _items_per_layer: int = 0


func _ready() -> void:
	var constants: Dictionary = DataLoader.get_balance_constants()
	assert(constants.has("max_turns"), "GameManager: balance_constants missing max_turns")
	assert(constants.has("layers_count"), "GameManager: balance_constants missing layers_count")
	assert(constants.has("items_per_layer"), "GameManager: balance_constants missing items_per_layer")
	_max_turns = constants["max_turns"] as int
	_layers_count = constants["layers_count"] as int
	_items_per_layer = constants["items_per_layer"] as int
	assert(_max_turns > 0, "GameManager: max_turns must be > 0")
	assert(_layers_count > 0, "GameManager: layers_count must be > 0")
	assert(_items_per_layer > 0, "GameManager: items_per_layer must be > 0")
	turns_remaining = _max_turns


func start_game(seed_value: Variant = null) -> void:
	current_state = GameState.TITLE
	current_layer = 0
	current_item_index = 0
	turns_remaining = _max_turns
	game_items = []
	ScoreManager.reset()

	if seed_value == null:
		rng.randomize()
	else:
		rng.seed = seed_value as int

	game_items = DataLoader.generate_game_items(rng)
	assert(
		game_items.size() == _layers_count * _items_per_layer,
		"GameManager: item count %d != layers_count(%d) * items_per_layer(%d)" % [
			game_items.size(), _layers_count, _items_per_layer
		]
	)
	change_state(GameState.LAYER_OPEN)
	layer_opened.emit(0)


func use_turn() -> bool:
	if turns_remaining <= 0:
		return false

	turns_remaining -= 1
	turn_consumed.emit(turns_remaining)

	if turns_remaining == 0:
		_end_game("timeout")
		return false

	return true


func change_state(new_state: GameState) -> void:
	var old_state: GameState = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)


func advance_item() -> void:
	if current_state != GameState.ITEM_INSPECT and current_state != GameState.DECISION:
		push_error("GameManager: advance_item called in invalid state %s" % GameState.keys()[current_state])
		return
	# INV-4: ターン0では進行不可
	if turns_remaining <= 0:
		return
	# INV-1: 現在のアイテムが判断済みでなければ進行不可
	var current: Dictionary = get_current_item()
	if not current.is_empty() and current.get("decision", null) == null:
		push_error("GameManager: INV-1 — cannot advance, current item has no decision")
		return
	current_item_index += 1

	if current_item_index >= _items_per_layer:
		current_item_index = 0
		current_layer += 1

		if current_layer >= _layers_count:
			_end_game("completed")
			return

		layer_opened.emit(current_layer)


func get_current_item() -> Dictionary:
	var index: int = current_layer * _items_per_layer + current_item_index
	if index < 0 or index >= game_items.size():
		return {}
	return game_items[index]


func get_items_for_layer(layer_index: int) -> Array:
	var start: int = layer_index * _items_per_layer
	var end: int = start + _items_per_layer

	if start < 0 or start >= game_items.size():
		return []

	end = mini(end, game_items.size())
	return game_items.slice(start, end)


func _end_game(reason: String) -> void:
	change_state(GameState.GRANDMA_AUDIT)
	game_ended.emit(reason)
