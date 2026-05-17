class_name OrderSlot
extends Area2D

@export var hover_scale := Vector2(1.15, 1.15)
@export var icon_width := 36.0
@export var ingredient_offset := Vector2(0, -8)

@onready var items_root: Node2D = $ItemsRoot as Node2D

var game: Node = null
var order: Dictionary = {}
var original_scale := Vector2.ONE
var connected_drag_components: Array[DraggableComponent] = []

func _ready() -> void:
	input_pickable = false
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

func setup_order(order_data: Dictionary, game_ref: Node) -> void:
	order = order_data
	game = game_ref
	visible = not order.is_empty()
	input_pickable = visible
	scale = original_scale
	_render_order()

func _render_order() -> void:
	for child in items_root.get_children():
		child.queue_free()

	if order.is_empty() or game == null:
		return

	var ingredients: Array = order.get("ingredients", []) as Array
	for index in range(ingredients.size()):
		var ingredient_id: StringName = StringName(ingredients[index])
		var texture: Texture2D = game.call("get_ingredient_texture", ingredient_id) as Texture2D
		if texture == null:
			continue

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = ingredient_offset * index
		sprite.z_index = index
		var texture_width: int = max(1.0, float(texture.get_width()))
		var scale_value: float = icon_width / texture_width
		sprite.scale = Vector2(scale_value, scale_value)
		items_root.add_child(sprite)

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
	if order.is_empty() or drag.is_drop_accepted():
		return

	var burger: CompletedBurger = item as CompletedBurger
	if burger == null or burger.has_burnt_patty:
		return

	for area in drag.get_overlapping_areas():
		var slot: OrderSlot = area as OrderSlot
		if slot != self:
			continue

		var points: int = _score_burger(burger)
		if points <= 0:
			return

		drag.mark_drop_accepted()
		item.queue_free()
		game.call("complete_order", int(order.get("id", -1)), points)
		return

func _score_burger(burger: CompletedBurger) -> int:
	var wanted: Array[String] = _to_string_array(order.get("ingredients", []) as Array)
	var actual: Array[String] = _to_string_array(burger.ingredients)

	if not _same_ingredient_set(wanted, actual):
		return 0

	if wanted == actual:
		return 2

	return 1

func _same_ingredient_set(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false

	for ingredient in left:
		if not right.has(ingredient):
			return false

	return true

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

func _on_mouse_entered() -> void:
	if DraggableComponent.is_drag_active() or order.is_empty():
		return

	scale = original_scale * hover_scale

func _on_mouse_exited() -> void:
	scale = original_scale

func _find_drag_component(node: Node) -> DraggableComponent:
	var drag: DraggableComponent = node as DraggableComponent
	if drag:
		return drag

	for child in node.get_children():
		drag = _find_drag_component(child)
		if drag:
			return drag

	return null
