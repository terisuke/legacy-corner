extends Control

signal continue_pressed

@onready var comment_label := $CenterContainer/VBoxContainer/CommentLabel
@onready var score_label := $CenterContainer/VBoxContainer/ScoreLabel
@onready var rank_label := $CenterContainer/VBoxContainer/RankLabel
@onready var warning_label := $CenterContainer/VBoxContainer/WarningLabel
@onready var history_list := $CenterContainer/VBoxContainer/HistoryList
@onready var continue_button := $CenterContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(func(): continue_pressed.emit())
	warning_label.visible = false


func show_audit(audit_report: Dictionary) -> void:
	var normalized: int = audit_report.get("normalized_score", 0)
	var rank: String = audit_report.get("rank", "D")
	var comment: String = DataLoader.get_grandma_comment(normalized)

	comment_label.text = comment
	score_label.text = "スコア: %d / 100" % normalized
	rank_label.text = "ランク: %s" % rank

	# Show contamination warning if any missed
	var missed: Array = audit_report.get("contamination_missed", [])
	if not missed.is_empty():
		warning_label.visible = true
		warning_label.text = "⚠ 食中毒リスク！ %d個の汚染を見逃しました" % missed.size()

	# Populate decision history
	for child in history_list.get_children():
		child.queue_free()

	var history: Array = audit_report.get("decision_history", [])
	for entry: Dictionary in history:
		var label := Label.new()
		var action_text: String = _action_to_japanese(entry.get("action", ""))
		var item_name: String = entry.get("item_name", "")
		var regret: String = " 💔" if entry.get("triggered_regret", false) else ""
		var contaminated: String = " [汚染]" if entry.get("is_contaminated", false) else ""
		label.text = "・%s → %s%s%s" % [item_name, action_text, contaminated, regret]
		history_list.add_child(label)


func _action_to_japanese(action: String) -> String:
	match action:
		"keep": return "残した"
		"discard": return "捨てた"
		"wash_success": return "洗った（成功）"
		"wash_fail": return "洗った（失敗）"
		_: return action
