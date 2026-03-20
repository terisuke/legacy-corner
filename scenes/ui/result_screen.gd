extends Control

signal retry_pressed

@onready var score_label := $CenterContainer/VBoxContainer/ScoreLabel
@onready var rank_label := $CenterContainer/VBoxContainer/RankLabel
@onready var retry_button := $CenterContainer/VBoxContainer/RetryButton


func _ready() -> void:
	retry_button.pressed.connect(func(): retry_pressed.emit())


func show_result(audit_report: Dictionary) -> void:
	var normalized: int = audit_report.get("normalized_score", 0)
	var rank: String = audit_report.get("rank", "D")
	score_label.text = "スコア: %d / 100" % normalized
	rank_label.text = "ランク: %s" % rank
