extends Node
## ScoreManager — Tracks score internally during gameplay.
## Score is NEVER exposed until calculate_final_score() is called (INV-2).

var _score_min: int = -180
var _score_max: int = 170

# Score delta constants — loaded from DataLoader (INV-6: no hardcoded balance values)
var _d: Dictionary = {}

# Internal state — NO public getter for score (INV-2)
var _raw_score: int = 0
var _decision_history: Array = []


func _ready() -> void:
	var c: Dictionary = DataLoader.get_balance_constants()
	_score_min = c.get("score_min", -180) as int
	_score_max = c.get("score_max", 170) as int
	_d = {
		"discard_contaminated": c.get("score_discard_contaminated", 20) as int,
		"discard_safe_mul": c.get("score_discard_safe_multiplier", -10) as int,
		"keep_safe": c.get("score_keep_safe", 15) as int,
		"keep_contaminated": c.get("score_keep_contaminated", -30) as int,
		"wash_success": c.get("score_wash_success", 25) as int,
		"wash_fail": c.get("score_wash_fail", -15) as int,
		"tool_bonus": c.get("score_tool_found_bonus", 5) as int,
		"turn_bonus": c.get("score_turn_bonus", 3) as int,
		"unprocessed": c.get("score_unprocessed_penalty", -20) as int,
	}


func reset() -> void:
	_raw_score = 0
	_decision_history = []


func record_decision(item_data: Dictionary, action: String, action_result: Dictionary) -> void:
	# INV-1: 1アイテム1回のみ。判断済みは拒否。
	if item_data.get("decision", null) != null:
		push_error("ScoreManager: INV-1 violation — duplicate decision for '%s'" % item_data.get("id", ""))
		return

	var resolved_action: String = _normalize_action(action)
	if resolved_action.is_empty():
		return

	var wash_succeeded: Variant = _resolve_wash_succeeded(action, action_result)
	if resolved_action == "wash" and wash_succeeded == null:
		push_error("ScoreManager: wash action requires action_result['wash_succeeded']")
		return

	var score_delta: int = _calculate_delta(item_data, resolved_action, wash_succeeded)

	if action_result.get("tool_found_contamination", false):
		score_delta += _d.get("tool_bonus", 5)

	_raw_score += score_delta

	var triggered_regret: bool = (
		resolved_action == "discard" and not item_data.get("is_contaminated", false)
	)

	# Store a domain-shaped terminal decision instead of raw transport strings.
	item_data["decision"] = {
		"action": resolved_action,
		"wash_succeeded": wash_succeeded,
		"score_delta": score_delta,
		"triggered_regret": triggered_regret,
	}

	_decision_history.append({
		"item_id": item_data.get("id", ""),
		"item_name": item_data.get("name", ""),
		"action": resolved_action,
		"wash_succeeded": wash_succeeded,
		"score_delta": score_delta,
		"is_contaminated": item_data.get("is_contaminated", false),
		"triggered_regret": triggered_regret,
	})


func _normalize_action(action: String) -> String:
	if action == "wash_success":
		return "wash"
	if action == "wash_fail":
		return "wash"
	return action


func _resolve_wash_succeeded(action: String, action_result: Dictionary) -> Variant:
	if action == "wash_success":
		return true
	if action == "wash_fail":
		return false
	return action_result.get("wash_succeeded", null)


func _calculate_delta(item_data: Dictionary, action: String, wash_succeeded: Variant) -> int:
	var is_contaminated: bool = item_data.get("is_contaminated", false)
	var regret: float = item_data.get("discard_regret", 0.0) as float

	match action:
		"discard":
			if is_contaminated:
				return _d.get("discard_contaminated", 20)
			return int(roundf(float(_d.get("discard_safe_mul", -10)) * regret))
		"keep":
			if is_contaminated:
				return _d.get("keep_contaminated", -30)
			return _d.get("keep_safe", 15)
		"wash":
			if wash_succeeded:
				return _d.get("wash_success", 25)
			return _d.get("wash_fail", -15)
		_:
			push_error("ScoreManager: unknown action '%s'" % action)
			return 0


func calculate_final_score(turns_remaining: int, unprocessed_count: int) -> Dictionary:
	var turn_bonus: int = _d.get("turn_bonus", 3) * turns_remaining
	var unprocessed_pen: int = _d.get("unprocessed", -20) * unprocessed_count
	var raw: int = _raw_score + turn_bonus + unprocessed_pen

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
