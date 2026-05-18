class_name BuildingStation
extends Node2D

signal burger_confirmed(slot: BuildingSlotComponent, items: Array)

@export var accepted_groups: PackedStringArray = PackedStringArray(["hamburger", "dressing_item", "top_bun"])
@export var slots_root_path := NodePath("Slots")
@export var completed_burger_scene: PackedScene = preload("res://scenes/completed_burger.tscn")

@onready var slots_root: Node = get_node_or_null(slots_root_path)

var slots: Array[BuildingSlotComponent] = []
var connected_drag_components: Array[DraggableComponent] = []

func _ready() -> void:
	_connect_slots()
	_connect_existing_build_items()

	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)

	for drag in connected_drag_components.duplicate():
		if is_instance_valid(drag) and drag.drag_ended.is_connected(_on_build_item_drag_ended):
			drag.drag_ended.disconnect(_on_build_item_drag_ended)

	connected_drag_components.clear()

func _connect_slots() -> void:
	slots.clear()

	if slots_root == null:
		slots_root = self

	for child in slots_root.get_children():
		var slot: BuildingSlotComponent = child as BuildingSlotComponent
		if slot == null:
			slot = child.get_node_or_null("BuildingSlotComponent") as BuildingSlotComponent

		if slot == null:
			continue

		slots.append(slot)

		if not slot.burger_confirmed.is_connected(_on_slot_burger_confirmed):
			slot.burger_confirmed.connect(_on_slot_burger_confirmed)

func _connect_existing_build_items() -> void:
	for group_name_variant in accepted_groups:
		var group_name: StringName = StringName(group_name_variant)
		for item in get_tree().get_nodes_in_group(group_name):
			_connect_build_item(item)

func _on_tree_node_added(node: Node) -> void:
	call_deferred("_connect_build_item", node)

func _connect_build_item(node: Node) -> void:
	if not is_instance_valid(node):
		return

	var item: Node2D = node as Node2D
	if item == null or not _is_accepted_item(item):
		return

	var drag: DraggableComponent = _find_drag_component(item)
	if drag == null:
		push_warning("Build item is missing a DraggableComponent: %s" % item.get_path())
		return

	if connected_drag_components.has(drag):
		return

	if not drag.drag_ended.is_connected(_on_build_item_drag_ended):
		drag.drag_ended.connect(_on_build_item_drag_ended)

	connected_drag_components.append(drag)

func _on_build_item_drag_ended(item: Node2D, drag: DraggableComponent) -> void:
	if drag.is_drop_accepted():
		return

	if not _is_accepted_item(item):
		return

	for area in drag.get_overlapping_areas():
		var slot: BuildingSlotComponent = area as BuildingSlotComponent
		if slot == null or not slots.has(slot):
			continue

		if slot.snap(item):
			return

func _is_accepted_item(item: Node2D) -> bool:
	for group_name_variant in accepted_groups:
		var group_name: StringName = StringName(group_name_variant)
		if item.is_in_group(group_name):
			return true

	return false

func _on_slot_burger_confirmed(slot: BuildingSlotComponent) -> void:
	if _report_red_light_attempt():
		return

	var ingredient_sequence: Array[StringName] = slot.get_ingredient_sequence()
	var has_burnt_patty: bool = slot.has_burnt_patty()
	var built_items: Array[Node2D] = slot.consume_items_for_completed_burger()

	var completed_burger: CompletedBurger = completed_burger_scene.instantiate() as CompletedBurger
	var burger_parent: Node = get_parent()
	if burger_parent == null:
		burger_parent = get_tree().current_scene

	burger_parent.add_child(completed_burger)
	completed_burger.global_position = slot.global_position
	completed_burger.setup_burger(ingredient_sequence, built_items, has_burnt_patty)

	burger_confirmed.emit(slot, built_items)

func _report_red_light_attempt() -> bool:
	var game: Node = get_tree().get_first_node_in_group("game_controller")
	if game == null or not game.has_method("is_red_light_active"):
		return false

	if not bool(game.call("is_red_light_active")):
		return false

	if game.has_method("report_successful_interaction"):
		game.call("report_successful_interaction", self)

	return true

func _find_drag_component(node: Node) -> DraggableComponent:
	var drag: DraggableComponent = node as DraggableComponent
	if drag:
		return drag

	for child in node.get_children():
		drag = _find_drag_component(child)
		if drag:
			return drag

	return null
