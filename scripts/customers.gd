class_name CustomersScene
extends Node2D

signal customer_spawned
signal all_customers_finished

@export var customer_scene: PackedScene = preload("res://scenes/customer.tscn")
@export var customer_stagger_seconds := 0.8
@export var customer_positions: Array[Vector2] = [
	Vector2(220, 420),
	Vector2(600, 405),
	Vector2(930, 420),
]

var game: Node = null
var session_active := false
var wave_elapsed := 0.0
var next_wave_seconds := 0.0
var stagger_elapsed := 0.0
var active_customers: Array[Customer] = []
var pending_wave_orders: Array[Dictionary] = []
var queued_orders: Array[Dictionary] = []
var slot_customers: Array[Customer] = []
var registered_order_ids: Array[int] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_reset_slots()

func setup_game(game_ref: Node) -> void:
	game = game_ref

func start_session() -> void:
	session_active = true
	if next_wave_seconds <= 0.0:
		_schedule_next_wave()

func stop_session() -> void:
	session_active = false

func stop_spawning_after_red() -> void:
	pass

func is_idle() -> bool:
	return active_customers.is_empty() and pending_wave_orders.is_empty() and queued_orders.is_empty()

func _process(delta: float) -> void:
	if not session_active or game == null:
		return

	if bool(game.get("is_game_over")):
		return

	_try_spawn_queued_customers()
	_process_pending_wave(delta)
	_process_wave_timer(delta)

func _process_wave_timer(delta: float) -> void:
	wave_elapsed += delta

	if wave_elapsed < next_wave_seconds:
		return

	_start_wave()
	_schedule_next_wave()

func _process_pending_wave(delta: float) -> void:
	if pending_wave_orders.is_empty():
		return

	stagger_elapsed += delta
	while stagger_elapsed >= customer_stagger_seconds and not pending_wave_orders.is_empty():
		stagger_elapsed -= customer_stagger_seconds
		var order: Dictionary = pending_wave_orders.pop_front() as Dictionary
		_spawn_or_queue_order(order)

func _start_wave() -> void:
	var available_slots: int = int(game.get("max_active_orders")) - _active_request_count()
	if available_slots <= 0:
		return

	var score_value: int = int(game.get("score"))
	var wave_size: int = rng.randi_range(_get_min_wave_size(score_value), _get_max_wave_size(score_value))
	wave_size = mini(wave_size, available_slots)

	for _index in range(wave_size):
		var order: Dictionary = game.call("create_random_order", _random_customer_type()) as Dictionary
		pending_wave_orders.append(order)

	stagger_elapsed = customer_stagger_seconds
	_process_pending_wave(0.0)

func _spawn_or_queue_order(order: Dictionary) -> void:
	var free_slot_index: int = _get_free_slot_index()

	if free_slot_index == -1:
		queued_orders.append(order)
		return

	_spawn_customer_in_slot(order, free_slot_index)

func _schedule_next_wave() -> void:
	var score_value: int = 0
	if game != null:
		score_value = int(game.get("score"))

	wave_elapsed = 0.0
	next_wave_seconds = rng.randf_range(_get_min_wave_interval(score_value), _get_max_wave_interval(score_value))

func _try_spawn_queued_customers() -> void:
	while not queued_orders.is_empty():
		var free_slot_index: int = _get_free_slot_index()

		if free_slot_index == -1:
			return

		var order: Dictionary = queued_orders.pop_front() as Dictionary
		_spawn_customer_in_slot(order, free_slot_index)

func _spawn_customer_in_slot(order: Dictionary, slot_index: int) -> void:
	var customer: Customer = customer_scene.instantiate() as Customer
	add_child(customer)

	if game.has_method("start_order_timer"):
		game.call("start_order_timer", order)

	customer.position = customer_positions[slot_index]
	customer.setup(order, game)

	active_customers.append(customer)
	slot_customers[slot_index] = customer

	if not customer.order_ready.is_connected(_on_customer_order_ready):
		customer.order_ready.connect(_on_customer_order_ready)

	if not customer.finished.is_connected(_on_customer_finished):
		customer.finished.connect(_on_customer_finished)

	customer_spawned.emit()

func _on_customer_order_ready(order: Dictionary) -> void:
	_register_order(order)

func _on_customer_finished(customer: Customer) -> void:
	_register_order(customer.order)
	active_customers.erase(customer)

	var slot_index: int = slot_customers.find(customer)
	if slot_index != -1:
		slot_customers[slot_index] = null

	_try_spawn_queued_customers()

	if is_idle() and not bool(game.get("is_game_over")):
		all_customers_finished.emit()

func _register_order(order: Dictionary) -> void:
	if order.is_empty():
		return

	var order_id: int = int(order.get("id", -1))
	if registered_order_ids.has(order_id):
		return

	registered_order_ids.append(order_id)
	game.call("add_order", order)

func _active_request_count() -> int:
	var orders: Array = game.get("active_orders") as Array
	return active_customers.size() + pending_wave_orders.size() + queued_orders.size() + orders.size()

func _get_free_slot_index() -> int:
	for index in range(slot_customers.size()):
		if slot_customers[index] == null:
			return index

	return -1

func _reset_slots() -> void:
	slot_customers.clear()

	for _index in range(customer_positions.size()):
		slot_customers.append(null)

func _random_customer_type() -> String:
	return "speckle" if rng.randi_range(0, 1) == 0 else "tuca"

func _get_min_wave_size(score_value: int) -> int:
	if score_value <= 3:
		return 1
	if score_value <= 8:
		return 1
	if score_value <= 15:
		return 2
	return 3

func _get_max_wave_size(score_value: int) -> int:
	if score_value <= 3:
		return 1
	if score_value <= 8:
		return 2
	if score_value <= 15:
		return 3
	return 4

func _get_min_wave_interval(score_value: int) -> float:
	if score_value <= 3:
		return 14.0
	if score_value <= 8:
		return 12.0
	if score_value <= 15:
		return 10.0
	return 8.0

func _get_max_wave_interval(score_value: int) -> float:
	if score_value <= 3:
		return 18.0
	if score_value <= 8:
		return 18.0
	if score_value <= 15:
		return 16.0
	return 14.0
