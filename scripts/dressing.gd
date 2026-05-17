@tool
class_name Dressing
extends Node2D

@export var dressing_texture: Texture2D:
	set(value):
		dressing_texture = value
		_update_texture()

@export var item_scene: PackedScene
@export var spawned_item_scale := Vector2(0.12, 0.12)

@onready var dressing_image: Sprite2D = $DressingImage as Sprite2D
@onready var dressing_area: Area2D = $DressingArea as Area2D

func _ready() -> void:
	_update_texture()

	if Engine.is_editor_hint():
		return

	if dressing_area:
		dressing_area.input_pickable = true

	if dressing_area and not dressing_area.input_event.is_connected(_on_dressing_area_input_event):
		dressing_area.input_event.connect(_on_dressing_area_input_event)

func _on_dressing_area_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if DraggableComponent.is_drag_active():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_spawn_item_for_drag()
		get_viewport().set_input_as_handled()

func _spawn_item_for_drag() -> void:
	if item_scene == null:
		push_warning("Dressing is missing an item scene: %s" % get_path())
		return

	var item: Node2D = item_scene.instantiate() as Node2D
	if item == null:
		push_warning("Dressing item scene must instantiate a Node2D: %s" % get_path())
		return

	var spawn_parent: Node = get_parent()
	if spawn_parent == null:
		spawn_parent = get_tree().current_scene

	spawn_parent.add_child(item)
	item.global_position = get_global_mouse_position()
	item.scale = spawned_item_scale

	var drag: DraggableComponent = _find_drag_component(item)
	if drag == null:
		push_warning("Spawned dressing item is missing a DraggableComponent: %s" % item.get_path())
		return

	drag.drag_parent = spawn_parent
	drag.failed_drop_behavior = DraggableComponent.FailedDropBehavior.DESPAWN
	drag.start_drag()

func _find_drag_component(node: Node) -> DraggableComponent:
	var drag: DraggableComponent = node as DraggableComponent
	if drag:
		return drag

	for child in node.get_children():
		drag = _find_drag_component(child)
		if drag:
			return drag

	return null

func _update_texture() -> void:
	var image: Sprite2D = dressing_image
	if image == null:
		image = get_node_or_null("DressingImage") as Sprite2D

	if image:
		image.texture = dressing_texture
