extends Node
## ScoreManager — Tracks score internally during gameplay.
## Score is NEVER exposed until calculate_final_score() is called (INV-2).

var _score_min: int = -180
var _score_max: int = 170

var _raw_score: int = 0
var _decision_history: Array = []


func _ready() -> void:
	var constants: Dictionary = DataLoader.get_balance_constants()
	_score_min = constants.get("score_min", -180) as int
	_score_max = constants.get("score_max", 170) as int


func reset() -> void:
	_raw_score = 0
	_decision_history = []


func record_decision(item_data: Dictionary, action: String, action_result: Dictionary) -> void:
	var score_delta: int = _calculate_delta(item_data, action)

	if action_result.get("tool_found_contamination", false):
		score_delta += 5

	_raw_score += score_delta

	var triggered_regret: bool = (
		action == "discard" and not item_data.get("is_contaminated", false)
	)

	_decision_history.append({
		"item_id": item_data.get("id", ""),
		"item_name": item_data.get("name", ""),
		"action": action,
		"score_delta": score_delta,
		"is_contaminated": item_data.get("is_contaminated", false),
		"triggered_regret": triggered_regret,
	})


func _calculate_delta(item_data: Dictionary, action: String) -> int:
	var is_contaminated: bool = item_data.get("is_contaminated", false)
	var discard_regret: float = item_data.get("discard_regret", 0.0) as float

	match action:
		"discard":
			if is_contaminated:
				return 20
			return int(roundf(-10.0 * discard_regret))
		"keep":
			if is_contaminated:
				return -30
			return 15
		"wash_success":
			return 25
		"wash_fail":
			return -15
		_:
			push_error("ScoreManager: unknown action '%s'" % action)
			return 0


func calculate_final_score(turns_remaining: int, unprocessed_count: int) -> Dictionary:
	var raw: int = _raw_score + (3 * turns_remaining) + (-20 * unprocessed_count)

	var score_range: float = float(_score_max - _score_min)
	var normalized: int = 0
	if score_range > 0.0:
		normalized = clampi(
			int(roundf(float(raw - _score_min) / score_range * 100.0)),
			0, 100
		)

	var rank: String = _get_rank(normalized)

	var contamination_missed: Array = []
	var regret_items: Array = []
	for entry: Dictionary in _decision_history:
		if entry.get("action", "") == "keep" and entry.get("is_contaminated", false):
			contamination_missed.append(entry)
		if entry.get("triggered_regret", false):
			regret_items.append(entry)

	return {
		"raw_score": raw,
		"normalized_score": normalized,
		"rank": rank,
		"decision_history": _decision_history.duplicate(true),
		"contamination_missed": contamination_missed,
		"regret_items": regret_items,
		"unprocessed_items_count": unprocessed_count,
	}


func _get_rank(normalized: int) -> String:
	if normalized >= 90:
		return "S"
	elif normalized >= 70:
		return "A"
	elif normalized >= 50:
		return "B"
	elif normalized >= 30:
		return "C"
	else:
		return "D"
