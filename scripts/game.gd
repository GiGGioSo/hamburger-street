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

const BIN_SOUND: AudioStream = preload("res://music/bin.mp3")
const COIN_VICTORY_SOUND: AudioStream = preload("res://music/coin_victory.mp3")
const FULL_BLOW_VICTORY_SOUND: AudioStream = preload("res://music/full_blow_of_victory.mp3")
const GAME_OVER_SOUND: AudioStream = preload("res://music/game_over.mp3")
const KRANKENWAGEN_SOUND: AudioStream = preload("res://music/krankenwagen.mp3")
const BACKGROUND_MUSIC: AudioStream = preload("res://music/final.mp3")
const SPIN_WIND_SOUND: AudioStream = preload("res://music/spin_wind.mp3")
const CUSTOMERS_SOUND: AudioStream = preload("res://music/customers.mp3")
const SGATARRATA_SOUND: AudioStream = preload("res://music/sgatarrata.mp3")
const NICE_1_SOUND: AudioStream = preload("res://music/nice1.mp3")
const NICE_2_SOUND: AudioStream = preload("res://music/nice2.mp3")
const NICE_3_SOUND: AudioStream = preload("res://music/nice3.mp3")
const BIN_SOUND_VOLUME_DB := 0.0
const COIN_VICTORY_SOUND_VOLUME_DB := 6.0
const FULL_BLOW_VICTORY_SOUND_VOLUME_DB := 6.0
const GAME_OVER_SOUND_VOLUME_DB := 0.0
const KRANKENWAGEN_SOUND_VOLUME_DB := 0.0
const BACKGROUND_MUSIC_VOLUME_DB := -14.0
const SPIN_WIND_SOUND_VOLUME_DB := 0.0
const CUSTOMERS_SOUND_VOLUME_DB := 0.0
const SGATARRATA_SOUND_VOLUME_DB := 0.0
const NICE_1_SOUND_VOLUME_DB := 2.0
const NICE_2_SOUND_VOLUME_DB := 2.0
const NICE_3_SOUND_VOLUME_DB := 2.0
const PRELOADED_MUSIC: Array[AudioStream] = [
	BIN_SOUND,
	COIN_VICTORY_SOUND,
	FULL_BLOW_VICTORY_SOUND,
	GAME_OVER_SOUND,
	KRANKENWAGEN_SOUND,
	BACKGROUND_MUSIC,
	SPIN_WIND_SOUND,
	CUSTOMERS_SOUND,
	SGATARRATA_SOUND,
	NICE_1_SOUND,
	NICE_2_SOUND,
	NICE_3_SOUND,
]

static var session_best_score: int = 0

@export var max_active_orders := 5
@export var red_countdown_seconds := 3.0
@export var max_discarded_hamburgers := 5
@export var min_order_processing_seconds := 30.0
@export var max_order_processing_seconds := 75.0
@export var score_for_min_order_processing_seconds := 20
@export var game_over_scene: PackedScene = preload("res://scenes/game_over.tscn")

@onready var cooking: CookingScene = $Cooking as CookingScene
@onready var customers: CustomersScene = $Customers as CustomersScene
@onready var red_light: Node2D = $RedLight as Node2D
@onready var green_light: Node2D = $"Green Light" as Node2D
@onready var semaphore_area: Area2D = $SemaphoreArea as Area2D
@onready var countdown_background: ColorRect = $CountdownBackground as ColorRect
@onready var countdown_label: Label = $CountdownLabel as Label
@onready var score_label: Label = $ScoreLabel as Label
@onready var game_over_image: Sprite2D = $GameOverImage as Sprite2D

var active_orders: Array[Dictionary] = []
var completed_orders: Array[Dictionary] = []
var timed_orders: Array[Dictionary] = []
var score := 0
var discarded_hamburgers := 0
var is_red_light := false
var is_game_over := false
var red_countdown_remaining := 0.0
var game_elapsed_seconds := 0.0
var next_order_id := 1
var rng := RandomNumberGenerator.new()
var game_over_overlay: Control = null
var game_over_layer: CanvasLayer = null
var background_music_player: AudioStreamPlayer = null

func _ready() -> void:
	add_to_group("game_controller")
	rng.randomize()
	_prime_music_cache()
	_start_background_music()

	green_light.position = red_light.position
	green_light.scale = red_light.scale

	if not semaphore_area.input_event.is_connected(_on_semaphore_input_event):
		semaphore_area.input_event.connect(_on_semaphore_input_event)

	cooking.setup_game(self)
	customers.setup_game(self)

	if not customers.customer_spawned.is_connected(_on_customer_spawned):
		customers.customer_spawned.connect(_on_customer_spawned)

	if not customers.all_customers_finished.is_connected(_on_all_customers_finished):
		customers.all_customers_finished.connect(_on_all_customers_finished)

	_set_red_light(false)
	_show_customers()
	_update_ui()

