class_name GameController
extends Node2D

const INGREDIENT_TEXTURES := {
	"bottom_bun": preload("res://textures/cooking/hamburger_bun_base.png"),
	"patty": preload("res://textures/cooking/hamburger_patty_well_done.png"),
	"top_bun": preload("res://textures/cooking/hamburger_bun_top.png"),
	"lettuce": preload("res://textures/cooking/hamburger_lattuce.png"),
	"tomato": preload("res://textures/cooking/hamburger_tomato.png"),
	"onion": preload("res://textures/cooking/hamburger_onions.png"),
	"cheese": preload("res://textures/cooking/hamburger_cheese.png"),
	"ketchup": preload("res://textures/cooking/hamburger_ketchup.png"),
	"majo": preload("res://textures/cooking/hamburger_majo.png"),
	"senf": preload("res://textures/cooking/hamburger_senf.png"),
}

const OPTIONAL_INGREDIENTS := [
	&"lettuce",
	&"tomato",
	&"onion",
	&"cheese",
	&"ketchup",
	&"majo",
	&"senf",
]

@export var customer_spawn_chance := 0.3
@export var max_active_orders := 5
@export var red_countdown_seconds := 3.0
@export var max_discarded_hamburgers := 5

@onready var cooking: CookingScene = $Cooking as CookingScene
@onready var customers: CustomersScene = $Customers as CustomersScene
@onready var red_light: Node2D = $RedLight as Node2D
@onready var green_light: Node2D = $"Green Light" as Node2D
@onready var semaphore_area: Area2D = $SemaphoreArea as Area2D
@onready var countdown_label: Label = $CountdownLabel as Label
@onready var score_label: Label = $ScoreLabel as Label
@onready var game_over_image: Sprite2D = $GameOverImage as Sprite2D

var active_orders: Array[Dictionary] = []
var completed_orders: Array[Dictionary] = []
var score := 0
var discarded_hamburgers := 0
var is_red_light := false
var is_game_over := false
var red_countdown_remaining := 0.0
var next_order_id := 1
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("game_controller")
	rng.randomize()

	green_light.position = red_light.position
	green_light.scale = red_light.scale

	if not semaphore_area.input_event.is_connected(_on_semaphore_input_event):
		semaphore_area.input_event.connect(_on_semaphore_input_event)

	cooking.setup_game(self)
	customers.setup_game(self)
	customers.spawn_chance = customer_spawn_chance

	if not customers.customer_spawned.is_connected(_on_customer_spawned):
		customers.customer_spawned.connect(_on_customer_spawned)

	if not customers.all_customers_finished.is_connected(_on_all_customers_finished):
		customers.all_customers_finished.connect(_on_all_customers_finished)

	_show_cooking()
	_set_red_light(false)
	_update_ui()

func _process(delta: float) -> void:
	if red_countdown_remaining <= 0.0 or is_game_over:
		return

	red_countdown_remaining = max(0.0, red_countdown_remaining - delta)
	countdown_label.text = str(ceil(red_countdown_remaining))

	if red_countdown_remaining <= 0.0:
		countdown_label.visible = false
		_set_red_light(true)
		customers.stop_spawning_after_red()
		if customers.is_idle():
			_on_all_customers_finished()

func create_random_order(customer_type: String) -> Dictionary:
	var middle: Array[StringName] = [&"patty"]
	for ingredient_variant in OPTIONAL_INGREDIENTS:
		var ingredient: StringName = ingredient_variant
		if rng.randf() < 0.5:
			middle.append(ingredient)

	_shuffle_array(middle)

	var ingredients: Array[StringName] = [&"bottom_bun"]
	ingredients.append_array(middle)
	ingredients.append(&"top_bun")

	var order: Dictionary = {
		"id": next_order_id,
		"customer_type": customer_type,
		"ingredients": ingredients,
		"total_ingredient_count": OPTIONAL_INGREDIENTS.size() + 3,
	}
	next_order_id += 1
	return order

func add_order(order: Dictionary) -> void:
	active_orders.append(order)
	_refresh_orders()

func complete_order(order_id: int, points: int) -> void:
	for index in range(active_orders.size()):
		var order: Dictionary = active_orders[index]
		if int(order.get("id", -1)) != order_id:
			continue

		active_orders.remove_at(index)
		completed_orders.append(order)
		score += points
		_refresh_orders()
		_update_ui()
		return

func report_successful_interaction(_source: Node = null) -> void:
	if is_red_light and not is_game_over:
		_trigger_game_over()

func report_hamburger_discarded() -> void:
	if is_game_over:
		return

	discarded_hamburgers += 1
	_update_ui()

	if discarded_hamburgers >= max_discarded_hamburgers:
		_trigger_game_over()

func get_ingredient_texture(ingredient_id: StringName) -> Texture2D:
	return INGREDIENT_TEXTURES.get(String(ingredient_id)) as Texture2D

func _on_customer_spawned() -> void:
	if red_countdown_remaining > 0.0 or is_red_light:
		return

	red_countdown_remaining = red_countdown_seconds
	countdown_label.text = str(ceil(red_countdown_remaining))
	countdown_label.visible = true

func _on_all_customers_finished() -> void:
	_set_red_light(false)

func _on_semaphore_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_game_over:
		return

	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	if cooking.visible and not is_red_light:
		_show_customers()
	elif customers.visible and not is_red_light and customers.is_idle():
		_show_cooking()

func _show_cooking() -> void:
	cooking.visible = true
	customers.visible = false
	customers.stop_session()
	_refresh_orders()

func _show_customers() -> void:
	cooking.visible = false
	customers.visible = true
	customers.start_session()

func _set_red_light(enabled: bool) -> void:
	is_red_light = enabled
	red_light.visible = enabled
	green_light.visible = not enabled

func _refresh_orders() -> void:
	if cooking:
		cooking.refresh_orders(active_orders.slice(0, 3))

func _update_ui() -> void:
	score_label.text = "Score: %d" % score
	cooking.set_discard_counter(discarded_hamburgers, max_discarded_hamburgers)

func _trigger_game_over() -> void:
	is_game_over = true
	countdown_label.visible = false
	game_over_image.visible = true

func _shuffle_array(values: Array[StringName]) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var value: StringName = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value
