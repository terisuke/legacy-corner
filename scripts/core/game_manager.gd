extends Node
## GameManager — Main state machine and turn manager for Legacy Corner.
## Autoload singleton that controls game flow, layer progression, and turn budget.

enum GameState { TITLE, LAYER_OPEN, ITEM_INSPECT, DECISION, GRANDMA_AUDIT, RESULT }

signal state_changed(old_state: GameState, new_state: GameState)
signal turn_consumed(remaining: int)
signal layer_opened(layer_index: int)
signal game_ended(end_reason: String)

const MAX_TURNS := 10
const LAYERS_COUNT := 3
const ITEMS_PER_LAYER := 2

var current_state: GameState = GameState.TITLE
var current_layer: int = 0
var current_item_index: int = 0
var turns_remaining: int = MAX_TURNS
var game_items: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func start_game(seed_value: Variant = null) -> void:
	current_state = GameState.TITLE
	current_layer = 0
	current_item_index = 0
	turns_remaining = MAX_TURNS
	game_items = []
	ScoreManager.reset()

	if seed_value == null:
		rng.randomize()
	else:
		rng.seed = seed_value as int

	game_items = DataLoader.generate_game_items(rng)
	change_state(GameState.LAYER_OPEN)
	layer_opened.emit(0)


func use_turn() -> bool:
	if turns_remaining <= 0:
		return false

	turns_remaining -= 1
	turn_consumed.emit(turns_remaining)

	if turns_remaining == 0:
		_end_game("timeout")

	return true


func change_state(new_state: GameState) -> void:
	var old_state: GameState = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)


func advance_item() -> void:
	# INV-4: ターン0では進行不可
	if turns_remaining <= 0:
		return
	current_item_index += 1

	if current_item_index >= ITEMS_PER_LAYER:
		current_item_index = 0
		current_layer += 1

		if current_layer >= LAYERS_COUNT:
			_end_game("completed")
			return

		layer_opened.emit(current_layer)


func get_current_item() -> Dictionary:
	var index: int = current_layer * ITEMS_PER_LAYER + current_item_index
	if index < 0 or index >= game_items.size():
		return {}
	return game_items[index]


func get_items_for_layer(layer_index: int) -> Array:
	var start: int = layer_index * ITEMS_PER_LAYER
	var end: int = start + ITEMS_PER_LAYER

	if start < 0 or start >= game_items.size():
		return []

	end = mini(end, game_items.size())
	return game_items.slice(start, end)


func _end_game(reason: String) -> void:
	change_state(GameState.GRANDMA_AUDIT)
	game_ended.emit(reason)
