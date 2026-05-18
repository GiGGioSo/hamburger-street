class_name BinSlot
extends Area2D

@export var accepted_groups: PackedStringArray = PackedStringArray(["hamburger", "dressing_item", "top_bun", "completed_burger"])
@export var hover_scale := Vector2(1.1, 1.1)

@onready var count_label: Label = $CountLabel as Label

var connected_drag_components: Array[DraggableComponent] = []
var original_scale := Vector2.ONE

func _ready() -> void:
	add_to_group("bin_slot")
	input_pickable = true
	original_scale = scale

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)

	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	_connect_existing_drag_components()

	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)

	for drag in connected_drag_components.duplicate():
		if is_instance_valid(drag) and drag.drag_ended.is_connected(_on_drag_ended):
			drag.drag_ended.disconnect(_on_drag_ended)

	connected_drag_components.clear()

func _connect_existing_drag_components() -> void:
	for node in get_tree().get_nodes_in_group("draggable_component"):
		var drag: DraggableComponent = node as DraggableComponent
		if drag:
			_connect_drag_component(drag)

func _on_tree_node_added(node: Node) -> void:
	call_deferred("_connect_draggable_node", node)

func _connect_draggable_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	var drag: DraggableComponent = node as DraggableComponent
	if drag == null:
		drag = _find_drag_component(node)

	if drag:
		_connect_drag_component(drag)

func _connect_drag_component(drag: DraggableComponent) -> void:
	if connected_drag_components.has(drag):
		return

	if not drag.drag_ended.is_connected(_on_drag_ended):
		drag.drag_ended.connect(_on_drag_ended)

	connected_drag_components.append(drag)

func _on_drag_ended(item: Node2D, drag: DraggableComponent) -> void:
	if drag.is_drop_accepted() or not _can_delete(item):
		return

	for area in drag.get_overlapping_areas():
		var bin: BinSlot = area as BinSlot
		if bin != self:
			continue

		var game: Node = get_tree().get_first_node_in_group("game_controller")
		if game and game.has_method("play_bin_sound"):
			game.call("play_bin_sound")

		if _counts_as_hamburger_discard(item):
			if game and game.has_method("report_hamburger_discarded"):
				game.call("report_hamburger_discarded")

		drag.mark_drop_accepted()
		item.queue_free()
		return

func _can_delete(item: Node2D) -> bool:
	if item == null or item.is_in_group("sauce_bottle"):
		return false

	for group_name_variant in accepted_groups:
		var group_name: StringName = StringName(group_name_variant)
		if item.is_in_group(group_name):
			return true

	return false

func set_discard_count(discarded_count: int, max_discarded: int) -> void:
	var remaining: int = maxi(0, max_discarded - discarded_count)
	count_label.text = str(remaining)

func _on_mouse_entered() -> void:
	scale = original_scale * hover_scale

func _on_mouse_exited() -> void:
	scale = original_scale

func _counts_as_hamburger_discard(item: Node2D) -> bool:
	return item.is_in_group("hamburger") or item.is_in_group("completed_burger")

func _find_drag_component(node: Node) -> DraggableComponent:
	var drag: DraggableComponent = node as DraggableComponent
	if drag:
		return drag

	for child in node.get_children():
		drag = _find_drag_component(child)
		if drag:
			return drag

	return null
