class_name ContaminationSystem
extends RefCounted

signal inspection_completed(item_id: String, displayed_result: String)


func inspect_item(item: Dictionary, tool_data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var item_id: String = item.get("id", "") as String
	var inconclusive_rate: float = tool_data.get("inconclusive_rate", 0.0) as float
	if rng.randf() < inconclusive_rate:
		return _complete_inspection(item_id, "inconclusive", false)

	var is_contaminated: bool = item.get("is_contaminated", false)
	var error_rate_key: String = "false_negative_rate_given_contaminated"
	var accurate_result: String = "contaminated"
	var inaccurate_result: String = "clean"

	if not is_contaminated:
		error_rate_key = "false_positive_rate_given_clean"
		accurate_result = "clean"
		inaccurate_result = "contaminated"

	var error_rate: float = tool_data.get(error_rate_key, 0.0) as float
	if rng.randf() < error_rate:
		return _complete_inspection(item_id, inaccurate_result, false)

	return _complete_inspection(item_id, accurate_result, true)


func get_wash_success_rate(item: Dictionary) -> float:
	if not item.get("washable", false):
		return 0.0
	return item.get("wash_success_rate", 0.0) as float


func attempt_wash(item: Dictionary, rng: RandomNumberGenerator) -> bool:
	var wash_success_rate: float = get_wash_success_rate(item)
	return rng.randf() < wash_success_rate


func _complete_inspection(item_id: String, displayed_result: String, is_accurate: bool) -> Dictionary:
	inspection_completed.emit(item_id, displayed_result)
	return {
		"displayed_result": displayed_result,
		"is_accurate": is_accurate,
	}
