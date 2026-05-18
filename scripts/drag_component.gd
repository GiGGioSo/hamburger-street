class_name DraggableComponent
extends Area2D

signal drag_started(item: Node2D, drag_component: DraggableComponent)
signal drag_ended(item: Node2D, drag_component: DraggableComponent)

enum FailedDropBehavior {
	RETURN_TO_ORIGIN,
	DESPAWN,
}

static var active_drag_component: DraggableComponent = null

@export var target: Node2D
@export var visual_target: Node2D
@export var drag_scale := 1.1
@export var drag_parent: Node
@export var failed_drop_behavior := FailedDropBehavior.RETURN_TO_ORIGIN

var dragging := false
var drag_enabled := true
var drop_accepted := false
var grab_offset := Vector2.ZERO

var original_visual_scale := Vector2.ONE
var drag_origin_parent: Node = null
var drag_origin_global_position := Vector2.ZERO
var drag_origin_z_index := 0

func _ready() -> void:
	add_to_group("draggable_component")
	input_pickable = true

	if target == null:
		target = get_parent() as Node2D

	if visual_target == null:
		visual_target = target

	if drag_parent == null:
		drag_parent = get_tree().current_scene

	if visual_target:
		original_visual_scale = visual_target.scale

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)

	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func _input_event(_viewport, event, _shape_idx) -> void:
	if not target or not drag_enabled:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_drag()
		else:
			_end_drag()

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()

func _process(_delta: float) -> void:
	if dragging and target:
		target.global_position = get_global_mouse_position() + grab_offset

func start_drag() -> void:
	if dragging or not drag_enabled:
		return

	if is_drag_active() and active_drag_component != self:
		return

	var game: Node = get_tree().get_first_node_in_group("game_controller")
	if game and game.has_method("report_cooking_action") and bool(game.call("report_cooking_action", target)):
		return

	if target == null:
		target = get_parent() as Node2D

	if visual_target == null:
		visual_target = target

	if drag_parent == null:
		drag_parent = get_tree().current_scene

	_start_drag()

func _start_drag() -> void:
	if not target:
		return

	dragging = true
	active_drag_component = self
	drop_accepted = false
	drag_origin_parent = target.get_parent()
	drag_origin_global_position = target.global_position
	drag_origin_z_index = target.z_index

	set_visual_scaled(false)

	if target.get_parent() != drag_parent:
		target.reparent(drag_parent, true)

	grab_offset = target.global_position - get_global_mouse_position()

	set_visual_scaled(true)
	target.z_index = 100

	drag_started.emit(target, self)

func _end_drag() -> void:
	if not dragging:
		return

	dragging = false
	if active_drag_component == self:
		active_drag_component = null

	set_visual_scaled(false)
	target.z_index = drag_origin_z_index

	drag_ended.emit(target, self)

	if not drop_accepted and is_instance_valid(target):
		_handle_failed_drop()

func set_drag_enabled(enabled: bool) -> void:
	drag_enabled = enabled
	input_pickable = enabled

	if not enabled and not dragging:
		set_visual_scaled(false)

func mark_drop_accepted() -> void:
	if drop_accepted:
		return

	drop_accepted = true
	var game: Node = get_tree().get_first_node_in_group("game_controller")
	if game and game.has_method("report_successful_interaction"):
		game.call("report_successful_interaction", target)

func is_drop_accepted() -> bool:
	return drop_accepted

func return_to_drag_origin() -> void:
	if not is_instance_valid(target):
		return

	if is_instance_valid(drag_origin_parent) and target.get_parent() != drag_origin_parent:
		target.reparent(drag_origin_parent, true)

	target.global_position = drag_origin_global_position
	target.z_index = drag_origin_z_index

static func is_drag_active() -> bool:
	return is_instance_valid(active_drag_component) and active_drag_component.dragging

func _handle_failed_drop() -> void:
	if _restore_to_origin_slot():
		return

	match failed_drop_behavior:
		FailedDropBehavior.RETURN_TO_ORIGIN:
			return_to_drag_origin()
		FailedDropBehavior.DESPAWN:
			target.queue_free()

func _restore_to_origin_slot() -> bool:
	if not is_instance_valid(drag_origin_parent):
		return false

	if not drag_origin_parent.has_method("restore_dragged_item"):
		return false

	var restored: bool = bool(drag_origin_parent.call("restore_dragged_item", target))
	if restored:
		mark_drop_accepted()

	return restored

func set_visual_scaled(enabled: bool) -> void:
	if not visual_target:
		return

	if enabled:
		visual_target.scale = original_visual_scale * drag_scale
	else:
		visual_target.scale = original_visual_scale

func _on_mouse_entered() -> void:
	if not target or dragging or not drag_enabled:
		return

	if is_drag_active() and active_drag_component != self:
		return

	set_visual_scaled(true)

func _on_mouse_exited() -> void:
	if not target or dragging:
		return

	set_visual_scaled(false)
