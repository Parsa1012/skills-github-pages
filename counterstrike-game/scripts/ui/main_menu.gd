extends Control
## منوی اصلی و لابی تاکتیکی ۳بعدی (پیش‌نمایش زنده قهرمان و سلاح، انتخاب نقشه و حالت، تنظیمات و کارنامه آفلاین).

const BLASTER_ORDER: Array[String] = [
	"pulse_blaster",
	"rapid_repeater",
	"plasma_scatter",
	"arc_railgun"
]

const BLASTER_PATHS: Dictionary = {
	"pulse_blaster": "res://data/blasters/pulse_blaster.tres",
	"rapid_repeater": "res://data/blasters/rapid_repeater.tres",
	"plasma_scatter": "res://data/blasters/plasma_scatter.tres",
	"arc_railgun": "res://data/blasters/arc_railgun.tres"
}

@onready var _lobby_stage: LobbyStage3D = $LobbyViewportContainer/LobbyViewport/LobbyStage3D
@onready var _safe_margin: MarginContainer = $SafeMargin

@onready var _rank_num_label: Label = $SafeMargin/MainLayout/TopHeader/RankHeroCard/RankHBox/RankCrest/RankNumLabel
@onready var _rank_title_header_label: Label = $SafeMargin/MainLayout/TopHeader/RankHeroCard/RankHBox/RankTextVBox/RankTitleLabel
@onready var _rank_xp_header_bar: ProgressBar = $SafeMargin/MainLayout/TopHeader/RankHeroCard/RankHBox/RankTextVBox/RankXpBar
@onready var _career_summary_label: Label = $SafeMargin/MainLayout/TopHeader/QuickBar/CareerPill/CareerSummaryLabel
@onready var _quick_music_btn: Button = $SafeMargin/MainLayout/TopHeader/QuickBar/BtnQuickMusic
@onready var _quick_sfx_btn: Button = $SafeMargin/MainLayout/TopHeader/QuickBar/BtnQuickSfx

@onready var _tab_loadout_btn: Button = $SafeMargin/MainLayout/MiddleStage/NavRail/BtnTabLoadout
@onready var _tab_arena_btn: Button = $SafeMargin/MainLayout/MiddleStage/NavRail/BtnTabArena
@onready var _tab_settings_btn: Button = $SafeMargin/MainLayout/MiddleStage/NavRail/BtnTabSettings
@onready var _select_map_btn: Button = $SafeMargin/MainLayout/MiddleStage/NavRail/QuickMatchCard/QuickMargin/QuickVBox/BtnSelectMap
@onready var _match_mode_btn: Button = $SafeMargin/MainLayout/MiddleStage/NavRail/QuickMatchCard/QuickMargin/QuickVBox/BtnMatchMode
@onready var _quick_diff_btn: Button = $SafeMargin/MainLayout/MiddleStage/NavRail/QuickMatchCard/QuickMargin/QuickVBox/BtnQuickDiff

@onready var _hero_weapon_label: Label = $SafeMargin/MainLayout/MiddleStage/CenterHeroStage/HeroWeaponQuickBar/WeaponPillRow/HeroWeaponLabel
@onready var _loadout_panel: PanelContainer = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel
@onready var _arena_panel: PanelContainer = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/ArenaPanel
@onready var _settings_panel: PanelContainer = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel

@onready var _blaster_pulse_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterGrid/BtnBlasterPulse
@onready var _blaster_repeater_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterGrid/BtnBlasterRepeater
@onready var _blaster_scatter_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterGrid/BtnBlasterScatter
@onready var _blaster_railgun_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterGrid/BtnBlasterRailgun
@onready var _blaster_desc_label: Label = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/BlasterDescLabel
@onready var _damage_bar: ProgressBar = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/DmgRow/DamageBar
@onready var _damage_val: Label = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/DmgRow/DamageVal
@onready var _rate_bar: ProgressBar = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/RateRow/FireRateBar
@onready var _rate_val: Label = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/RateRow/RateVal
@onready var _ammo_bar: ProgressBar = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/AmmoRow/AmmoBar
@onready var _ammo_val: Label = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/AmmoRow/AmmoVal
@onready var _speed_bar: ProgressBar = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/VelRow/SpeedBar
@onready var _speed_val: Label = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/LoadoutPanel/LoadoutMargin/LoadoutVBox/BlasterStatCard/StatVBox/VelRow/SpeedVal

