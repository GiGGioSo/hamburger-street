extends Control

const GAME_SCENE_PATH := "res://scenes/game.tscn"

@onready var last_score_label: Label = $Scores/LastScoreLabel as Label
@onready var best_score_label: Label = $Scores/BestScoreLabel as Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_to_viewport()

	if not get_viewport().size_changed.is_connected(_fit_to_viewport):
		get_viewport().size_changed.connect(_fit_to_viewport)

func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_fit_to_viewport):
		get_viewport().size_changed.disconnect(_fit_to_viewport)

func setup_scores(last_score: int, best_score: int) -> void:
	if not is_node_ready():
		await ready

	last_score_label.text = "Score: %d" % last_score
	best_score_label.text = "Best: %d" % best_score

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()

func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

func _on_play_again_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
