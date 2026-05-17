class_name SauceBottle
extends Node2D

@export var sauce_scene: PackedScene
@export var sauce_item_scale := Vector2.ONE
@export var drag_component_path := NodePath("DraggableComponent")

@onready var drag_component: DraggableComponent = get_node_or_null(drag_component_path) as DraggableComponent

func _ready() -> void:
	add_to_group("sauce_bottle")

	if drag_component and not drag_component.drag_ended.is_connected(_on_drag_ended):
		drag_component.drag_ended.connect(_on_drag_ended)

func _on_drag_ended(_item: Node2D, drag: DraggableComponent) -> void:
	if drag.is_drop_accepted():
		return

	for area in drag.get_overlapping_areas():
		var slot: BuildingSlotComponent = area as BuildingSlotComponent
		if slot == null:
			continue

		if _apply_sauce_to_slot(slot, drag):
			return

func _apply_sauce_to_slot(slot: BuildingSlotComponent, bottle_drag: DraggableComponent) -> bool:
	if sauce_scene == null:
		push_warning("Sauce bottle is missing a sauce item scene: %s" % get_path())
		return false

	var sauce_item: Node2D = sauce_scene.instantiate() as Node2D
	if sauce_item == null:
		push_warning("Sauce item scene must instantiate a Node2D: %s" % get_path())
		return false

	var spawn_parent: Node = get_parent()
	if spawn_parent == null:
		spawn_parent = get_tree().current_scene

	spawn_parent.add_child(sauce_item)
	sauce_item.global_position = global_position
	sauce_item.scale = sauce_item_scale

	var sauce_drag: DraggableComponent = _find_drag_component(sauce_item)
	if sauce_drag:
		sauce_drag.drag_parent = spawn_parent
		sauce_drag.failed_drop_behavior = DraggableComponent.FailedDropBehavior.DESPAWN

	if not slot.snap(sauce_item):
		sauce_item.queue_free()
		return false

	bottle_drag.mark_drop_accepted()
	bottle_drag.return_to_drag_origin()
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
