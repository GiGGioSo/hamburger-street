class_name BuildingSlotComponent
extends Area2D

signal item_snapped(item: Node2D, slot: BuildingSlotComponent)
signal item_released(item: Node2D, slot: BuildingSlotComponent)
signal slot_completed(slot: BuildingSlotComponent)
signal burger_confirmed(slot: BuildingSlotComponent)

@export var accepted_groups: PackedStringArray = PackedStringArray(["hamburger", "dressing_item", "top_bun"])
@export var max_items := 6
@export var stack_offset := Vector2(0, -14)
@export var item_base_offset := Vector2(0, -4)
@export var top_bun_group := "top_bun"
@export var confirm_button_path := NodePath("ConfirmButton")

@onready var confirm_button: Button = get_node_or_null(confirm_button_path) as Button

var items: Array[Node2D] = []
var is_completed := false
var item_drag_components := {}

func _ready() -> void:
	add_to_group("building_slot")
	input_pickable = true

	if confirm_button:
		confirm_button.visible = false
		if not confirm_button.pressed.is_connected(_on_confirm_button_pressed):
			confirm_button.pressed.connect(_on_confirm_button_pressed)

func can_accept(item: Node2D) -> bool:
	_clear_stale_items()

	if is_completed:
		return false

	if items.size() >= max_items:
		return false

	var hamburger: Hamburger = item as Hamburger
	if hamburger and hamburger.is_burnt():
		return false

	if not _is_accepted_item(item):
		return false

	if _has_matching_ingredient(item):
		return false

	return true

func snap(item: Node2D) -> bool:
	if not can_accept(item):
		return false

	var drag: DraggableComponent = _find_drag_component(item)
	items.append(item)

	if drag:
		drag.mark_drop_accepted()
		item_drag_components[item] = drag
		if not drag.drag_started.is_connected(_on_item_drag_started):
			drag.drag_started.connect(_on_item_drag_started)

	item.reparent(self)
	_refresh_stack()
	_refresh_stack_drag_enabled()

	item_snapped.emit(item, self)

	if item.is_in_group(top_bun_group):
		is_completed = true
		_set_confirm_visible(true)
		slot_completed.emit(self)

	return true

func restore_dragged_item(item: Node2D) -> bool:
	return snap(item)

func get_ingredient_sequence() -> Array[StringName]:
	var sequence: Array[StringName] = [&"bottom_bun"]
	for item in items:
		if not is_instance_valid(item):
			continue

		var ingredient_id: StringName = _get_ingredient_id(item)
		if ingredient_id != &"":
			sequence.append(ingredient_id)

	return sequence

func has_burnt_patty() -> bool:
	for item in items:
		var hamburger: Hamburger = item as Hamburger
		if hamburger and hamburger.is_burnt():
			return true

	return false

func consume_items_for_completed_burger() -> Array[Node2D]:
	var consumed: Array[Node2D] = []
	for item in items:
		if not is_instance_valid(item):
			continue

		var drag: DraggableComponent = item_drag_components.get(item) as DraggableComponent
		if is_instance_valid(drag):
			if drag.drag_started.is_connected(_on_item_drag_started):
				drag.drag_started.disconnect(_on_item_drag_started)
			drag.set_drag_enabled(false)

		consumed.append(item)

	items.clear()
	item_drag_components.clear()
	is_completed = false
	_set_confirm_visible(false)
	return consumed

func _is_accepted_item(item: Node2D) -> bool:
	if item == null:
		return false

	for group_name_variant in accepted_groups:
		var group_name: StringName = StringName(group_name_variant)
		if item.is_in_group(group_name):
			return true

	return false

func _has_matching_ingredient(item: Node2D) -> bool:
	var ingredient_id: StringName = _get_ingredient_id(item)
	if ingredient_id == &"":
		return false

	for stacked_item in items:
		if not is_instance_valid(stacked_item) or stacked_item == item:
			continue

		if _get_ingredient_id(stacked_item) == ingredient_id:
			return true

	return false

func _get_ingredient_id(item: Node2D) -> StringName:
	var ingredient: BurgerIngredient = item.get_node_or_null("BurgerIngredient") as BurgerIngredient
	if ingredient and ingredient.ingredient_id != &"":
		return ingredient.ingredient_id

	if item.is_in_group("hamburger"):
		return &"patty"
	if item.is_in_group("top_bun"):
		return &"top_bun"
	if item.is_in_group("dressing_item"):
		return StringName(String(item.name).to_snake_case())

	return &""

func _clear_stale_items() -> void:
	for item in items.duplicate():
		if not is_instance_valid(item) or item.get_parent() != self:
			_release_item(item)

func _release_item(item: Node2D) -> void:
	if not items.has(item):
		return

	var drag: DraggableComponent = item_drag_components.get(item) as DraggableComponent
	if is_instance_valid(drag) and drag.drag_started.is_connected(_on_item_drag_started):
		drag.drag_started.disconnect(_on_item_drag_started)

	items.erase(item)
	item_drag_components.erase(item)
	if is_instance_valid(drag):
		drag.set_drag_enabled(true)

	_refresh_stack()
	_refresh_stack_drag_enabled()

	is_completed = _has_top_bun()
	_set_confirm_visible(is_completed)

	if is_instance_valid(item):
		item_released.emit(item, self)

func _refresh_stack() -> void:
	for index in range(items.size()):
		var item: Node2D = items[index]
		if not is_instance_valid(item):
			continue

		item.position = item_base_offset + (stack_offset * index)
		item.z_index = index + 1

func _refresh_stack_drag_enabled() -> void:
	var top_item: Node2D = null
	if not items.is_empty():
		top_item = items.back()

	for item in items:
		if not is_instance_valid(item):
			continue

		var drag: DraggableComponent = item_drag_components.get(item) as DraggableComponent
		if drag == null:
			drag = _find_drag_component(item)

		if drag:
			drag.set_drag_enabled(item == top_item)

func _has_top_bun() -> bool:
	for item in items:
		if is_instance_valid(item) and item.is_in_group(top_bun_group):
			return true

	return false

func _set_confirm_visible(is_visible: bool) -> void:
	if confirm_button:
		confirm_button.visible = is_visible

func _on_item_drag_started(item: Node2D, _drag_component: DraggableComponent) -> void:
	if items.is_empty() or item != items.back():
		return

	_release_item(item)

func _on_confirm_button_pressed() -> void:
	burger_confirmed.emit(self)

func _find_drag_component(node: Node) -> DraggableComponent:
	var drag: DraggableComponent = node as DraggableComponent
	if drag:
		return drag

	for child in node.get_children():
		drag = _find_drag_component(child)
		if drag:
			return drag

	return null
