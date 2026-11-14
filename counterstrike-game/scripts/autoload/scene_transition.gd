extends CanvasLayer
## Lightweight reusable full-screen fade for route changes; remains active while gameplay is paused.

signal transition_finished(scene_path: String, result: Error)

const FADE_OUT_SEC: float = 0.14
const FADE_IN_SEC: float = 0.18

var _overlay: ColorRect
var _transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_overlay = ColorRect.new()
	_overlay.name = "FadeOverlay"
	_overlay.color = Color(0.025, 0.04, 0.075, 1.0)
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


func transition_to(scene_path: String) -> Error:
	if scene_path.is_empty():
		return ERR_INVALID_PARAMETER
	if _transitioning:
		return ERR_BUSY
	if not ResourceLoader.exists(scene_path):
		return ERR_FILE_NOT_FOUND
	if OS.get_environment("ARENA_CI_SILENT_AUDIO") == "1" or DisplayServer.get_name().to_lower() == "headless":
		get_tree().paused = false
		return get_tree().change_scene_to_file(scene_path)
	_transitioning = true
	_run_transition(scene_path)
	return OK


func _run_transition(scene_path: String) -> void:
	if _overlay == null or not is_inside_tree():
		_transitioning = false
		return
	var fade_out: Tween = create_tween()
	fade_out.tween_property(_overlay, "modulate:a", 1.0, FADE_OUT_SEC)
	await fade_out.finished
	get_tree().paused = false
	var result: Error = get_tree().change_scene_to_file(scene_path)
	if result == OK:
		await get_tree().process_frame
		await get_tree().process_frame
	if is_instance_valid(_overlay):
		var fade_in: Tween = create_tween()
		fade_in.tween_property(_overlay, "modulate:a", 0.0, FADE_IN_SEC)
		await fade_in.finished
	_transitioning = false
	transition_finished.emit(scene_path, result)
	if result != OK:
		push_error("Scene transition failed for %s (Error %d)" % [scene_path, result])
