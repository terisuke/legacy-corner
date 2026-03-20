class_name DecisionSystem
extends RefCounted

signal decision_made(item_id: String, action: String, result_summary: Dictionary)
signal regret_triggered(item_data: Dictionary)

const _ContaminationSystemScript = preload("res://scripts/systems/contamination_system.gd")
var _contamination_system: RefCounted


func _init() -> void:
	_contamination_system = _ContaminationSystemScript.new()


func can_wash(item_data: Dictionary) -> bool:
	return item_data.get("washable", false)


func execute_decision(item_data: Dictionary, action: String, rng: RandomNumberGenerator) -> Dictionary:
	# INV-1: reject if already decided
	if item_data.get("decision", null) != null:
		push_error("DecisionSystem: INV-1 violation — item '%s' already has decision" % item_data.get("id", ""))
		return {"success": false, "reason": "already_decided"}

	# Validate action
	if action not in ["keep", "discard", "wash"]:
		push_error("DecisionSystem: invalid action '%s'" % action)
		return {"success": false, "reason": "invalid_action"}

	# INV-1: wash on non-washable item
	if action == "wash" and not can_wash(item_data):
		push_error("DecisionSystem: cannot wash non-washable item '%s'" % item_data.get("id", ""))
		return {"success": false, "reason": "not_washable"}

	var result_summary: Dictionary = {}
	var score_action: String = action  # may be modified for wash

	match action:
		"keep":
			result_summary = {"action": "keep"}

		"discard":
			var is_contaminated: bool = item_data.get("is_contaminated", false)
			var triggered_regret: bool = not is_contaminated
			result_summary = {
				"action": "discard",
				"triggered_regret": triggered_regret,
			}
			if triggered_regret:
				regret_triggered.emit(item_data)

		"wash":
			var success: bool = _contamination_system.attempt_wash(item_data, rng)
			score_action = "wash_success" if success else "wash_fail"
			result_summary = {
				"action": "wash",
				"wash_success": success,
			}

	# Build action_result for ScoreManager
	var action_result: Dictionary = _build_action_result(item_data)

	# Record in ScoreManager (this also sets item_data["decision"])
	ScoreManager.record_decision(item_data, score_action, action_result)

	# Emit signal — INV-2: do NOT include score_delta
	decision_made.emit(
		item_data.get("id", "") as String,
		action,
		result_summary
	)

	return {"success": true, "action": score_action, "result": result_summary}


func _build_action_result(item_data: Dictionary) -> Dictionary:
	var action_result: Dictionary = {}
	# Check if tool inspection found contamination (for +5 bonus)
	var inspection: Variant = item_data.get("inspection_result", null)
	if inspection != null and inspection is Dictionary:
		if inspection.get("displayed_result", "") == "contaminated":
			action_result["tool_found_contamination"] = true
	return action_result
