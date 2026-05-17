@tool
class_name DraggableItemSpawner
extends Node2D

signal item_spawned(item: Node2D)

@export var spawner_texture: Texture2D:
	set(value):
		spawner_texture = value
		_update_texture()

@export var item_scene: PackedScene
@export var spawned_item_scale := Vector2(0.12, 0.12)
@export var display_scale := Vector2(0.05, 0.05):
	set(value):
		display_scale = value
		_update_display_scale()

@onready var spawner_image := $SpawnerImage as Sprite2D
@onready var spawner_area := $SpawnerArea as Area2D

func _ready() -> void:
	_update_texture()
	_update_display_scale()

	if Engine.is_editor_hint():
		return

	if spawner_area:
		spawner_area.input_pickable = true

	if spawner_area and not spawner_area.input_event.is_connected(_on_spawner_area_input_event):
		spawner_area.input_event.connect(_on_spawner_area_input_event)

func _on_spawner_area_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if DraggableComponent.is_drag_active():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_spawn_item_for_drag()
		get_viewport().set_input_as_handled()

func _spawn_item_for_drag() -> void:
	if item_scene == null:
		push_warning("Draggable item spawner is missing an item scene: %s" % get_path())
		return

	var item := item_scene.instantiate() as Node2D
	if item == null:
		push_warning("Spawner item scene must instantiate a Node2D: %s" % get_path())
		return

	var spawn_parent := get_parent()
	if spawn_parent == null:
		spawn_parent = get_tree().current_scene

	spawn_parent.add_child(item)
	item.global_position = get_global_mouse_position()
	item.scale = spawned_item_scale

	var drag := _find_drag_component(item)
	if drag == null:
		push_warning("Spawned item is missing a DraggableComponent: %s" % item.get_path())
		return

	drag.drag_parent = spawn_parent
	drag.start_drag()
	item_spawned.emit(item)

func _find_drag_component(node: Node) -> DraggableComponent:
	var drag := node as DraggableComponent
	if drag:
		return drag

	for child in node.get_children():
		drag = _find_drag_component(child)
		if drag:
			return drag

	return null

func _update_texture() -> void:
	var image := spawner_image
	if image == null:
		image = get_node_or_null("SpawnerImage") as Sprite2D

	if image:
		image.texture = spawner_texture

func _update_display_scale() -> void:
	var image := spawner_image
	if image == null:
		image = get_node_or_null("SpawnerImage") as Sprite2D

	if image:
		image.scale = display_scale
