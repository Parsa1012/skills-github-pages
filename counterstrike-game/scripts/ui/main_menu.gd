extends Control
## منوی اصلی و لابی تاکتیکی آفلاین (انتخاب نقشه، حالت نبرد، ۴ سلاح شروع، تنظیمات و سیستم رتبه).

const BLASTER_PATHS: Dictionary = {
	"pulse_blaster": "res://data/blasters/pulse_blaster.tres",
	"rapid_repeater": "res://data/blasters/rapid_repeater.tres",
	"plasma_scatter": "res://data/blasters/plasma_scatter.tres",
	"arc_railgun": "res://data/blasters/arc_railgun.tres"
}

@onready var _safe_margin: MarginContainer = $SafeMargin
@onready var _select_map_btn: Button = $SafeMargin/MainLayout/ContentRow/ActionColumn/BtnSelectMap
@onready var _match_mode_btn: Button = $SafeMargin/MainLayout/ContentRow/ActionColumn/BtnMatchMode
@onready var _tab_loadout_btn: Button = $SafeMargin/MainLayout/ContentRow/ActionColumn/TabSwitcherRow/BtnTabLoadout
@onready var _tab_arena_btn: Button = $SafeMargin/MainLayout/ContentRow/ActionColumn/TabSwitcherRow/BtnTabArena
@onready var _tab_settings_btn: Button = $SafeMargin/MainLayout/ContentRow/ActionColumn/TabSwitcherRow/BtnTabSettings
@onready var _loadout_panel: PanelContainer = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel
@onready var _arena_panel: PanelContainer = $SafeMargin/MainLayout/ContentRow/DetailColumn/ArenaPanel
@onready var _settings_panel: PanelContainer = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel

@onready var _blaster_pulse_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterRow/BtnBlasterPulse
@onready var _blaster_repeater_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterRow/BtnBlasterRepeater
@onready var _blaster_scatter_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterRow/BtnBlasterScatter
@onready var _blaster_railgun_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterRow/BtnBlasterRailgun
@onready var _blaster_desc_label: Label = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/BlasterDescLabel
@onready var _damage_bar: ProgressBar = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/DmgRow/DamageBar
@onready var _rate_bar: ProgressBar = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/RateRow/FireRateBar
@onready var _ammo_bar: ProgressBar = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/AmmoRow/AmmoBar
@onready var _speed_bar: ProgressBar = $SafeMargin/MainLayout/ContentRow/DetailColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/VelRow/SpeedBar

@onready var _map_info_label: Label = $SafeMargin/MainLayout/ContentRow/DetailColumn/ArenaPanel/ArenaMargin/ArenaVBox/MapInfoCard/MapInfoLabel
@onready var _mode_info_label: Label = $SafeMargin/MainLayout/ContentRow/DetailColumn/ArenaPanel/ArenaMargin/ArenaVBox/ModeInfoCard/ModeInfoLabel

@onready var _fps_30_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/FpsRow/BtnFps30
@onready var _fps_60_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/FpsRow/BtnFps60
@onready var _quality_low_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnLow
@onready var _quality_med_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnMedium
@onready var _quality_high_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnHigh
@onready var _aim_mode_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/ControlsRow/BtnAimMode
@onready var _sensitivity_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/ControlsRow/BtnSensitivity
@onready var _cam_preset_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/CameraAudioRow/BtnCamPreset
@onready var _difficulty_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/CameraAudioRow/BtnDifficulty
@onready var _music_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/AudioRow/BtnMusic
@onready var _sfx_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/AudioRow/BtnSfx
@onready var _volume_btn: Button = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/AudioRow/BtnVolume
@onready var _rank_label: Label = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/RankCard/RankVBox/RankLabel
@onready var _rank_xp_bar: ProgressBar = $SafeMargin/MainLayout/ContentRow/DetailColumn/SettingsPanel/SettingsMargin/SettingsVBox/RankCard/RankVBox/RankXpBar
@onready var _status_label: Label = $SafeMargin/MainLayout/FooterBar/StatusLabel


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	if _safe_margin != null:
		_safe_margin.layout_direction = Control.LAYOUT_DIRECTION_RTL
	if _status_label != null:
		_status_label.text_direction = Control.TEXT_DIRECTION_RTL

	GameManager.current_state = GameManager.AppState.MAIN_MENU
	AudioManager.play_menu_music()
	_apply_safe_area_margins()
	_show_tab(0)
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


func _show_tab(tab_idx: int) -> void:
	if _loadout_panel != null:
		_loadout_panel.visible = (tab_idx == 0)
	if _arena_panel != null:
		_arena_panel.visible = (tab_idx == 1)
	if _settings_panel != null:
		_settings_panel.visible = (tab_idx == 2)
	if _tab_loadout_btn != null:
		_tab_loadout_btn.button_pressed = (tab_idx == 0)
	if _tab_arena_btn != null:
		_tab_arena_btn.button_pressed = (tab_idx == 1)
	if _tab_settings_btn != null:
		_tab_settings_btn.button_pressed = (tab_idx == 2)


