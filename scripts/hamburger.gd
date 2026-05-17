class_name Hamburger
extends Node2D

enum CookStage {
	RAW,
	COOKED,
	BURNT,
}

@export var points_to_cooked := 3
@export var points_to_burnt := 5
@export var raw_texture: Texture2D = preload("res://textures/cooking/hamburger_patty_raw.png")
@export var cooked_texture: Texture2D = preload("res://textures/cooking/hamburger_patty_well_done.png")
@export var burnt_texture: Texture2D = preload("res://textures/cooking/hamburger_patty_overdone.png")

@onready var hamburger_image := $HamburgerImage as Sprite2D

var cook_stage := CookStage.RAW
var cook_points_in_stage := 0

func _ready() -> void:
	add_to_group("hamburger")
	_update_texture()

func add_cook_point() -> void:
	if cook_stage == CookStage.BURNT:
		return

	cook_points_in_stage += 1

	if cook_stage == CookStage.RAW and cook_points_in_stage >= max(1, points_to_cooked):
		set_cook_stage(CookStage.COOKED)
	elif cook_stage == CookStage.COOKED and cook_points_in_stage >= max(1, points_to_burnt):
		set_cook_stage(CookStage.BURNT)

func set_cook_stage(stage: int) -> void:
	if cook_stage == stage:
		return

	cook_stage = stage
	cook_points_in_stage = 0
	_update_texture()

func is_burnt() -> bool:
	return cook_stage == CookStage.BURNT

func _update_texture() -> void:
	if hamburger_image == null:
		return

	match cook_stage:
		CookStage.RAW:
			hamburger_image.texture = raw_texture
		CookStage.COOKED:
			hamburger_image.texture = cooked_texture
		CookStage.BURNT:
			hamburger_image.texture = burnt_texture