@onready var _map_s01_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/ArenaPanel/ArenaMargin/ArenaVBox/MapCardsRow/BtnMapSector01
@onready var _map_s02_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/ArenaPanel/ArenaMargin/ArenaVBox/MapCardsRow/BtnMapSector02
@onready var _mode_zc_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/ArenaPanel/ArenaMargin/ArenaVBox/ModeCardsCol/BtnModeZoneControl
@onready var _mode_tr_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/ArenaPanel/ArenaMargin/ArenaVBox/ModeCardsCol/BtnModeTeamRush
@onready var _mode_zb_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/ArenaPanel/ArenaMargin/ArenaVBox/ModeCardsCol/BtnModeZoneBlitz
@onready var _map_info_label: Label = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/ArenaPanel/ArenaMargin/ArenaVBox/MapInfoCard/MapInfoLabel
@onready var _mode_info_label: Label = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/ArenaPanel/ArenaMargin/ArenaVBox/RosterCard/ModeInfoLabel

@onready var _fps_30_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/FpsRow/BtnFps30
@onready var _fps_60_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/FpsRow/BtnFps60
@onready var _quality_low_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnLow
@onready var _quality_med_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnMedium
@onready var _quality_high_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/QualityRow/BtnHigh
@onready var _aim_mode_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/ControlsRow/BtnAimMode
@onready var _sensitivity_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/ControlsRow/BtnSensitivity
@onready var _difficulty_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/TacticalRow/BtnDifficulty
@onready var _cam_preset_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/TacticalRow/BtnCamPreset
@onready var _music_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/AudioRow/BtnMusic
@onready var _sfx_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/AudioRow/BtnSfx
@onready var _volume_btn: Button = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/AudioRow/BtnVolume
@onready var _rank_label: Label = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/RankCard/RankVBox/RankLabel
@onready var _career_detail_label: Label = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/RankCard/RankVBox/CareerDetailLabel
@onready var _settings_xp_bar: ProgressBar = $SafeMargin/MainLayout/MiddleStage/InspectorColumn/SettingsPanel/SettingsMargin/SettingsVBox/RankCard/RankVBox/SettingsXpBar

@onready var _status_label: Label = $SafeMargin/MainLayout/BottomLaunchDock/TicketCard/StatusLabel
@onready var _enter_arena_btn: Button = $SafeMargin/MainLayout/BottomLaunchDock/BtnEnterArena

var _active_tab: int = -1
var _stat_tween: Tween = null
var _tab_tween: Tween = null
var _cta_pulse_time: float = 0.0
var _dragging_hero: bool = false


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	if _safe_margin != null:
		_safe_margin.layout_direction = Control.LAYOUT_DIRECTION_RTL
	if _status_label != null:
		_status_label.text_direction = Control.TEXT_DIRECTION_RTL
	var pill_row: HBoxContainer = get_node_or_null("SafeMargin/MainLayout/MiddleStage/CenterHeroStage/HeroWeaponQuickBar/WeaponPillRow") as HBoxContainer
	if pill_row != null:
		pill_row.layout_direction = Control.LAYOUT_DIRECTION_LTR

	GameManager.current_state = GameManager.AppState.MAIN_MENU
	AudioManager.play_menu_music()
	_apply_safe_area_margins()
	_show_tab(0, false)
	_refresh_ui()
	get_viewport().size_changed.connect(_apply_safe_area_margins)


