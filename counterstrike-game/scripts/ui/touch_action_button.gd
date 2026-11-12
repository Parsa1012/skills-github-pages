class_name TouchActionButton
extends Control
## دکمه اکشن چندلمسی (تغییر سلاح / شارژ مجدد) بدون تداخل با جوی‌استیک‌های حرکت و نشانه.

signal action_triggered()

@export var title_text: String = "تغییر سلاح"
@export var accent_color: Color = Color(0.219608, 0.741176, 0.972549, 1.0)

var _pressed: bool = false
var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_reset_button()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset_button()


func _reset_button() -> void:
	_touch_index = -1
	_pressed = false
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1:
				var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * touch.position
				if Rect2(Vector2.ZERO, size).has_point(local_pos):
					_touch_index = touch.index
					_pressed = true
					queue_redraw()
					action_triggered.emit()
		elif touch.index == _touch_index:
			_touch_index = -1
			_pressed = false
			queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var bg_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.42 if _pressed else 0.18)
	var border_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.95 if _pressed else 0.65)
	draw_rect(rect, bg_col, true)
	draw_rect(rect, border_col, false, 2.0)

	var font: Font = get_theme_default_font()
	if font != null and not title_text.is_empty():
		var text_y: float = size.y * 0.5 + 5.0
		draw_string(font, Vector2(0.0, text_y), title_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(0.97, 0.98, 1.0, 0.95), TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_RTL)
