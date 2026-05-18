extends Control

const GAME_SCENE_PATH := "res://scenes/game.tscn"

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
