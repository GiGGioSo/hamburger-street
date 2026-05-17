class_name SnapSlotComponent
extends Area2D

signal item_snapped(item: Node2D, slot: SnapSlotComponent)
signal item_released(item: Node2D, slot: SnapSlotComponent)

@export var accepted_group := ""
@export var snap_offset := Vector2.ZERO

var current_item: Node2D = null
var current_drag_component: DraggableComponent = null

func _ready() -> void:
	add_to_group("snap_slot")

func can_accept(item: Node2D) -> bool:
	_clear_stale_item()

	if current_item != null:
		return false

	if accepted_group != "" and not item.is_in_group(accepted_group):
		return false

	return true

func snap(item: Node2D) -> void:
	_release_current_item()

	current_item = item

	current_drag_component = item.get_node_or_null("DraggableComponent") as DraggableComponent
	if current_drag_component:
		current_drag_component.mark_drop_accepted()

	if current_drag_component and not current_drag_component.drag_started.is_connected(_on_current_item_drag_started):
		current_drag_component.drag_started.connect(_on_current_item_drag_started)

	item.reparent(self)
	item.position = snap_offset
	item_snapped.emit(item, self)

func restore_dragged_item(item: Node2D) -> bool:
	if not can_accept(item):
		return false

	snap(item)
	return true

func _clear_stale_item() -> void:
	if current_item == null:
		return

	if not is_instance_valid(current_item) or current_item.get_parent() != self:
		_release_current_item()

func _release_current_item() -> void:
	var released_item: Node2D = current_item

	if is_instance_valid(current_drag_component) and current_drag_component.drag_started.is_connected(_on_current_item_drag_started):
		current_drag_component.drag_started.disconnect(_on_current_item_drag_started)

	current_item = null
	current_drag_component = null

	if is_instance_valid(released_item):
		item_released.emit(released_item, self)

func _on_current_item_drag_started(item: Node2D, _drag_component: DraggableComponent) -> void:
	if item == current_item:
		_release_current_item()
