class_name CustomersScene
extends Node2D

signal customer_spawned
signal all_customers_finished

@export var customer_scene: PackedScene = preload("res://scenes/customer.tscn")
@export var spawn_chance := 0.3
@export var spawn_interval := 1.0
@export var customer_positions: Array[Vector2] = [
	Vector2(170, 390),
	Vector2(500, 375),
]

var game: Node = null
var spawn_elapsed := 0.0
var session_active := false
var spawner_enabled := false
var active_customers: Array[Customer] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func setup_game(game_ref: Node) -> void:
	game = game_ref

func start_session() -> void:
	session_active = true
	spawner_enabled = true
	spawn_elapsed = 0.0

func stop_session() -> void:
	session_active = false
	spawner_enabled = false
	spawn_elapsed = 0.0

func stop_spawning_after_red() -> void:
	spawner_enabled = false

func is_idle() -> bool:
	return active_customers.is_empty()

func _process(delta: float) -> void:
	if not session_active or not spawner_enabled or game == null:
		return

	if bool(game.get("is_red_light")):
		spawner_enabled = false
		return

	if _active_request_count() >= int(game.get("max_active_orders")):
		return

	spawn_elapsed += delta
	while spawn_elapsed >= spawn_interval:
		spawn_elapsed -= spawn_interval
		_try_spawn_customer()

func _try_spawn_customer() -> void:
	if rng.randf() > spawn_chance:
		return

	if _active_request_count() >= int(game.get("max_active_orders")):
		return

	var order: Dictionary = game.call("create_random_order", _random_customer_type()) as Dictionary
	var customer: Customer = customer_scene.instantiate() as Customer
	add_child(customer)
	customer.position = customer_positions[rng.randi_range(0, customer_positions.size() - 1)]
	customer.setup(order, game)
	active_customers.append(customer)

	if not customer.order_ready.is_connected(_on_customer_order_ready):
		customer.order_ready.connect(_on_customer_order_ready)

	if not customer.finished.is_connected(_on_customer_finished):
		customer.finished.connect(_on_customer_finished)

	customer_spawned.emit()

func _on_customer_order_ready(order: Dictionary) -> void:
	game.call("add_order", order)

func _on_customer_finished(customer: Customer) -> void:
	active_customers.erase(customer)
	if active_customers.is_empty() and bool(game.get("is_red_light")):
		all_customers_finished.emit()

func _active_request_count() -> int:
	var orders: Array = game.get("active_orders") as Array
	return active_customers.size() + orders.size()

func _random_customer_type() -> String:
	return "speckle" if rng.randi_range(0, 1) == 0 else "tuca"