func _exit_tree() -> void:
	if get_viewport() != null and get_viewport().size_changed.is_connected(_apply_safe_area_margins):
		get_viewport().size_changed.disconnect(_apply_safe_area_margins)


func _process(delta: float) -> void:
	_cta_pulse_time += delta
	if _enter_arena_btn != null:
		var glow: float = 0.93 + 0.07 * sin(_cta_pulse_time * 3.1)
		_enter_arena_btn.modulate = Color(glow, clampf(glow + 0.05, 0.0, 1.0), 1.0, 1.0)


func _apply_safe_area_margins() -> void:
	if _safe_margin == null:
		return
	var pad: Dictionary = GameManager.get_safe_area_padding(get_viewport_rect().size)
	_safe_margin.add_theme_constant_override("margin_left", int(pad["left"]))
	_safe_margin.add_theme_constant_override("margin_right", int(pad["right"]))
	_safe_margin.add_theme_constant_override("margin_top", int(pad["top"]))
	_safe_margin.add_theme_constant_override("margin_bottom", int(pad["bottom"]))


func _show_tab(tab_idx: int, animate: bool = true) -> void:
	var changed: bool = (tab_idx != _active_tab)
	_active_tab = tab_idx
	var panels: Array[PanelContainer] = [_loadout_panel, _arena_panel, _settings_panel]
	for i in panels.size():
		var p: PanelContainer = panels[i]
		if p != null:
			p.visible = (i == tab_idx)

	if _tab_loadout_btn != null:
		_tab_loadout_btn.button_pressed = (tab_idx == 0)
	if _tab_arena_btn != null:
		_tab_arena_btn.button_pressed = (tab_idx == 1)
	if _tab_settings_btn != null:
		_tab_settings_btn.button_pressed = (tab_idx == 2)

	if _lobby_stage != null:
		_lobby_stage.focus_for_tab(tab_idx)

	if animate and changed and tab_idx >= 0 and tab_idx < panels.size():
		var active_panel: PanelContainer = panels[tab_idx]
		if active_panel != null and is_inside_tree():
			if _tab_tween != null and _tab_tween.is_valid():
				_tab_tween.kill()
			active_panel.modulate = Color(1.0, 1.0, 1.0, 0.25)
			_tab_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tab_tween.tween_property(active_panel, "modulate", Color.WHITE, 0.22)


