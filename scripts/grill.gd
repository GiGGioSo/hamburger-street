extends Node2D

@export var default_seconds_per_cook_point := 1.0
@export var slot_seconds_per_cook_point: Array[float] = []

@onready var slots: Node = $HamburgerGrillSlots

var grill_slots := []
var cooking_hamburgers := {}
var cooking_elapsed := {}
var connected_hamburgers := []

func _ready() -> void:
	_connect_grill_slots()

	for hamburger in get_tree().get_nodes_in_group("hamburger"):
		_connect_hamburger_drag(hamburger)

	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)

	for hamburger in connected_hamburgers.duplicate():
		if not is_instance_valid(hamburger):
			continue

		var drag: DraggableComponent = hamburger.get_node_or_null("DraggableComponent") as DraggableComponent
		if drag and drag.drag_ended.is_connected(_on_hamburger_dropped):
			drag.drag_ended.disconnect(_on_hamburger_dropped)

func _process(delta: float) -> void:
	var game: Node = get_tree().get_first_node_in_group("game_controller")

	for slot in cooking_hamburgers.keys():
		if not is_instance_valid(slot):
			cooking_hamburgers.erase(slot)
			cooking_elapsed.erase(slot)
			continue

		var hamburger: Hamburger = cooking_hamburgers.get(slot) as Hamburger
		if not is_instance_valid(hamburger):
			_stop_cooking(slot)
			continue

		if hamburger.get_parent() != slot:
			_stop_cooking(slot)
			continue

		if _is_red_light_active(game):
			game.call("report_successful_interaction", self)
			return

		var seconds_per_cook_point := _get_seconds_per_cook_point(slot)
		var elapsed: float = float(cooking_elapsed.get(slot, 0.0)) + delta

		while elapsed >= seconds_per_cook_point:
			elapsed -= seconds_per_cook_point
			hamburger.add_cook_point()

		cooking_elapsed[slot] = elapsed

func _on_hamburger_dropped(hamburger: Node2D, drag: DraggableComponent) -> void:
	if drag.is_drop_accepted():
		return

	for area in drag.get_overlapping_areas():
		var slot: SnapSlotComponent = area as SnapSlotComponent

		if slot and grill_slots.has(slot) and slot.can_accept(hamburger):
			slot.snap(hamburger)
			return

func _connect_hamburger_drag(hamburger: Node) -> void:
	if connected_hamburgers.has(hamburger):
		return

	var drag: DraggableComponent = hamburger.get_node_or_null("DraggableComponent") as DraggableComponent
	if drag == null:
		push_warning("Hamburger is missing a DraggableComponent: %s" % hamburger.get_path())
		return

	if not drag.drag_ended.is_connected(_on_hamburger_dropped):
		drag.drag_ended.connect(_on_hamburger_dropped)

	connected_hamburgers.append(hamburger)

func _on_tree_node_added(node: Node) -> void:
	call_deferred("_connect_hamburger_if_ready", node)

func _connect_hamburger_if_ready(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_in_group("hamburger"):
		return

	_connect_hamburger_drag(node)

func _connect_grill_slots() -> void:
	for slot_container in slots.get_children():
		var slot: SnapSlotComponent = slot_container as SnapSlotComponent
		if slot == null:
			slot = slot_container.get_node_or_null("SnapSlotComponent") as SnapSlotComponent

		if slot == null:
			continue

		grill_slots.append(slot)

		if not slot.item_snapped.is_connected(_on_slot_item_snapped):
			slot.item_snapped.connect(_on_slot_item_snapped)

		if not slot.item_released.is_connected(_on_slot_item_released):
			slot.item_released.connect(_on_slot_item_released)

func _on_slot_item_snapped(item: Node2D, slot: SnapSlotComponent) -> void:
	var hamburger: Hamburger = item as Hamburger
	if hamburger == null:
		return

	cooking_hamburgers[slot] = hamburger
	cooking_elapsed[slot] = 0.0

func _on_slot_item_released(item: Node2D, slot: SnapSlotComponent) -> void:
	if cooking_hamburgers.get(slot) == item:
		_stop_cooking(slot)

func _stop_cooking(slot: SnapSlotComponent) -> void:
	cooking_hamburgers.erase(slot)
	cooking_elapsed.erase(slot)

func _get_seconds_per_cook_point(slot: SnapSlotComponent) -> float:
	var seconds := default_seconds_per_cook_point
	var slot_index := grill_slots.find(slot)

	if slot_index >= 0 and slot_index < slot_seconds_per_cook_point.size():
		seconds = slot_seconds_per_cook_point[slot_index]

	return max(0.01, seconds)

func _is_red_light_active(game: Node) -> bool:
	return game != null and bool(game.get("is_red_light")) and not bool(game.get("is_game_over"))
