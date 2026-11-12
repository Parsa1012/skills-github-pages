extends Node
## Top-level offline session coordinator, FPS/quality policy manager, and scene router.

enum AppState {
	BOOT,
	MAIN_MENU,
	CAMERA_TEST,
	IN_MATCH,
	PAUSED
}

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const CAMERA_TEST_SCENE: String = "res://scenes/test/camera_angle_test.tscn"

var current_state: AppState = AppState.BOOT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_camera_project_settings()
	apply_performance_settings()
	EventBus.scene_change_requested.connect(change_scene)


func _register_camera_project_settings() -> void:
	_ensure_setting("arena_camera/pitch_degrees", 57.5, TYPE_FLOAT, PROPERTY_HINT_RANGE, "45.0,75.0,0.5")
	_ensure_setting("arena_camera/yaw_degrees", 0.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "-45.0,45.0,1.0")
	_ensure_setting("arena_camera/distance", 19.5, TYPE_FLOAT, PROPERTY_HINT_RANGE, "12.0,32.0,0.5")
	_ensure_setting("arena_camera/fov_degrees", 44.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "32.0,60.0,0.5")
	_ensure_setting("arena_camera/follow_smoothness", 6.5, TYPE_FLOAT, PROPERTY_HINT_RANGE, "1.0,20.0,0.5")
	_ensure_setting("arena_camera/look_ahead_distance", 1.25, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.0,4.0,0.25")
	_ensure_setting("arena_camera/allow_free_rotation", false, TYPE_BOOL, PROPERTY_HINT_NONE, "")


func _ensure_setting(setting_name: String, default_value: Variant, prop_type: int, hint: int, hint_string: String) -> void:
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)
	ProjectSettings.set_initial_value(setting_name, default_value)
	ProjectSettings.add_property_info({
		"name": setting_name,
		"type": prop_type,
		"hint": hint,
		"hint_string": hint_string
	})


func apply_performance_settings() -> void:
	Engine.max_fps = SaveManager.target_fps
	EventBus.fps_target_changed.emit(SaveManager.target_fps)
	EventBus.quality_preset_changed.emit(SaveManager.quality_preset)


func set_target_fps(fps: int) -> void:
	SaveManager.target_fps = 60 if fps >= 60 else 30
	SaveManager.save_settings()
	apply_performance_settings()


func set_quality_preset(preset: String) -> void:
	if preset in ["low", "medium", "high"]:
		SaveManager.quality_preset = preset
		SaveManager.save_settings()
		apply_performance_settings()


func go_to_main_menu() -> void:
	current_state = AppState.MAIN_MENU
	change_scene(MAIN_MENU_SCENE)


func go_to_camera_test() -> void:
	current_state = AppState.CAMERA_TEST
	change_scene(CAMERA_TEST_SCENE)


func change_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	get_tree().paused = false
	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("Failed to load scene: %s (Error %d)" % [scene_path, err])


func get_safe_area_padding(viewport_size: Vector2) -> Dictionary:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return {"left": 16.0, "right": 16.0, "top": 12.0, "bottom": 12.0}

	var scale_x: float = viewport_size.x / float(screen_size.x)
	var scale_y: float = viewport_size.y / float(screen_size.y)

	var left_pad: float = maxf(float(safe_rect.position.x) * scale_x, 16.0)
	var top_pad: float = maxf(float(safe_rect.position.y) * scale_y, 12.0)
	var right_px: int = screen_size.x - (safe_rect.position.x + safe_rect.size.x)
	var bottom_px: int = screen_size.y - (safe_rect.position.y + safe_rect.size.y)
	var right_pad: float = maxf(float(right_px) * scale_x, 16.0)
	var bottom_pad: float = maxf(float(bottom_px) * scale_y, 12.0)

	return {
		"left": left_pad,
		"right": right_pad,
		"top": top_pad,
		"bottom": bottom_pad
	}
