class_name TouchFirePad
extends Control
## دکمه لمسی اختصاصی شلیک با پشتیبانی کامل چندلمسی (Multi-Touch) همزمان با حرکت.

signal fire_state_changed(pressed: bool)

@export var label_text: String = "شلیک"
@export var pad_color: Color = Color(0.984314, 0.45098, 0.086275, 1.0)

var is_pressed: bool = false
var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release_pad()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_pad()


func release_pad() -> void:
	if _touch_index != -1 or is_pressed:
		_touch_index = -1
		is_pressed = false
		queue_redraw()
		fire_state_changed.emit(false)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1:
				var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * touch.position
				var center: Vector2 = size * 0.5
				var radius: float = minf(size.x, size.y) * 0.48
				if local_pos.distance_to(center) <= radius:
					_touch_index = touch.index
					is_pressed = true
					queue_redraw()
					fire_state_changed.emit(true)
		elif touch.index == _touch_index:
			release_pad()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.44
	var alpha: float = 0.96 if is_pressed else 0.72

	var fill_col := Color(pad_color.r, pad_color.g, pad_color.b, (0.85 if is_pressed else 0.40) * alpha)
	draw_circle(center, radius, fill_col)
	draw_arc(center, radius, 0.0, TAU, 36, Color(1.0, 0.92, 0.84, alpha), 3.0, true)

	var inner_r: float = radius * (0.64 if is_pressed else 0.72)
	draw_arc(center, inner_r, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.45 * alpha), 1.5, true)

	var font: Font = get_theme_default_font()
	if font != null and not label_text.is_empty():
		draw_string(font, center + Vector2(-42.0, 6.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, 84.0, 18, Color(0.98, 0.99, 1.0, 0.95), TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_RTL)
