class_name Customer
extends Node2D

signal order_ready(order: Dictionary)
signal finished(customer: Customer)

const TUCA_BODY := preload("res://textures/costumer_tuca.png")
const TUCA_CLOSED := preload("res://textures/tuca_closed_mouth.png")
const TUCA_OPEN := preload("res://textures/tuca_open_mouth.png")
const SPECKLE_BODY := preload("res://textures/costumer_speckle.png")
const SPECKLE_CLOSED := preload("res://textures/speckle_closed_mouth.png")
const SPECKLE_OPEN := preload("res://textures/speckle_open_mouth.png")

@export var min_speaking_seconds := 2.0
@export var max_speaking_seconds := 5.0
@export var final_view_seconds := 1.0
@export var ingredient_icon_width := 72.0
@export var ingredient_offset := Vector2(0, -13)

@onready var body_image: Sprite2D = $BodyImage as Sprite2D
@onready var closed_mouth_image: Sprite2D = $ClosedMouthImage as Sprite2D
@onready var open_mouth_image: Sprite2D = $OpenMouthImage as Sprite2D
@onready var order_items: Node2D = $OrderChat/OrderItems as Node2D
@onready var progress_bar: ProgressBar = $OrderChat/ProgressBar as ProgressBar

var game: Node = null
var order: Dictionary = {}
var speaking_seconds := 2.0
var elapsed := 0.0
var order_sent := false

func setup(order_data: Dictionary, game_ref: Node) -> void:
	order = order_data
	game = game_ref
	elapsed = 0.0
	order_sent = false

	_apply_customer_textures(String(order.get("customer_type", "tuca")))
	_setup_speaking_duration()
	_render_order_items()
	_set_visible_ingredient_count(0)
	progress_bar.value = 0.0

func _process(delta: float) -> void:
	if order.is_empty():
		return

	elapsed += delta
	var speaking_progress: float = clamp(elapsed / max(0.01, speaking_seconds), 0.0, 1.0)
	progress_bar.value = speaking_progress * 100.0

	var ingredients: Array = order.get("ingredients", []) as Array
	var visible_count := int(floor(speaking_progress * ingredients.size()))
	if speaking_progress >= 1.0:
		visible_count = ingredients.size()
	_set_visible_ingredient_count(visible_count)

	var mouth_open := elapsed < speaking_seconds and int(elapsed * 6.0) % 2 == 0
	open_mouth_image.visible = mouth_open
	closed_mouth_image.visible = not mouth_open

	if not order_sent and elapsed >= speaking_seconds + final_view_seconds:
		order_sent = true
		order_ready.emit(order)
		finished.emit(self)
		queue_free()

func _apply_customer_textures(customer_type: String) -> void:
	if customer_type == "speckle":
		body_image.texture = SPECKLE_BODY
		closed_mouth_image.texture = SPECKLE_CLOSED
		open_mouth_image.texture = SPECKLE_OPEN
		closed_mouth_image.position = Vector2(-49, -55)
		open_mouth_image.position = Vector2(-49, -55)
	else:
		body_image.texture = TUCA_BODY
		closed_mouth_image.texture = TUCA_CLOSED
		open_mouth_image.texture = TUCA_OPEN
		closed_mouth_image.position = Vector2(36, -32)
		open_mouth_image.position = Vector2(36, -32)

func _setup_speaking_duration() -> void:
	var total_ingredients: int = int(order.get("total_ingredient_count", 10))
	var ingredients: Array = order.get("ingredients", []) as Array
	var ingredient_count := ingredients.size()
	var t := 0.0
	if total_ingredients > 3:
		t = clamp(float(ingredient_count - 3) / float(total_ingredients - 3), 0.0, 1.0)

	speaking_seconds = lerpf(min_speaking_seconds, max_speaking_seconds, t)

func _render_order_items() -> void:
	for child in order_items.get_children():
		child.queue_free()

	if game == null:
		return

	var ingredients: Array = order.get("ingredients", []) as Array
	for index in range(ingredients.size()):
		var ingredient_id: StringName = StringName(ingredients[index])
		var texture: Texture2D = game.call("get_ingredient_texture", ingredient_id) as Texture2D
		if texture == null:
			continue

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = ingredient_offset * index
		sprite.z_index = index
		var scale_value: float = ingredient_icon_width / max(1.0, float(texture.get_width()))
		sprite.scale = Vector2(scale_value, scale_value)
		order_items.add_child(sprite)

func _set_visible_ingredient_count(count: int) -> void:
	for index in range(order_items.get_child_count()):
		order_items.get_child(index).visible = index < count