func _refresh_ui() -> void:
	var fps_target: int = SaveManager.target_fps
	_fps_30_btn.button_pressed = (fps_target == 30)
	_fps_60_btn.button_pressed = (fps_target == 60)

	_quality_low_btn.button_pressed = (SaveManager.quality_preset == "low")
	_quality_med_btn.button_pressed = (SaveManager.quality_preset == "medium")
	_quality_high_btn.button_pressed = (SaveManager.quality_preset == "high")

	var is_fire_btn: bool = (SaveManager.aim_fire_mode == "fire_button")
	_aim_mode_btn.text = "نشانه: دکمه جدا" if is_fire_btn else "نشانه: دو جوی‌استیک"

	if _sensitivity_btn != null:
		_sensitivity_btn.text = "حساسیت: تند" if SaveManager.joystick_sensitivity > 1.1 else "حساسیت: معمولی"

	if _cam_preset_btn != null:
		match SaveManager.camera_preset:
			"tactical":
				_cam_preset_btn.text = "نمای نبرد: گسترده"
			"close":
				_cam_preset_btn.text = "نمای نبرد: نزدیک"
			_:
				_cam_preset_btn.text = "نمای نبرد: استاندارد"

	if _volume_btn != null:
		_volume_btn.text = "بلندی: %d٪" % int(round(SaveManager.master_volume * 100.0))

	var diff_fa: String = "متعادل"
	match SaveManager.bot_difficulty:
		"easy":
			diff_fa = "آسان"
		"hard":
			diff_fa = "حرفه‌ای"
	if _difficulty_btn != null:
		_difficulty_btn.text = "حریف: %s" % diff_fa
	if _quick_diff_btn != null:
		_quick_diff_btn.text = "سختی حریف: %s" % diff_fa

	var music_txt: String = "موسیقی: روشن" if SaveManager.music_enabled else "موسیقی: خاموش"
	var sfx_txt: String = "افکت: روشن" if SaveManager.sfx_enabled else "افکت: خاموش"
	if _music_btn != null:
		_music_btn.button_pressed = SaveManager.music_enabled
		_music_btn.text = music_txt
	if _quick_music_btn != null:
		_quick_music_btn.button_pressed = SaveManager.music_enabled
		_quick_music_btn.text = music_txt
	if _sfx_btn != null:
		_sfx_btn.button_pressed = SaveManager.sfx_enabled
		_sfx_btn.text = sfx_txt
	if _quick_sfx_btn != null:
		_quick_sfx_btn.button_pressed = SaveManager.sfx_enabled
		_quick_sfx_btn.text = sfx_txt

	var is_s02: bool = (SaveManager.selected_map_id == "sector_02")
	var map_name_fa: String = "دژ مرکزی" if is_s02 else "پایگاه فولادی"
	if _select_map_btn != null:
		_select_map_btn.text = "نقشه: %s" % map_name_fa
	if _map_s01_btn != null:
		_map_s01_btn.button_pressed = not is_s02
	if _map_s02_btn != null:
		_map_s02_btn.button_pressed = is_s02

	if _lobby_stage != null:
		_lobby_stage.set_map_theme(SaveManager.selected_map_id)

	var active_mode: ArenaModeConfig = GameManager.get_active_mode_config()
	var mode_id: String = SaveManager.selected_mode_id
	if _mode_zc_btn != null:
		_mode_zc_btn.button_pressed = (mode_id == "zone_control")
	if _mode_tr_btn != null:
		_mode_tr_btn.button_pressed = (mode_id == "team_score_rush")
	if _mode_zb_btn != null:
		_mode_zb_btn.button_pressed = (mode_id == "zone_blitz")
	if _match_mode_btn != null and active_mode != null:
		_match_mode_btn.text = "حالت: %s (%d)" % [active_mode.display_name, active_mode.target_score]

	_refresh_blaster_preview()
	_refresh_arena_overview(active_mode)

	var rank: Dictionary = SaveManager.get_rank_info()
	var win_pct: int = 0
	if SaveManager.total_matches > 0:
		win_pct = int(round((float(SaveManager.total_wins) / float(SaveManager.total_matches)) * 100.0))

	if _rank_num_label != null:
		_rank_num_label.text = str(int(rank["level"]))
	if _rank_title_header_label != null:
		_rank_title_header_label.text = "%s • %d XP" % [str(rank["title_fa"]), int(rank["xp"])]
	if _rank_xp_header_bar != null:
		_rank_xp_header_bar.value = float(rank["progress"]) * 100.0
	if _career_summary_label != null:
		_career_summary_label.text = "%d پیروزی • %d حذف" % [SaveManager.total_wins, SaveManager.total_eliminations]

	if _rank_label != null:
		_rank_label.text = "رتبه %d (%s) • %d XP" % [int(rank["level"]), str(rank["title_fa"]), int(rank["xp"])]
	if _career_detail_label != null:
		_career_detail_label.text = "%d نبرد • %d پیروزی (%d٪) • %d حذف • بهترین رکورد: %d" % [
			SaveManager.total_matches,
			SaveManager.total_wins,
			win_pct,
			SaveManager.total_eliminations,
			SaveManager.best_match_eliminations
		]
	if _settings_xp_bar != null:
		_settings_xp_bar.value = float(rank["progress"]) * 100.0

	var weapon_fa: String = _get_weapon_title_fa(SaveManager.starting_blaster_id)
	var mode_fa: String = active_mode.display_name if active_mode != null else "کنترل مناطق"
	var quality_fa: String = "زیاد" if SaveManager.quality_preset == "high" else ("کم" if SaveManager.quality_preset == "low" else "متوسط")
	_status_label.text = "آماده اعزام: %s  •  %s  •  %s  •  حریف %s  (%d FPS / %s)" % [
		map_name_fa,
		mode_fa,
		weapon_fa,
		diff_fa,
		fps_target,
		quality_fa
	]


