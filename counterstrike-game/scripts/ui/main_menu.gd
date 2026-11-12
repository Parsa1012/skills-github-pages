extends Control
## منوی اصلی و لابی تاکتیکی آفلاین (انتخاب حالت نبرد، سلاح شروع، تنظیمات صدا/گرافیک و کارنامه).

const BLASTER_PATHS: Dictionary = {
	"pulse_blaster": "res://data/blasters/pulse_blaster.tres",
	"rapid_repeater": "res://data/blasters/rapid_repeater.tres",
	"plasma_scatter": "res://data/blasters/plasma_scatter.tres"
}

@onready var _safe_margin: MarginContainer = $SafeMargin
@onready var _match_mode_btn: Button = $SafeMargin/MainLayout/ContentRow/ActionColumn/BtnMatchMode
@onready var _tab_loadout_btn: Button = $SafeMargin/MainLayout/ContentRow/ActionColumn/TabSwitcherRow/BtnTabLoadout
@onready var _tab_settings_btn: Button = $SafeMargin/MainLayout/ContentRow/ActionColumn/TabSwitcherRow/BtnTabSettings
@onready var _loadout_panel: PanelContainer = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel
@onready var _settings_panel: PanelContainer = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel

@onready var _blaster_pulse_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterRow/BtnBlasterPulse
@onready var _blaster_repeater_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterRow/BtnBlasterRepeater
@onready var _blaster_scatter_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterRow/BtnBlasterScatter
@onready var _blaster_desc_label: Label = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/BlasterDescLabel
@onready var _damage_bar: ProgressBar = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/DmgRow/DamageBar
@onready var _rate_bar: ProgressBar = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/RateRow/FireRateBar
@onready var _ammo_bar: ProgressBar = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/AmmoRow/AmmoBar

@onready var _fps_30_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/FpsRow/BtnFps30
@onready var _fps_60_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/FpsRow/BtnFps60
@onready var _quality_low_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnLow
@onready var _quality_med_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnMedium
@onready var _quality_high_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnHigh
@onready var _aim_mode_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/ControlsRow/BtnAimMode
@onready var _volume_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/ControlsRow/BtnVolume
@onready var _music_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/AudioRow/BtnMusic
@onready var _sfx_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/AudioRow/BtnSfx
@onready var _camera_info_label: Label = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/CameraInfoLabel
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
	AudioManager.play_menu_music()
	_apply_safe_area_margins()
	_show_tab(false)
	_refresh_ui()
	get_viewport().size_changed.connect(_apply_safe_area_margins)


func _exit_tree() -> void:
	if get_viewport() != null and get_viewport().size_changed.is_connected(_apply_safe_area_margins):
		get_viewport().size_changed.disconnect(_apply_safe_area_margins)


func _apply_safe_area_margins() -> void:
	if _safe_margin == null:
		return
	var pad: Dictionary = GameManager.get_safe_area_padding(get_viewport_rect().size)
	_safe_margin.add_theme_constant_override("margin_left", int(pad["left"]))
	_safe_margin.add_theme_constant_override("margin_right", int(pad["right"]))
	_safe_margin.add_theme_constant_override("margin_top", int(pad["top"]))
	_safe_margin.add_theme_constant_override("margin_bottom", int(pad["bottom"]))


func _show_tab(show_settings: bool) -> void:
	if _loadout_panel != null:
		_loadout_panel.visible = not show_settings
	if _settings_panel != null:
		_settings_panel.visible = show_settings
	if _tab_loadout_btn != null:
		_tab_loadout_btn.button_pressed = not show_settings
	if _tab_settings_btn != null:
		_tab_settings_btn.button_pressed = show_settings


func _refresh_ui() -> void:
	var fps_target: int = SaveManager.target_fps
	_fps_30_btn.button_pressed = (fps_target == 30)
	_fps_60_btn.button_pressed = (fps_target == 60)

	_quality_low_btn.button_pressed = (SaveManager.quality_preset == "low")
	_quality_med_btn.button_pressed = (SaveManager.quality_preset == "medium")
	_quality_high_btn.button_pressed = (SaveManager.quality_preset == "high")

	var is_fire_btn: bool = (SaveManager.aim_fire_mode == "fire_button")
	_aim_mode_btn.text = "نشانه: دکمه شلیک جدا" if is_fire_btn else "نشانه: دو جوی‌استیک"

	if _volume_btn != null:
		_volume_btn.text = "بلندی صدا: %d٪" % int(round(SaveManager.master_volume * 100.0))

	if _music_btn != null:
		_music_btn.button_pressed = SaveManager.music_enabled
		_music_btn.text = "موسیقی منو: روشن" if SaveManager.music_enabled else "موسیقی منو: خاموش"

	_sfx_btn.button_pressed = SaveManager.sfx_enabled
	_sfx_btn.text = "افکت صوتی: روشن" if SaveManager.sfx_enabled else "افکت صوتی: خاموش"

	var quality_fa: String = "متوسط"
	match SaveManager.quality_preset:
		"low":
			quality_fa = "کم"
		"high":
			quality_fa = "زیاد"

	var active_mode: ArenaModeConfig = GameManager.get_active_mode_config()
	if _match_mode_btn != null and active_mode != null:
		_match_mode_btn.text = "حالت نبرد: %s (هدف: %d | %dث)" % [
			active_mode.display_name,
			active_mode.target_score,
			int(active_mode.round_duration_sec)
		]

	_refresh_blaster_preview()

	var cam_cfg: CameraConfig = CameraConfig.from_project_settings()
	_camera_info_label.text = (
		"دوربین BombSquad: زاویه %.1f° | فاصله %.1f متر | زاویه دید %.0f°\n"
		+ "میدان نبرد ۲×۳ با آیتم‌های بازیابی و پشتیبانی چندلمسی."
	) % [cam_cfg.pitch_degrees, cam_cfg.distance, cam_cfg.fov_degrees]

	var win_pct: int = 0
	if SaveManager.total_matches > 0:
		win_pct = int(round((float(SaveManager.total_wins) / float(SaveManager.total_matches)) * 100.0))

	_status_label.text = "کارنامه آفلاین: %d نبرد | %d پیروزی (%d٪) | %d حذف   •   هدف: %d FPS | کیفیت: %s" % [
		SaveManager.total_matches,
		SaveManager.total_wins,
		win_pct,
		SaveManager.total_eliminations,
		fps_target,
		quality_fa
	]


