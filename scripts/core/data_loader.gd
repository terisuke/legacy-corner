extends Node
## DataLoader — Autoload singleton that reads JSON data files at startup
## and provides game data to other systems.

var _items_data: Dictionary = {}
var _dialogues_data: Dictionary = {}


func _ready() -> void:
	_items_data = _load_json_file("res://data/items.json")
	_dialogues_data = _load_json_file("res://data/grandma_dialogues.json")


func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: failed to open %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(content)
	if error != OK:
		push_error("DataLoader: failed to parse %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}

	return json.data as Dictionary


func get_item_templates() -> Array:
	return _items_data.get("items", []) as Array


func get_mvp_tools() -> Array:
	var all_tools: Array = _items_data.get("tools", [])
	var mvp_tools: Array = []
	for tool_def: Dictionary in all_tools:
		if tool_def.get("mvp_enabled", false):
			mvp_tools.append(tool_def)
	return mvp_tools


func get_balance_constants() -> Dictionary:
	return _items_data.get("balance_constants", {}) as Dictionary


func get_grandma_comment(normalized_score: int) -> String:
	var comments: Array = _dialogues_data.get("audit_comments", [])
	if comments.is_empty():
		return ""

	var lowest_comment: Dictionary = comments[0]
	var lowest_min: int = lowest_comment.get("score_range", [0, 0])[0]

	for comment: Dictionary in comments:
		var score_range: Array = comment.get("score_range", [0, 0])
		var range_min: int = score_range[0] as int
		var range_max: int = score_range[1] as int

		if range_min < lowest_min:
			lowest_min = range_min
			lowest_comment = comment

		if normalized_score >= range_min and normalized_score <= range_max:
			return comment.get("text", "") as String

	return lowest_comment.get("text", "") as String


func get_contamination_comment(rng: RandomNumberGenerator) -> String:
	var comments: Array = _dialogues_data.get("contamination_found", [])
	if comments.is_empty():
		return ""
	var idx: int = rng.randi_range(0, comments.size() - 1)
	return comments[idx].get("text", "") as String


func get_perfect_comment() -> String:
	var comments: Array = _dialogues_data.get("perfect_corner", [])
	if comments.is_empty():
		return ""
	return comments[0].get("text", "") as String


func generate_game_items(rng: RandomNumberGenerator) -> Array:
	var templates: Array = get_item_templates()
	var constants: Dictionary = get_balance_constants()
	var contam_coeff: float = constants.get("contamination_coefficient", 0.015) as float
	var contam_min: float = constants.get("contamination_min", 0.05) as float
	var contam_max: float = constants.get("contamination_max", 0.85) as float
	var wash_base: float = constants.get("wash_base", 0.9) as float
	var wash_coeff: float = constants.get("wash_coefficient", 0.025) as float
	var wash_min: float = constants.get("wash_min", 0.1) as float
	var wash_max: float = constants.get("wash_max", 0.9) as float

	var items: Array = []

	for template: Dictionary in templates:
		var years_range: Array = template.get("years_old_range", [1, 10])
		var years_old: int = rng.randi_range(years_range[0] as int, years_range[1] as int)
		var base_chance: float = template.get("base_contamination_chance", 0.0) as float

		# ADR-003 §1: contamination probability
		var contamination_chance: float = clampf(
			base_chance + float(years_old) * contam_coeff,
			contam_min, contam_max
		)
		var is_contaminated: bool = rng.randf() < contamination_chance

		# ADR-003 §3: wash success rate
		var wash_success_rate: float = 0.0
		if template.get("washable", false):
			wash_success_rate = clampf(
				wash_base - float(years_old) * wash_coeff,
				wash_min, wash_max
			)

		var item: Dictionary = {
			"id": template.get("id", ""),
			"name": template.get("name", ""),
			"years_old": years_old,
			"base_contamination_chance": base_chance,
			"contamination_chance": contamination_chance,
			"is_contaminated": is_contaminated,
			"memory_text": template.get("memory_text", ""),
			"washable": template.get("washable", false),
			"wash_success_rate": wash_success_rate,
			"discard_regret": template.get("discard_regret", 0.0),
			"inspection_result": null,
			"decision": null,
		}
		items.append(item)

	## NOTE: Mutates items in-place (Fisher-Yates shuffle).
	_shuffle_array(items, rng)
	return items


func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	var n: int = arr.size()
	for i: int in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
