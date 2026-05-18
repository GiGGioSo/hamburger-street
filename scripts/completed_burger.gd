class_name CompletedBurger
extends Node2D

@export var stack_offset := Vector2(0, -14)
@export var item_base_offset := Vector2(0, -4)

var ingredients: Array[StringName] = []
var has_burnt_patty := false

func _ready() -> void:
	add_to_group("completed_burger")

func setup_burger(sequence: Array[StringName], stack_items: Array[Node2D], contains_burnt_patty: bool) -> void:
	ingredients.clear()
	for ingredient in sequence:
		ingredients.append(StringName(ingredient))

	has_burnt_patty = contains_burnt_patty

	for index in range(stack_items.size()):
		var item: Node2D = stack_items[index]
		if item == null:
			continue

		_disable_nested_drag(item)
		item.reparent(self, false)
		item.rotation = 0.0
		item.position = item_base_offset + (stack_offset * (index + 1))
		item.z_index = index + 1

func _disable_nested_drag(node: Node) -> void:
	var drag: DraggableComponent = node as DraggableComponent
	if drag:
		drag.set_drag_enabled(false)

	for child in node.get_children():
		_disable_nested_drag(child)