func _process(delta: float) -> void:
	if is_game_over:
		return

	game_elapsed_seconds += delta

	if red_countdown_remaining > 0.0:
		_process_red_countdown(delta)

	_process_order_timers(delta)

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

	var processing_seconds: float = _roll_order_processing_seconds()
	var order: Dictionary = {
		"id": next_order_id,
		"customer_type": customer_type,
		"ingredients": ingredients,
		"total_ingredient_count": OPTIONAL_INGREDIENTS.size() + 3,
		"time_limit_seconds": processing_seconds,
		"time_remaining_seconds": processing_seconds,
		"timer_started_seconds": game_elapsed_seconds,
	}

	next_order_id += 1
	return order

func add_order(order: Dictionary) -> void:
	_update_order_remaining_time(order)
	if _get_order_remaining_seconds(order) <= 0.0:
		_trigger_game_over()
		_refresh_orders()
		return

	active_orders.append(order)
	_refresh_orders()

func start_order_timer(order: Dictionary) -> void:
	var time_limit_seconds: float = float(order.get("time_limit_seconds", _roll_order_processing_seconds()))
	order["time_limit_seconds"] = time_limit_seconds
	order["timer_started_seconds"] = game_elapsed_seconds
	order["time_remaining_seconds"] = time_limit_seconds

	if not _is_order_timer_tracked(int(order.get("id", -1))):
		timed_orders.append(order)

func is_customer_progress_active() -> bool:
	return customers != null and customers.visible and not is_game_over

func complete_order(order_id: int, points: int) -> void:
	for index in range(active_orders.size()):
		var order: Dictionary = active_orders[index]
		if int(order.get("id", -1)) != order_id:
			continue

		active_orders.remove_at(index)
		completed_orders.append(order)
		_remove_tracked_order(order_id)
		score += points
		play_delivery_sound()
		_refresh_orders()
		_update_ui()
		return

func report_successful_interaction(_source: Node = null) -> void:
	if is_red_light and not is_game_over:
		_trigger_game_over()

func report_cooking_action(_source: Node = null) -> bool:
	if cooking != null and cooking.visible and is_red_light and not is_game_over:
		_trigger_game_over()
		return true

	return false

func is_red_light_active() -> bool:
	return is_red_light and not is_game_over

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
	if is_game_over or is_red_light:
		return

	if not cooking.visible:
		_set_red_light(true)
		return

	play_customer_alert_sound()

	if red_countdown_remaining > 0.0:
		return

	red_countdown_remaining = red_countdown_seconds
	countdown_label.text = str(ceil(red_countdown_remaining))
	countdown_background.visible = true
	countdown_label.visible = true

func _on_all_customers_finished() -> void:
	_cancel_red_countdown()
	_set_red_light(false)

func _on_semaphore_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_game_over:
		return

	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	if cooking.visible:
		play_scene_switch_sound()
		_show_customers()
	elif customers.visible and not is_red_light:
		play_scene_switch_sound()
		_show_cooking()

func _show_cooking() -> void:
	cooking.visible = true
	customers.visible = false
	_refresh_orders()

func _show_customers() -> void:
	_cancel_red_countdown()
	cooking.visible = false
	customers.visible = true
	customers.start_session()

func _set_red_light(enabled: bool) -> void:
	is_red_light = enabled
	red_light.visible = enabled
	green_light.visible = not enabled

func _cancel_red_countdown() -> void:
	red_countdown_remaining = 0.0
	countdown_background.visible = false
	countdown_label.visible = false

func _refresh_orders() -> void:
	if cooking:
		var visible_orders: Array[Dictionary] = []
		visible_orders.assign(active_orders)
		visible_orders.sort_custom(_sort_orders_by_remaining_time)
		cooking.refresh_orders(visible_orders.slice(0, 3))

func _update_ui() -> void:
	score_label.text = "Score: %d" % score
	cooking.set_discard_counter(discarded_hamburgers, max_discarded_hamburgers)

func _trigger_game_over() -> void:
	if is_game_over:
		return

	is_game_over = true
	play_game_over_sound()
	countdown_label.visible = false
	countdown_background.visible = false
	game_over_image.visible = false
	session_best_score = maxi(session_best_score, score)
	_show_game_over_overlay()

func _show_game_over_overlay() -> void:
	if game_over_scene == null or game_over_overlay != null:
		return

	game_over_overlay = game_over_scene.instantiate() as Control
	if game_over_overlay == null:
		return

	game_over_layer = CanvasLayer.new()
	game_over_layer.layer = 100
	add_child(game_over_layer)
	game_over_layer.add_child(game_over_overlay)

	if game_over_overlay.has_method("setup_scores"):
		game_over_overlay.call("setup_scores", score, session_best_score)

func _process_red_countdown(delta: float) -> void:
	if not cooking.visible:
		_cancel_red_countdown()
		return

	red_countdown_remaining = maxf(0.0, red_countdown_remaining - delta)
	countdown_label.text = str(ceil(red_countdown_remaining))

	if red_countdown_remaining <= 0.0:
		countdown_background.visible = false
		countdown_label.visible = false
		_set_red_light(true)

		if customers.is_idle():
			_on_all_customers_finished()

