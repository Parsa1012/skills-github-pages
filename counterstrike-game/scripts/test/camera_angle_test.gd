extends Node3D
## Phase 1 Camera Angle & Low-Poly Visual Verification Controller.

@onready var _camera_rig: ArenaCameraRig = $ArenaCameraRig
@onready var _player_proxy: Node3D = $Units/PlayerProxy
@onready var _sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var _safe_margin: MarginContainer = $HUDLayer/SafeMargin
@onready var _cam_metrics_label: Label = $HUDLayer/SafeMargin/RootVBox/TopBar/MetricsPanel/MetricsMargin/MetricsVBox/CameraMetricsLabel
@onready var _perf_metrics_label: Label = $HUDLayer/SafeMargin/RootVBox/TopBar/MetricsPanel/MetricsMargin/MetricsVBox/PerfMetricsLabel
@onready var _patrol_btn: Button = $HUDLayer/SafeMargin/RootVBox/BottomPanel/BottomMargin/ControlsVBox/RowUtility/BtnPatrol
@onready var _fps_btn: Button = $HUDLayer/SafeMargin/RootVBox/BottomPanel/BottomMargin/ControlsVBox/RowUtility/BtnToggleFps

var _pitch_deg: float = 57.5
var _distance_m: float = 19.5
var _telemetry_timer: float = 0.0


func _ready() -> void:
	GameManager.current_state = GameManager.AppState.CAMERA_TEST
	_apply_quality_to_scene()
	_sync_from_rig()
	_apply_safe_area_margins()
	_update_labels()
	get_viewport().size_changed.connect(_apply_safe_area_margins)


func _process(delta: float) -> void:
	_telemetry_timer += delta
	if _telemetry_timer >= 0.25:
		_telemetry_timer = 0.0
		_update_perf_label()


func _apply_safe_area_margins() -> void:
	if _safe_margin == null:
		return
	var pad: Dictionary = GameManager.get_safe_area_padding(get_viewport_rect().size)
	_safe_margin.add_theme_constant_override("margin_left", int(pad["left"]))
	_safe_margin.add_theme_constant_override("margin_right", int(pad["right"]))
	_safe_margin.add_theme_constant_override("margin_top", int(pad["top"]))
	_safe_margin.add_theme_constant_override("margin_bottom", int(pad["bottom"]))


func _apply_quality_to_scene() -> void:
	if _sun_light != null:
		_sun_light.shadow_enabled = (SaveManager.quality_preset != "low")


func _sync_from_rig() -> void:
	if _camera_rig == null:
		return
	_pitch_deg = _camera_rig.get_active_pitch()
	_distance_m = _camera_rig.get_active_distance()


func _apply_test_camera() -> void:
	_pitch_deg = clampf(_pitch_deg, 45.0, 75.0)
	_distance_m = clampf(_distance_m, 12.0, 32.0)
	if _camera_rig != null:
		_camera_rig.set_test_parameters(_pitch_deg, _distance_m)
	_update_labels()


func _update_labels() -> void:
	if _camera_rig != null and _cam_metrics_label != null:
		_cam_metrics_label.text = (
			"BombSquad View | Pitch: %.1f deg | Dist: %.1f m | Height: %.1f m | FOV: %.0f deg | 360 Rot: OFF"
		) % [
			_camera_rig.get_active_pitch(),
			_camera_rig.get_active_distance(),
			_camera_rig.get_camera_world_height(),
			_camera_rig.get_active_fov()
		]

	if _patrol_btn != null and _player_proxy != null:
		var patrol_on: bool = bool(_player_proxy.get("auto_patrol"))
		_patrol_btn.text = "Patrol: ON" if patrol_on else "Patrol: OFF"

	if _fps_btn != null:
		_fps_btn.text = "Target: %d FPS" % SaveManager.target_fps

	_update_perf_label()


func _update_perf_label() -> void:
	if _perf_metrics_label == null:
		return
	var fps: float = Engine.get_frames_per_second()
	var frame_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_perf_metrics_label.text = "FPS: %.0f / %d | Frame: %.1f ms | Draw Calls: %d | Primitives: %d" % [
		fps,
		SaveManager.target_fps,
		frame_ms,
		draw_calls,
		primitives
	]


func _on_btn_pitch_55_pressed() -> void:
	_pitch_deg = 55.0
	_apply_test_camera()


func _on_btn_pitch_575_pressed() -> void:
	_pitch_deg = 57.5
	_apply_test_camera()


func _on_btn_pitch_60_pressed() -> void:
	_pitch_deg = 60.0
	_apply_test_camera()


func _on_btn_pitch_minus_pressed() -> void:
	_pitch_deg -= 1.0
	_apply_test_camera()


func _on_btn_pitch_plus_pressed() -> void:
	_pitch_deg += 1.0
	_apply_test_camera()


func _on_btn_dist_165_pressed() -> void:
	_distance_m = 16.5
	_apply_test_camera()


func _on_btn_dist_195_pressed() -> void:
	_distance_m = 19.5
	_apply_test_camera()


func _on_btn_dist_230_pressed() -> void:
	_distance_m = 23.0
	_apply_test_camera()


func _on_btn_dist_minus_pressed() -> void:
	_distance_m -= 1.0
	_apply_test_camera()


func _on_btn_dist_plus_pressed() -> void:
	_distance_m += 1.0
	_apply_test_camera()


func _on_btn_patrol_pressed() -> void:
	if _player_proxy != null:
		var current_patrol: bool = bool(_player_proxy.get("auto_patrol"))
		_player_proxy.set("auto_patrol", not current_patrol)
	_update_labels()


func _on_btn_toggle_fps_pressed() -> void:
	var next_fps: int = 60 if SaveManager.target_fps == 30 else 30
	GameManager.set_target_fps(next_fps)
	_update_labels()


func _on_btn_reset_pressed() -> void:
	if _camera_rig != null:
		_camera_rig.reload_from_project_settings()
	_sync_from_rig()
	_update_labels()


func _on_btn_back_pressed() -> void:
	GameManager.go_to_main_menu()
