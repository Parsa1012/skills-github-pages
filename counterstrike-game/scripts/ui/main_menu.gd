extends Control
## منوی اصلی و مرکز تنظیمات آفلاین بازی (پشتیبانی کامل فارسی RTL و حاشیه امن صفحه موبایل).

@onready var _safe_margin: MarginContainer = $SafeMargin
@onready var _match_mode_btn: Button = $SafeMargin/MainLayout/ContentRow/ActionColumn/BtnMatchMode
@onready var _settings_panel: PanelContainer = $SafeMargin/MainLayout/ContentRow/SettingsPanel
@onready var _fps_30_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/FpsRow/BtnFps30
@onready var _fps_60_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/FpsRow/BtnFps60
@onready var _quality_low_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnLow
@onready var _quality_med_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnMedium
@onready var _quality_high_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnHigh
@onready var _aim_mode_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/ControlsRow/BtnAimMode
@onready var _sfx_btn: Button = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/ControlsRow/BtnSfx
@onready var _camera_info_label: Label = $SafeMargin/MainLayout/ContentRow/SettingsPanel/SettingsMargin/SettingsVBox/CameraInfoLabel
@onready var _status_label: Label = $SafeMargin/MainLayout/FooterBar/StatusLabel


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	if _safe_margin != null:
		_safe_margin.layout_direction = Control.LAYOUT_DIRECTION_RTL
	if _camera_info_label != null:
		_camera_info_label.text_direction = Control.TEXT_DIRECTION_RTL
	if _status_label != null:
		_status_label.text_direction = Control.TEXT_DIRECTION_RTL

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

	var is_fire_btn: bool = (SaveManager.aim_fire_mode == "fire_button")
	_aim_mode_btn.text = "نشانه: دکمه شلیک جدا" if is_fire_btn else "نشانه: دو جوی‌استیک"

	_sfx_btn.button_pressed = SaveManager.sfx_enabled
	_sfx_btn.text = "صدای رابط: روشن" if SaveManager.sfx_enabled else "صدای رابط: خاموش"

	var quality_fa: String = "متوسط"
	match SaveManager.quality_preset:
		"low":
			quality_fa = "کم"
		"high":
			quality_fa = "زیاد"

	var active_mode: ArenaModeConfig = GameManager.get_active_mode_config()
	if _match_mode_btn != null and active_mode != null:
		_match_mode_btn.text = "حالت نبرد: %s (هدف: %d)" % [active_mode.display_name, active_mode.target_score]

	var cam_cfg: CameraConfig = CameraConfig.from_project_settings()
	_camera_info_label.text = (
		"دوربین BombSquad: زاویه %.1f° | فاصله %.1f متر | زاویه دید %.0f°\n"
		+ "میدان نبرد ۲×۳: ۱ هم‌تیمی آبی در برابر ۳ پهپاد نارنجی با ۳ سلاح انرژی."
	) % [cam_cfg.pitch_degrees, cam_cfg.distance, cam_cfg.fov_degrees]

	_status_label.text = "سابقه آفلاین: %d نبرد (%d پیروزی، %d حذف) | هدف: %d FPS | کیفیت: %s" % [
		SaveManager.total_matches,
		SaveManager.total_wins,
		SaveManager.total_eliminations,
		fps_target,
		quality_fa
	]


func _on_btn_match_mode_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_mode_id: String = "team_score_rush" if SaveManager.selected_mode_id == "zone_control" else "zone_control"
	GameManager.set_selected_mode(next_mode_id)
	_refresh_ui()


func _on_btn_enter_arena_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_arena_sector_01()


func _on_btn_camera_test_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_camera_test()


func _on_btn_toggle_settings_pressed() -> void:
	AudioManager.play_ui_menu()
	_settings_panel.visible = not _settings_panel.visible


func _on_btn_fps_30_pressed() -> void:
	AudioManager.play_ui_click()
	GameManager.set_target_fps(30)
	_refresh_ui()


func _on_btn_fps_60_pressed() -> void:
	AudioManager.play_ui_click()
	GameManager.set_target_fps(60)
	_refresh_ui()


func _on_btn_low_pressed() -> void:
	AudioManager.play_ui_click()
	GameManager.set_quality_preset("low")
	_refresh_ui()


func _on_btn_medium_pressed() -> void:
	AudioManager.play_ui_click()
	GameManager.set_quality_preset("medium")
	_refresh_ui()


func _on_btn_high_pressed() -> void:
	AudioManager.play_ui_click()
	GameManager.set_quality_preset("high")
	_refresh_ui()


func _on_btn_aim_mode_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_mode: String = "fire_button" if SaveManager.aim_fire_mode == "twin_stick" else "twin_stick"
	GameManager.set_aim_fire_mode(next_mode)
	_refresh_ui()


func _on_btn_sfx_pressed() -> void:
	var next_enabled: bool = not SaveManager.sfx_enabled
	AudioManager.set_sfx_enabled(next_enabled)
	if next_enabled:
		AudioManager.play_ui_pop()
	_refresh_ui()
