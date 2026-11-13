class_name DamageNumbersOverlay
extends Control
## نمایش اعداد شناور آسیب و اعلان حذف در فضای ۳بعدی روی صفحه نبرد (Game Juice).

const BOLD_FONT: Font = preload("res://assets/fonts/Vazirmatn-Bold.ttf")
const MAX_POPUPS: int = 18

var _popups: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func spawn_callout(world_pos: Vector3, text_fa: String, color: Color, scale_boost: float = 1.0) -> void:
	if text_fa.is_empty():
		return
	if _popups.size() >= MAX_POPUPS:
		_popups.remove_at(0)
	_popups.append({
		"world_pos": world_pos,
		"text": text_fa,
		"color": color,
		"age": 0.0,
		"dur": 0.72 if scale_boost < 1.25 else 0.90,
		"scale": clampf(scale_boost, 0.85, 1.65),
		"drift_x": randf_range(-16.0, 16.0)
	})
	queue_redraw()


func _process(delta: float) -> void:
	if _popups.is_empty():
		return
	for i in range(_popups.size() - 1, -1, -1):
		var p: Dictionary = _popups[i]
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["dur"]):
			_popups.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if _popups.is_empty():
		return
	var vp: Viewport = get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp != null else null
	if cam == null:
		return
	var font: Font = BOLD_FONT if BOLD_FONT != null else get_theme_default_font()
	if font == null:
		return

	for p in _popups:
		var world_pos: Vector3 = p["world_pos"]
		if cam.is_position_behind(world_pos):
			continue
		var screen_pos: Vector2 = cam.unproject_position(world_pos)
		var age: float = float(p["age"])
		var dur: float = maxf(0.1, float(p["dur"]))
		var t: float = clampf(age / dur, 0.0, 1.0)
		var pop_scale: float = float(p["scale"]) * (1.35 - 0.35 * minf(1.0, t * 4.5))
		var alpha: float = 1.0 if t < 0.55 else clampf(1.0 - (t - 0.55) / 0.45, 0.0, 1.0)
		var y_rise: float = 34.0 * (1.0 - pow(1.0 - t, 2.0))
		var x_drift: float = float(p["drift_x"]) * t
		var pos := Vector2(screen_pos.x + x_drift - 65.0, screen_pos.y - y_rise)
		var fsize: int = maxi(14, int(round(17.0 * pop_scale)))
		var col: Color = p["color"]
		var shadow := Color(0.03, 0.04, 0.08, alpha * 0.88)
		var fg := Color(col.r, col.g, col.b, alpha)
		var text_str: String = str(p["text"])
		draw_string(font, pos + Vector2(1.5, 1.5), text_str, HORIZONTAL_ALIGNMENT_CENTER, 130.0, fsize, shadow, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO)
		draw_string(font, pos, text_str, HORIZONTAL_ALIGNMENT_CENTER, 130.0, fsize, fg, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO)
