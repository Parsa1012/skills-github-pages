extends Node
## هماهنگ‌کننده اصلی جلسه آفلاین، مدیریت نرخ فریم/کیفیت، حالت مسابقه و جابه‌جایی بین صحنه‌ها.

enum AppState {
	BOOT,
	MAIN_MENU,
	CAMERA_TEST,
	ARENA_PLAY,
	PAUSED
}

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const CAMERA_TEST_SCENE: String = "res://scenes/test/camera_angle_test.tscn"
const ARENA_SECTOR_01_SCENE: String = "res://scenes/maps/arena_sector_01.tscn"
const MODE_ZONE_CONTROL_PATH: String = "res://data/modes/zone_control.tres"
const MODE_TEAM_RUSH_PATH: String = "res://data/modes/team_score_rush.tres"

var current_state: AppState = AppState.BOOT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TranslationServer.set_locale("fa")
	if get_tree() != null:
		get_tree().set_quit_on_go_back(false)
	_apply_persian_theme()
	_register_camera_project_settings()
	apply_performance_settings()
	EventBus.scene_change_requested.connect(change_scene)


func _apply_persian_theme() -> void:
	if Engine.is_editor_hint():
		return
	var theme_path: String = "res://assets/ui/persian_theme.tres"
	if ResourceLoader.exists(theme_path):
		var loaded_theme: Resource = ResourceLoader.load(theme_path)
		if loaded_theme is Theme and get_tree() != null and get_tree().root != null:
			get_tree().root.theme = loaded_theme as Theme


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
	_apply_viewport_quality_preset(SaveManager.quality_preset)
	EventBus.fps_target_changed.emit(SaveManager.target_fps)
	EventBus.quality_preset_changed.emit(SaveManager.quality_preset)


func _apply_viewport_quality_preset(preset: String) -> void:
	if get_tree() == null or get_tree().root == null:
		return
	var root_vp: Viewport = get_tree().root
	match preset:
		"low":
			root_vp.scaling_3d_scale = 0.75
			root_vp.msaa_3d = Viewport.MSAA_DISABLED
		"high":
			root_vp.scaling_3d_scale = 1.0
			root_vp.msaa_3d = Viewport.MSAA_2X
		_:
			root_vp.scaling_3d_scale = 0.90
			root_vp.msaa_3d = Viewport.MSAA_DISABLED


func set_target_fps(fps: int) -> void:
	SaveManager.target_fps = 60 if fps >= 60 else 30
	SaveManager.save_settings()
	apply_performance_settings()


func set_quality_preset(preset: String) -> void:
	if preset in ["low", "medium", "high"]:
		SaveManager.quality_preset = preset
		SaveManager.save_settings()
		apply_performance_settings()


func set_aim_fire_mode(mode: String) -> void:
	if mode in ["twin_stick", "fire_button"]:
		SaveManager.aim_fire_mode = mode
		SaveManager.save_settings()
		EventBus.aim_fire_mode_changed.emit(mode)


func set_selected_mode(mode_id: String) -> void:
	if mode_id in ["zone_control", "team_score_rush"]:
		SaveManager.selected_mode_id = mode_id
		SaveManager.save_settings()
		EventBus.selected_mode_changed.emit(mode_id)


func get_active_mode_config() -> ArenaModeConfig:
	var path: String = MODE_TEAM_RUSH_PATH if SaveManager.selected_mode_id == "team_score_rush" else MODE_ZONE_CONTROL_PATH
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is ArenaModeConfig:
			return res as ArenaModeConfig
	var fallback := ArenaModeConfig.new()
	return fallback


func record_match_result(won: bool, eliminations: int) -> void:
	SaveManager.total_matches += 1
	if won:
		SaveManager.total_wins += 1
	SaveManager.total_eliminations += maxi(0, eliminations)
	SaveManager.save_settings()


func set_match_paused(paused: bool) -> void:
	if get_tree() != null:
		get_tree().paused = paused
	current_state = AppState.PAUSED if paused else AppState.ARENA_PLAY
	EventBus.match_paused_changed.emit(paused)


func go_to_main_menu() -> void:
	current_state = AppState.MAIN_MENU
	change_scene(MAIN_MENU_SCENE)


func go_to_camera_test() -> void:
	current_state = AppState.CAMERA_TEST
	change_scene(CAMERA_TEST_SCENE)


func go_to_arena_sector_01() -> void:
	current_state = AppState.ARENA_PLAY
	change_scene(ARENA_SECTOR_01_SCENE)


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

	var left_pad: float = clampf(float(safe_rect.position.x) * scale_x, 16.0, 96.0)
	var top_pad: float = clampf(float(safe_rect.position.y) * scale_y, 12.0, 56.0)
	var right_px: int = screen_size.x - (safe_rect.position.x + safe_rect.size.x)
	var bottom_px: int = screen_size.y - (safe_rect.position.y + safe_rect.size.y)
	var right_pad: float = clampf(float(right_px) * scale_x, 16.0, 96.0)
	var bottom_pad: float = clampf(float(bottom_px) * scale_y, 12.0, 48.0)

	return {
		"left": left_pad,
		"right": right_pad,
		"top": top_pad,
		"bottom": bottom_pad
	}
