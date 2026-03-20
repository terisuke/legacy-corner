extends Node
## ScoreManager — Tracks score internally during gameplay.
## Score is NEVER exposed until calculate_final_score() is called (INV-2).

signal decision_recorded(item_id: String, action: String, result: Dictionary)

var _score_min: int = 0
var _score_max: int = 0
var _rank_s_min: int = 0
var _rank_a_min: int = 0
var _rank_b_min: int = 0
var _rank_c_min: int = 0

# Score delta constants — loaded from DataLoader (INV-6: no hardcoded balance values)
var _d: Dictionary = {}

# Internal state — NO public getter for score (INV-2)
var _raw_score: int = 0
var _decision_history: Array = []


func _ready() -> void:
	var c: Dictionary = DataLoader.get_balance_constants()
	assert(c.has("score_min"), "ScoreManager: balance_constants missing score_min")
	assert(c.has("score_max"), "ScoreManager: balance_constants missing score_max")
	assert(c.has("score_discard_contaminated"), "ScoreManager: missing score_discard_contaminated")
	assert(c.has("score_discard_safe_multiplier"), "ScoreManager: missing score_discard_safe_multiplier")
	assert(c.has("score_keep_safe"), "ScoreManager: missing score_keep_safe")
	assert(c.has("score_keep_contaminated"), "ScoreManager: missing score_keep_contaminated")
	assert(c.has("score_wash_success"), "ScoreManager: missing score_wash_success")
	assert(c.has("score_wash_fail"), "ScoreManager: missing score_wash_fail")
	assert(c.has("score_tool_found_bonus"), "ScoreManager: missing score_tool_found_bonus")
	assert(c.has("score_turn_bonus"), "ScoreManager: missing score_turn_bonus")
	assert(c.has("score_unprocessed_penalty"), "ScoreManager: missing score_unprocessed_penalty")
	assert(c.has("rank_s_min"), "ScoreManager: missing rank_s_min")
	assert(c.has("rank_a_min"), "ScoreManager: missing rank_a_min")
	assert(c.has("rank_b_min"), "ScoreManager: missing rank_b_min")
	assert(c.has("rank_c_min"), "ScoreManager: missing rank_c_min")
	_score_min = c["score_min"] as int
	_score_max = c["score_max"] as int
	_rank_s_min = c["rank_s_min"] as int
	_rank_a_min = c["rank_a_min"] as int
	_rank_b_min = c["rank_b_min"] as int
	_rank_c_min = c["rank_c_min"] as int
	assert(_score_max > _score_min, "ScoreManager: score_max must be greater than score_min")
	assert(_rank_s_min > _rank_a_min, "ScoreManager: rank_s_min must be > rank_a_min")
	assert(_rank_a_min > _rank_b_min, "ScoreManager: rank_a_min must be > rank_b_min")
	assert(_rank_b_min > _rank_c_min, "ScoreManager: rank_b_min must be > rank_c_min")
	assert(_rank_c_min >= 0, "ScoreManager: rank_c_min must be >= 0")
	_d = {
		"discard_contaminated": c["score_discard_contaminated"] as int,
		"discard_safe_mul": c["score_discard_safe_multiplier"] as int,
		"keep_safe": c["score_keep_safe"] as int,
		"keep_contaminated": c["score_keep_contaminated"] as int,
		"wash_success": c["score_wash_success"] as int,
		"wash_fail": c["score_wash_fail"] as int,
		"tool_bonus": c["score_tool_found_bonus"] as int,
		"turn_bonus": c["score_turn_bonus"] as int,
		"unprocessed": c["score_unprocessed_penalty"] as int,
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
		score_delta += _d["tool_bonus"] as int

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
	decision_recorded.emit(item_data.get("id", ""), resolved_action, item_data["decision"])

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
	if action == "discard" or action == "keep" or action == "wash":
		return action
	push_error("ScoreManager: unrecognized action '%s'" % action)
	return ""


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
				return _d["discard_contaminated"] as int
			return _round_score_delta(float(_d["discard_safe_mul"] as int) * regret)
		"keep":
			if is_contaminated:
				return _d["keep_contaminated"] as int
			return _d["keep_safe"] as int
		"wash":
			if wash_succeeded:
				return _d["wash_success"] as int
			return _d["wash_fail"] as int
		_:
			push_error("ScoreManager: unknown action '%s'" % action)
			return 0


func _round_score_delta(value: float) -> int:
	var floor_value: float = floorf(value)
	var fraction: float = value - floor_value

	# ADR-003 integer policy: ties round to the nearest even integer.
	if is_equal_approx(absf(fraction), 0.5):
		var lower: int = int(floor_value)
		var upper: int = int(ceilf(value))
		if lower % 2 == 0:
			return lower
		return upper

	return int(roundf(value))


func calculate_final_score(turns_remaining: int, unprocessed_count: int) -> Dictionary:
	var turn_bonus: int = (_d["turn_bonus"] as int) * turns_remaining
	var unprocessed_pen: int = (_d["unprocessed"] as int) * unprocessed_count
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
		"contamination_missed": contamination_missed.duplicate(true),
		"regret_items": regret_items.duplicate(true),
		"unprocessed_items_count": unprocessed_count,
	}


func _get_rank(normalized: int) -> String:
	if normalized >= _rank_s_min:
		return "S"
	elif normalized >= _rank_a_min:
		return "A"
	elif normalized >= _rank_b_min:
		return "B"
	elif normalized >= _rank_c_min:
		return "C"
	else:
		return "D"