func _refresh_blaster_preview() -> void:
	var bid: String = SaveManager.starting_blaster_id
	if _blaster_pulse_btn != null:
		_blaster_pulse_btn.button_pressed = (bid == "pulse_blaster")
	if _blaster_repeater_btn != null:
		_blaster_repeater_btn.button_pressed = (bid == "rapid_repeater")
	if _blaster_scatter_btn != null:
		_blaster_scatter_btn.button_pressed = (bid == "plasma_scatter")

	var path: String = str(BLASTER_PATHS.get(bid, BLASTER_PATHS["pulse_blaster"]))
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is EnergyBlasterData:
			var b := res as EnergyBlasterData
			var total_dmg: float = b.energy_damage * float(maxi(1, b.pellets_per_shot))
			var fire_rate: float = 1.0 / maxf(b.pulse_cooldown, 0.08)
			if _damage_bar != null:
				_damage_bar.value = clampf(total_dmg, 0.0, _damage_bar.max_value)
			if _rate_bar != null:
				_rate_bar.value = clampf(fire_rate, 0.0, _rate_bar.max_value)
			if _ammo_bar != null:
				_ammo_bar.value = clampf(float(b.energy_cell_capacity), 0.0, _ammo_bar.max_value)
			if _blaster_desc_label != null:
				if bid == "rapid_repeater":
					_blaster_desc_label.text = "رگبار سریع: شلیک پیوسته با خشاب بزرگ ۳۰ تایی برای فشار مداوم."
					_blaster_desc_label.add_theme_color_override("font_color", Color(0.984314, 0.572549, 0.235294, 1.0))
				elif bid == "plasma_scatter":
					_blaster_desc_label.text = "پخش‌کننده پلاسما: شلیک ۳ تیر همزمان با قدرت تخریب بالا در برد نزدیک."
					_blaster_desc_label.add_theme_color_override("font_color", Color(0.752941, 0.517647, 0.988235, 1.0))
				else:
					_blaster_desc_label.text = "پالس بلاستر: سلاح دقیق و متعادل برای نبرد در تمام فواصل میدان."
					_blaster_desc_label.add_theme_color_override("font_color", Color(0.219608, 0.741176, 0.972549, 1.0))


func _on_btn_enter_arena_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_arena_sector_01()


func _on_btn_match_mode_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_mode_id: String = "team_score_rush" if SaveManager.selected_mode_id == "zone_control" else "zone_control"
	GameManager.set_selected_mode(next_mode_id)
	_refresh_ui()


func _on_btn_tab_loadout_pressed() -> void:
	AudioManager.play_ui_click()
	_show_tab(false)


func _on_btn_tab_settings_pressed() -> void:
	AudioManager.play_ui_click()
	_show_tab(true)


func _on_btn_blaster_pulse_pressed() -> void:
	AudioManager.play_ui_click()
	GameManager.set_starting_blaster("pulse_blaster")
	_refresh_ui()


func _on_btn_blaster_repeater_pressed() -> void:
	AudioManager.play_ui_click(1.06)
	GameManager.set_starting_blaster("rapid_repeater")
	_refresh_ui()


func _on_btn_blaster_scatter_pressed() -> void:
	AudioManager.play_ui_click(0.92)
	GameManager.set_starting_blaster("plasma_scatter")
	_refresh_ui()


func _on_btn_camera_test_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_camera_test()


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


func _on_btn_volume_pressed() -> void:
	var cur: float = SaveManager.master_volume
	var next_vol: float = 0.85
	if cur < 0.50:
		next_vol = 0.60
	elif cur < 0.72:
		next_vol = 0.85
	elif cur < 0.94:
		next_vol = 1.00
	else:
		next_vol = 0.35
	AudioManager.set_master_volume(next_vol)
	AudioManager.play_ui_pop()
	_refresh_ui()


func _on_btn_music_pressed() -> void:
	var next_music: bool = not SaveManager.music_enabled
	AudioManager.set_music_enabled(next_music)
	AudioManager.play_ui_click()
	_refresh_ui()


func _on_btn_sfx_pressed() -> void:
	var next_enabled: bool = not SaveManager.sfx_enabled
	AudioManager.set_sfx_enabled(next_enabled)
	if next_enabled:
		AudioManager.play_ui_pop()
	_refresh_ui()