func _process_order_timers(_delta: float) -> void:
	if timed_orders.is_empty():
		return

	for index in range(timed_orders.size() - 1, -1, -1):
		var order: Dictionary = timed_orders[index]
		_update_order_remaining_time(order)
		timed_orders[index] = order

		if _get_order_remaining_seconds(order) <= 0.0:
			_trigger_game_over()
			_refresh_orders()
			return

	if not active_orders.is_empty():
		_refresh_orders()

func _roll_order_processing_seconds() -> float:
	var score_factor := 0.0
	if score_for_min_order_processing_seconds > 0:
		score_factor = clamp(float(score) / float(score_for_min_order_processing_seconds), 0.0, 1.0)

	var current_max_seconds: float = lerpf(max_order_processing_seconds, min_order_processing_seconds, score_factor)
	var upper_bound: float = maxf(min_order_processing_seconds, current_max_seconds)
	return rng.randf_range(min_order_processing_seconds, upper_bound)

func _sort_orders_by_remaining_time(left: Dictionary, right: Dictionary) -> bool:
	var left_remaining: float = _get_order_remaining_seconds(left)
	var right_remaining: float = _get_order_remaining_seconds(right)
	return left_remaining < right_remaining

func _get_order_remaining_seconds(order: Dictionary) -> float:
	return float(order.get("time_remaining_seconds", order.get("time_limit_seconds", 0.0)))

func _update_order_remaining_time(order: Dictionary) -> void:
	var time_limit_seconds: float = float(order.get("time_limit_seconds", 0.0))
	var timer_started_seconds: float = float(order.get("timer_started_seconds", game_elapsed_seconds))
	var elapsed_seconds: float = maxf(0.0, game_elapsed_seconds - timer_started_seconds)
	order["time_remaining_seconds"] = maxf(0.0, time_limit_seconds - elapsed_seconds)

func _is_order_timer_tracked(order_id: int) -> bool:
	for order in timed_orders:
		if int(order.get("id", -1)) == order_id:
			return true

	return false

func _remove_tracked_order(order_id: int) -> void:
	for index in range(timed_orders.size() - 1, -1, -1):
		var order: Dictionary = timed_orders[index]
		if int(order.get("id", -1)) == order_id:
			timed_orders.remove_at(index)
			return

func _prime_music_cache() -> void:
	var preloaded_music_count: int = PRELOADED_MUSIC.size()
	if preloaded_music_count == 0:
		push_warning("No music streams are preloaded.")

func _start_background_music() -> void:
	if BACKGROUND_MUSIC == null:
		return

	background_music_player = AudioStreamPlayer.new()
	background_music_player.stream = _make_looping_stream(BACKGROUND_MUSIC)
	background_music_player.volume_db = BACKGROUND_MUSIC_VOLUME_DB
	add_child(background_music_player)
	background_music_player.play()

func _make_looping_stream(stream: AudioStream) -> AudioStream:
	var looping_stream: AudioStream = stream.duplicate() as AudioStream
	if looping_stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = looping_stream as AudioStreamMP3
		mp3_stream.loop = true

	return looping_stream

func play_bin_sound() -> void:
	_play_sound(BIN_SOUND, BIN_SOUND_VOLUME_DB)

func play_customer_alert_sound() -> void:
	var sound_index: int = rng.randi_range(0, 1)
	if sound_index == 0:
		_play_sound(CUSTOMERS_SOUND, CUSTOMERS_SOUND_VOLUME_DB)
	else:
		_play_sound(SGATARRATA_SOUND, SGATARRATA_SOUND_VOLUME_DB)

func play_delivery_sound() -> void:
	_play_sound(COIN_VICTORY_SOUND, COIN_VICTORY_SOUND_VOLUME_DB)
	_play_sound(FULL_BLOW_VICTORY_SOUND, FULL_BLOW_VICTORY_SOUND_VOLUME_DB)

func play_game_over_sound() -> void:
	_play_sound(GAME_OVER_SOUND, GAME_OVER_SOUND_VOLUME_DB)
	_play_sound(KRANKENWAGEN_SOUND, KRANKENWAGEN_SOUND_VOLUME_DB)

func play_snap_sound() -> void:
	var sound_index: int = rng.randi_range(0, 2)
	if sound_index == 0:
		_play_sound(NICE_1_SOUND, NICE_1_SOUND_VOLUME_DB)
	elif sound_index == 1:
		_play_sound(NICE_2_SOUND, NICE_2_SOUND_VOLUME_DB)
	else:
		_play_sound(NICE_3_SOUND, NICE_3_SOUND_VOLUME_DB)

func play_scene_switch_sound() -> void:
	_play_sound(SPIN_WIND_SOUND, SPIN_WIND_SOUND_VOLUME_DB)

func _play_sound(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)

	var cleanup: Callable = Callable(player, "queue_free")
	if not player.finished.is_connected(cleanup):
		player.finished.connect(cleanup)

	player.play()

func _shuffle_array(values: Array[StringName]) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var value: StringName = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value
