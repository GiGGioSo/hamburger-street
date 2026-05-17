extends Button

@export var hover_scale : Vector2 = Vector2(1.1, 1.1)
@export var normal_scale : Vector2 = Vector2(1.0, 1.0)
@export var duration : float = 0.15

var tween : Tween

func _ready() -> void:
	pivot_offset = size / 2
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	_animate_scale(hover_scale)

func _on_mouse_exited() -> void:
	_animate_scale(normal_scale)

func _animate_scale(target_scale: Vector2) -> void:
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween()
	tween.tween_property(self, "scale", target_scale, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