func _get_weapon_title_fa(bid: String) -> String:
	match bid:
		"rapid_repeater":
			return "رگبار انرژی"
		"plasma_scatter":
			return "پخش‌کننده پلاسما"
		"arc_railgun":
			return "ریل‌گان کمانی"
		_:
			return "پالس بلاستر"


func _get_weapon_accent(bid: String) -> Color:
	match bid:
		"rapid_repeater":
			return Color(0.984314, 0.572549, 0.235294, 1.0)
		"plasma_scatter":
			return Color(0.752941, 0.517647, 0.988235, 1.0)
		"arc_railgun":
			return Color(0.984314, 0.74902, 0.141176, 1.0)
		_:
			return Color(0.219608, 0.741176, 0.972549, 1.0)


func _refresh_arena_overview(active_mode: ArenaModeConfig) -> void:
	if _map_info_label != null:
		if SaveManager.selected_map_id == "sector_02":
			_map_info_label.text = (
				"بخش ۰۲ — دژ مرکزی (۳۴×۲۴ متر، تم گرم صنعتی)\n"
				+ "۴ ستون پوششی، سنگرهای جناحی، ۲ جعبه انفجاری در گلوگاه‌ها و بسته تقویت در قلب میدان."
			)
		else:
			_map_info_label.text = (
				"بخش ۰۱ — پایگاه فولادی (۳۲×۲۴ متر، تم شب سایبر)\n"
				+ "سکوی مرتفع مرکزی با دو رمپ دسترسی، ۲ جعبه انفجاری و مناطق تصرف متقارن شمال و جنوب."
			)

	if _mode_info_label != null and active_mode != null:
		if active_mode.enable_capture_zones:
			_mode_info_label.text = (
				"قوانین %s: هدف %d امتیاز در %d ثانیه | تصرف هر منطقه در %.1f ثانیه (+%d امتیاز) و +%d امتیاز هر %.1f ثانیه.\n"
				+ "تیم آبی (شما + ۱ هم‌تیمی) در برابر ۳ رقیب نارنجی با هوش مصنوعی تاکتیکی."
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
				"قوانین %s: هدف %d حذف تیمی در %d ثانیه | مناطق غیرفعال و تمرکز کامل روی مبارزه مستقیم ۲ در برابر ۳."
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

	var accent: Color = _get_weapon_accent(bid)
	if _hero_weapon_label != null:
		_hero_weapon_label.text = _get_weapon_title_fa(bid)
		_hero_weapon_label.add_theme_color_override("font_color", accent)

	var path: String = str(BLASTER_PATHS.get(bid, BLASTER_PATHS["pulse_blaster"]))
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is EnergyBlasterData:
			var b := res as EnergyBlasterData
			if _lobby_stage != null:
				_lobby_stage.set_weapon(b, accent)

			var total_dmg: float = b.energy_damage * float(maxi(1, b.pellets_per_shot))
			var fire_rate: float = 1.0 / maxf(b.pulse_cooldown, 0.08)

			if _damage_val != null:
				_damage_val.text = "%d" % int(round(total_dmg))
			if _rate_val != null:
				_rate_val.text = "%.1f/ث" % fire_rate
			if _ammo_val != null:
				_ammo_val.text = "%d" % b.energy_cell_capacity
			if _speed_val != null:
				_speed_val.text = "%d" % int(round(b.projectile_speed))

			if is_inside_tree():
				if _stat_tween != null and _stat_tween.is_valid():
					_stat_tween.kill()
				_stat_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				if _damage_bar != null:
					_stat_tween.tween_property(_damage_bar, "value", clampf(total_dmg, 0.0, _damage_bar.max_value), 0.28)
				if _rate_bar != null:
					_stat_tween.tween_property(_rate_bar, "value", clampf(fire_rate, 0.0, _rate_bar.max_value), 0.28)
				if _ammo_bar != null:
					_stat_tween.tween_property(_ammo_bar, "value", clampf(float(b.energy_cell_capacity), 0.0, _ammo_bar.max_value), 0.28)
				if _speed_bar != null:
					_stat_tween.tween_property(_speed_bar, "value", clampf(b.projectile_speed, 0.0, _speed_bar.max_value), 0.28)

			if _blaster_desc_label != null:
				_blaster_desc_label.add_theme_color_override("font_color", accent)
				match bid:
					"rapid_repeater":
						_blaster_desc_label.text = "رگبار انرژی: شلیک پیوسته و سریع با خشاب ۳۰ تایی و گلوله‌های پرسرعت."
					"plasma_scatter":
						_blaster_desc_label.text = "پخش‌کننده پلاسما: شلیک همزمان ۳ گوی پلاسما با رانش متوسط برای نبرد نزدیک."
					"arc_railgun":
						_blaster_desc_label.text = "ریل‌گان کمانی: پرتو فوق‌سریع با نفوذ در هدف اول، رانش قوی و آسیب ۴۶."
					_:
						_blaster_desc_label.text = "پالس بلاستر: سلاح دقیق و متعادل برای نبرد در تمام فواصل میدان."


func _on_hero_drag_zone_gui_input(event: InputEvent) -> void:
	if _lobby_stage == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_hero = mb.pressed
	elif event is InputEventMouseMotion and (_dragging_hero or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_lobby_stage.spin_by_drag((event as InputEventMouseMotion).relative.x)
	elif event is InputEventScreenDrag:
		_lobby_stage.spin_by_drag((event as InputEventScreenDrag).relative.x)


func _cycle_weapon(step: int) -> void:
	var idx: int = BLASTER_ORDER.find(SaveManager.starting_blaster_id)
	if idx < 0:
		idx = 0
	var next_idx: int = (idx + step + BLASTER_ORDER.size()) % BLASTER_ORDER.size()
	AudioManager.play_ui_click(1.0 + 0.05 * float(next_idx))
	GameManager.set_starting_blaster(BLASTER_ORDER[next_idx])
	_refresh_ui()


func _on_btn_prev_weapon_pressed() -> void:
	_cycle_weapon(-1)


func _on_btn_next_weapon_pressed() -> void:
	_cycle_weapon(1)


func _on_btn_enter_arena_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_selected_arena()


func _on_btn_select_map_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_map: String = "sector_02" if SaveManager.selected_map_id == "sector_01" else "sector_01"
	GameManager.set_selected_map(next_map)
	_refresh_ui()


func _on_btn_map_sector01_pressed() -> void:
	AudioManager.play_ui_menu()
	GameManager.set_selected_map("sector_01")
	_refresh_ui()


func _on_btn_map_sector02_pressed() -> void:
	AudioManager.play_ui_menu()
	GameManager.set_selected_map("sector_02")
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


func _on_btn_mode_zone_control_pressed() -> void:
	AudioManager.play_ui_menu()
	GameManager.set_selected_mode("zone_control")
	_refresh_ui()


func _on_btn_mode_team_rush_pressed() -> void:
	AudioManager.play_ui_menu()
	GameManager.set_selected_mode("team_score_rush")
	_refresh_ui()


func _on_btn_mode_zone_blitz_pressed() -> void:
	AudioManager.play_ui_menu()
	GameManager.set_selected_mode("zone_blitz")
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
