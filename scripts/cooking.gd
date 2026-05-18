class_name CookingScene
extends Node2D

@export var order_slot_scene: PackedScene = preload("res://scenes/order_slot.tscn")
@export var order_slot_positions: Array[Vector2] = [
	Vector2(46, 115),
	Vector2(46, 315),
	Vector2(46, 515),
]

@onready var bin_slot: BinSlot = $BinSlot as BinSlot

var game: Node = null
var order_slots: Array[OrderSlot] = []

func setup_game(game_ref: Node) -> void:
	game = game_ref
	_ensure_order_slots()
	refresh_orders([])

func refresh_orders(orders: Array) -> void:
	_ensure_order_slots()

	for index in range(order_slots.size()):
		var order: Dictionary = {}
		if index < orders.size():
			order = orders[index] as Dictionary

		order_slots[index].setup_order(order, game)

func set_discard_counter(discarded_count: int, max_discarded: int) -> void:
	if bin_slot and bin_slot.has_method("set_discard_count"):
		bin_slot.set_discard_count(discarded_count, max_discarded)

func _ensure_order_slots() -> void:
	if not order_slots.is_empty():
		return

	for position in order_slot_positions:
		var slot: OrderSlot = order_slot_scene.instantiate() as OrderSlot
		add_child(slot)
		slot.position = position
		order_slots.append(slot)
