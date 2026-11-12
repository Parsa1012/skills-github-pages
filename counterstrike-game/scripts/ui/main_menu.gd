extends Control
## Phase 1 Main Menu & Offline Settings Hub (Galaxy A32 safe-area aware).

@onready var _safe_margin: MarginContainer = $SafeMargin
@onready var _settings_panel: PanelContainer = $SafeMargin/MainLayout/ContentRow/SettingsPanel
@onready var _fps_30_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/FpsRow/BtnFps30
@onready var _fps_60_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/FpsRow/BtnFps60
@onready var _quality_low_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnLow
@onready var _quality_med_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnMedium
@onready var _quality_high_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnHigh
@onready var _camera_info_label: Label = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/CameraInfoLabel
@onready var _status_label: Label = $SafeMargin/MainLayout/FooterBar/StatusLabel


func _ready() -> void:
	GameManager.current_state = GameManager.AppState.MAIN_MENU
	_apply_safe_area_margins()
	_refresh_ui()
	get_viewport().size_changed.connect(_apply_safe_area_margins)


func _apply_safe_area_margins() -> void:
	if _safe_margin == null:
		return
	var pad: Dictionary = GameManager.get_safe_area_padding(get_viewport_rect().size)
	_safe_margin.add_theme_constant_override("margin_left", int(pad["left"]))
	_safe_margin.add_theme_constant_override("margin_right", int(pad["right"]))
	_safe_margin.add_theme_constant_override("margin_top", int(pad["top"]))
	_safe_margin.add_theme_constant_override("margin_bottom", int(pad["bottom"]))


func _refresh_ui() -> void:
	var fps_target: int = SaveManager.target_fps
	_fps_30_btn.button_pressed = (fps_target == 30)
	_fps_60_btn.button_pressed = (fps_target == 60)

	_quality_low_btn.button_pressed = (SaveManager.quality_preset == "low")
	_quality_med_btn.button_pressed = (SaveManager.quality_preset == "medium")
	_quality_high_btn.button_pressed = (SaveManager.quality_preset == "high")

	var cam_cfg: CameraConfig = CameraConfig.from_project_settings()
	_camera_info_label.text = (
		"BombSquad Camera Defaults (ProjectSettings):\n"
		+ "Pitch: %.1f deg | Distance: %.1f m | FOV: %.1f deg | Free 360: Off"
	) % [cam_cfg.pitch_degrees, cam_cfg.distance, cam_cfg.fov_degrees]

	_status_label.text = "Offline Mode Ready | Renderer: GL Compatibility | Target FPS: %d | Preset: %s" % [
		fps_target,
		SaveManager.quality_preset.capitalize()
	]


func _on_btn_camera_test_pressed() -> void:
	GameManager.go_to_camera_test()


func _on_btn_toggle_settings_pressed() -> void:
	_settings_panel.visible = not _settings_panel.visible


func _on_btn_fps_30_pressed() -> void:
	GameManager.set_target_fps(30)
	_refresh_ui()


func _on_btn_fps_60_pressed() -> void:
	GameManager.set_target_fps(60)
	_refresh_ui()


func _on_btn_low_pressed() -> void:
	GameManager.set_quality_preset("low")
	_refresh_ui()


func _on_btn_medium_pressed() -> void:
	GameManager.set_quality_preset("medium")
	_refresh_ui()


func _on_btn_high_pressed() -> void:
	GameManager.set_quality_preset("high")
	_refresh_ui()