func _refresh_ui() -> void:
	var fps_target: int = SaveManager.target_fps
	_fps_30_btn.button_pressed = (fps_target == 30)
	_fps_60_btn.button_pressed = (fps_target == 60)

	_quality_low_btn.button_pressed = (SaveManager.quality_preset == "low")
	_quality_med_btn.button_pressed = (SaveManager.quality_preset == "medium")
	_quality_high_btn.button_pressed = (SaveManager.quality_preset == "high")

	var is_fire_btn: bool = (SaveManager.aim_fire_mode == "fire_button")
	_aim_mode_btn.text = "نشانه: دکمه شلیک جدا" if is_fire_btn else "نشانه: دو جوی‌استیک"

	if _sensitivity_btn != null:
		_sensitivity_btn.text = "حساسیت لمس: تند" if SaveManager.joystick_sensitivity > 1.1 else "حساسیت لمس: معمولی"

	if _cam_preset_btn != null:
		match SaveManager.camera_preset:
			"tactical":
				_cam_preset_btn.text = "دوربین: تاکتیکی ۶۳°"
			"close":
				_cam_preset_btn.text = "دوربین: نزدیک ۵۲°"
			_:
				_cam_preset_btn.text = "دوربین: کلاسیک ۵۷.۵°"

	if _volume_btn != null:
		_volume_btn.text = "بلندی: %d٪" % int(round(SaveManager.master_volume * 100.0))

	if _difficulty_btn != null:
		match SaveManager.bot_difficulty:
			"easy":
				_difficulty_btn.text = "سختی حریف: آسان"
			"hard":
				_difficulty_btn.text = "سختی حریف: حرفه‌ای"
			_:
				_difficulty_btn.text = "سختی حریف: متعادل"

	if _music_btn != null:
		_music_btn.button_pressed = SaveManager.music_enabled
		_music_btn.text = "موسیقی: روشن" if SaveManager.music_enabled else "موسیقی: خاموش"

	_sfx_btn.button_pressed = SaveManager.sfx_enabled
	_sfx_btn.text = "افکت: روشن" if SaveManager.sfx_enabled else "افکت: خاموش"

	if _select_map_btn != null:
		_select_map_btn.text = "نقشه: بخش ۰۲ (دژ مرکزی)" if SaveManager.selected_map_id == "sector_02" else "نقشه: بخش ۰۱ (پایگاه فولادی)"

	var active_mode: ArenaModeConfig = GameManager.get_active_mode_config()
	if _match_mode_btn != null and active_mode != null:
		_match_mode_btn.text = "حالت: %s (هدف: %d | %dث)" % [
			active_mode.display_name,
			active_mode.target_score,
			int(active_mode.round_duration_sec)
		]

	_refresh_blaster_preview()
	_refresh_arena_overview(active_mode)

	var rank: Dictionary = SaveManager.get_rank_info()
	if _rank_label != null:
		_rank_label.text = "رتبه %d (%s)  •  تجربه: %d XP  •  رکورد حذف در یک نبرد: %d" % [
			int(rank["level"]),
			str(rank["title_fa"]),
			int(rank["xp"]),
			SaveManager.best_match_eliminations
		]
	if _rank_xp_bar != null:
		_rank_xp_bar.value = float(rank["progress"]) * 100.0

	var quality_fa: String = "متوسط"
	match SaveManager.quality_preset:
		"low":
			quality_fa = "کم"
		"high":
			quality_fa = "زیاد"

	var diff_fa: String = "متعادل"
	match SaveManager.bot_difficulty:
		"easy":
			diff_fa = "آسان"
		"hard":
			diff_fa = "حرفه‌ای"

	var win_pct: int = 0
	if SaveManager.total_matches > 0:
		win_pct = int(round((float(SaveManager.total_wins) / float(SaveManager.total_matches)) * 100.0))

	_status_label.text = "رتبه %d (%s) | %d نبرد • %d پیروزی (%d٪) • %d حذف  |  حریف: %s • %d FPS • کیفیت: %s" % [
		int(rank["level"]),
		str(rank["title_fa"]),
		SaveManager.total_matches,
		SaveManager.total_wins,
		win_pct,
		SaveManager.total_eliminations,
		diff_fa,
		fps_target,
		quality_fa
	]


func _refresh_arena_overview(active_mode: ArenaModeConfig) -> void:
	if _map_info_label != null:
		if SaveManager.selected_map_id == "sector_02":
			_map_info_label.text = (
				"نقشه فعال: بخش ۰۲ — دژ مرکزی (۳۴×۲۴ متر، تم گرم صنعتی)\n"
				+ "میدان باز مرکزی با ۴ ستون پوششی، سنگرهای جناحی، برجک شمال و حیاط جنوب + تقویت انرژی در قلب میدان."
			)
		else:
			_map_info_label.text = (
				"نقشه فعال: بخش ۰۱ — پایگاه فولادی (۳۲×۲۴ متر، تم شب سایبر)\n"
				+ "سکوی مرتفع مرکزی با دو رمپ دسترسی، موانع متقارن و دو منطقهٔ شمال و جنوب + بسته‌های سپر در دو جناح."
			)

	if _mode_info_label != null and active_mode != null:
		if active_mode.enable_capture_zones:
			_mode_info_label.text = (
				"قوانین %s: هدف %d امتیاز در %d ثانیه | تصرف هر منطقه در %.1f ثانیه (+%d امتیاز) و +%d امتیاز دوره‌ای هر %.1f ثانیه."
			) % [
				active_mode.display_name,
				active_mode.target_score,
				int(active_mode.round_duration_sec),
				active_mode.zone_capture_seconds,
				active_mode.zone_capture_bonus,
				active_mode.zone_hold_points,
				active_mode.zone_hold_tick_interval
			]
		else:
			_mode_info_label.text = (
				"قوانین %s: هدف %d حذف تیمی در %d ثانیه | مناطق غیرفعال و تمرکز کامل روی نبرد مستقیم تیمی و جمع‌آوری باف‌ها."
			) % [active_mode.display_name, active_mode.target_score, int(active_mode.round_duration_sec)]


func _refresh_blaster_preview() -> void:
	var bid: String = SaveManager.starting_blaster_id
	if _blaster_pulse_btn != null:
		_blaster_pulse_btn.button_pressed = (bid == "pulse_blaster")
	if _blaster_repeater_btn != null:
		_blaster_repeater_btn.button_pressed = (bid == "rapid_repeater")
	if _blaster_scatter_btn != null:
		_blaster_scatter_btn.button_pressed = (bid == "plasma_scatter")
	if _blaster_railgun_btn != null:
		_blaster_railgun_btn.button_pressed = (bid == "arc_railgun")

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
			if _speed_bar != null:
				_speed_bar.value = clampf(b.projectile_speed, 0.0, _speed_bar.max_value)
			if _blaster_desc_label != null:
				if bid == "rapid_repeater":
					_blaster_desc_label.text = "رگبار انرژی: شلیک سریع با خشاب بزرگ ۳۰ تایی و گلوله‌های پرسرعت."
					_blaster_desc_label.add_theme_color_override("font_color", Color(0.984314, 0.572549, 0.235294, 1.0))
				elif bid == "plasma_scatter":
					_blaster_desc_label.text = "پخش‌کننده پلاسما: شلیک ۳ گوی پلاسما همزمان برای درگیری نزدیک و تخریب سریع."
					_blaster_desc_label.add_theme_color_override("font_color", Color(0.752941, 0.517647, 0.988235, 1.0))
				elif bid == "arc_railgun":
					_blaster_desc_label.text = "ریل‌گان کمانی: پرتو فوق‌سریع با قابلیت نفوذ از هدف اول و آسیب بسیار بالا (۴۶)."
					_blaster_desc_label.add_theme_color_override("font_color", Color(0.984314, 0.74902, 0.141176, 1.0))
				else:
					_blaster_desc_label.text = "پالس بلاستر: سلاح دقیق و متعادل برای نبرد در تمام فواصل میدان."
					_blaster_desc_label.add_theme_color_override("font_color", Color(0.219608, 0.741176, 0.972549, 1.0))


func _on_btn_enter_arena_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_selected_arena()


func _on_btn_select_map_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_map: String = "sector_02" if SaveManager.selected_map_id == "sector_01" else "sector_01"
	GameManager.set_selected_map(next_map)
	_refresh_ui()


func _on_btn_match_mode_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_mode_id: String = "zone_control"
	match SaveManager.selected_mode_id:
		"zone_control":
			next_mode_id = "team_score_rush"
		"team_score_rush":
			next_mode_id = "zone_blitz"
		_:
			next_mode_id = "zone_control"
	GameManager.set_selected_mode(next_mode_id)
	_refresh_ui()


func _on_btn_tab_loadout_pressed() -> void:
	AudioManager.play_ui_click()
	_show_tab(0)


func _on_btn_tab_arena_pressed() -> void:
	AudioManager.play_ui_click()
	_show_tab(1)


func _on_btn_tab_settings_pressed() -> void:
	AudioManager.play_ui_click()
	_show_tab(2)


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


func _on_btn_blaster_railgun_pressed() -> void:
	AudioManager.play_ui_click(0.84)
	GameManager.set_starting_blaster("arc_railgun")
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


func _on_btn_sensitivity_pressed() -> void:
	AudioManager.play_ui_click()
	var next_sens: float = 1.25 if SaveManager.joystick_sensitivity <= 1.1 else 1.0
	GameManager.set_joystick_sensitivity(next_sens)
	_refresh_ui()


func _on_btn_cam_preset_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_cam: String = "classic"
	match SaveManager.camera_preset:
		"classic":
			next_cam = "tactical"
		"tactical":
			next_cam = "close"
		_:
			next_cam = "classic"
	GameManager.set_camera_preset(next_cam)
	_refresh_ui()


func _on_btn_difficulty_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_diff: String = "balanced"
	match SaveManager.bot_difficulty:
		"easy":
			next_diff = "balanced"
		"balanced":
			next_diff = "hard"
		_:
			next_diff = "easy"
	GameManager.set_bot_difficulty(next_diff)
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
