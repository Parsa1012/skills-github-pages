extends Control
## منوی اصلی سبک میدان نبرد نظامی «کانتر آرنا» (بدون رندر سنگین پس‌زمینه، ۵ بخش مجزا و تنظیمات کامل ۶۰ فریم).

const WEAPON_PATHS: Dictionary = {
	"pulse_blaster": "res://data/blasters/pulse_blaster.tres",
	"rapid_repeater": "res://data/blasters/rapid_repeater.tres",
	"plasma_scatter": "res://data/blasters/plasma_scatter.tres",
	"arc_railgun": "res://data/blasters/arc_railgun.tres"
}

const MODE_ORDER: Array[String] = ["zone_control", "team_score_rush", "zone_blitz"]
const DIFF_ORDER: Array[String] = ["easy", "balanced", "hard"]

@onready var _safe_margin: MarginContainer = $SafeMargin

@onready var _rank_num_label: Label = $SafeMargin/MainLayout/TopHeader/RankHeroCard/RankHBox/RankCrest/RankNumLabel
@onready var _rank_title_header_label: Label = $SafeMargin/MainLayout/TopHeader/RankHeroCard/RankHBox/RankTextVBox/RankTitleLabel
@onready var _rank_xp_header_bar: ProgressBar = $SafeMargin/MainLayout/TopHeader/RankHeroCard/RankHBox/RankTextVBox/RankXpBar
@onready var _quick_music_btn: Button = $SafeMargin/MainLayout/TopHeader/QuickAudioBar/BtnQuickMusic
@onready var _quick_sfx_btn: Button = $SafeMargin/MainLayout/TopHeader/QuickAudioBar/BtnQuickSfx

@onready var _tab_btns: Array[Button] = [
	$SafeMargin/MainLayout/ContentSplit/NavRail/BtnTabHome,
	$SafeMargin/MainLayout/ContentSplit/NavRail/BtnTabArsenal,
	$SafeMargin/MainLayout/ContentSplit/NavRail/BtnTabArena,
	$SafeMargin/MainLayout/ContentSplit/NavRail/BtnTabSettings,
	$SafeMargin/MainLayout/ContentSplit/NavRail/BtnTabProfile
]
@onready var _quick_status_label: Label = $SafeMargin/MainLayout/ContentSplit/NavRail/QuickStatusCard/QuickStatusLabel

@onready var _pages: Array[Control] = [
	$SafeMargin/MainLayout/ContentSplit/PageStage/PageHome,
	$SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal,
	$SafeMargin/MainLayout/ContentSplit/PageStage/PageArena,
	$SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings,
	$SafeMargin/MainLayout/ContentSplit/PageStage/PageProfile
]

@onready var _home_weapon_icon: TextureRect = $SafeMargin/MainLayout/ContentSplit/PageStage/PageHome/HomeCardsRow/WeaponBriefCard/VBox/HomeWeaponIcon
@onready var _home_weapon_title: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageHome/HomeCardsRow/WeaponBriefCard/VBox/HomeWeaponTitle
@onready var _home_weapon_stats: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageHome/HomeCardsRow/WeaponBriefCard/VBox/HomeWeaponStats
@onready var _mission_summary_label: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageHome/HomeCardsRow/MissionBriefCard/VBox/MissionSummaryLabel
@onready var _home_diff_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageHome/HomeCardsRow/MissionBriefCard/VBox/BtnHomeSwitchDiff

@onready var _btn_m4: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponCardsRow/BtnWeaponM4
@onready var _btn_uzi: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponCardsRow/BtnWeaponUzi
@onready var _btn_shotgun: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponCardsRow/BtnWeaponShotgun
@onready var _btn_sniper: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponCardsRow/BtnWeaponSniper
@onready var _arsenal_preview_icon: TextureRect = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponInspectorCard/HBox/PreviewIcon
@onready var _weapon_desc_label: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponInspectorCard/HBox/StatsVBox/WeaponDescLabel
@onready var _damage_bar: ProgressBar = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponInspectorCard/HBox/StatsVBox/DmgRow/DamageBar
@onready var _damage_val: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponInspectorCard/HBox/StatsVBox/DmgRow/DamageVal
@onready var _rate_bar: ProgressBar = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponInspectorCard/HBox/StatsVBox/RateRow/FireRateBar
@onready var _rate_val: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponInspectorCard/HBox/StatsVBox/RateRow/RateVal
@onready var _ammo_bar: ProgressBar = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponInspectorCard/HBox/StatsVBox/AmmoRow/AmmoBar
@onready var _ammo_val: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponInspectorCard/HBox/StatsVBox/AmmoRow/AmmoVal
@onready var _speed_bar: ProgressBar = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponInspectorCard/HBox/StatsVBox/VelRow/SpeedBar
@onready var _speed_val: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArsenal/WeaponInspectorCard/HBox/StatsVBox/VelRow/SpeedVal

@onready var _map_s01_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArena/MapRow/BtnMapSector01
@onready var _map_s02_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArena/MapRow/BtnMapSector02
@onready var _mode_zc_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArena/ModeRow/BtnModeZoneControl
@onready var _mode_tr_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArena/ModeRow/BtnModeTeamRush
@onready var _mode_zb_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArena/ModeRow/BtnModeZoneBlitz
@onready var _diff_easy_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArena/DiffRow/BtnDiffEasy
@onready var _diff_bal_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArena/DiffRow/BtnDiffBalanced
@onready var _diff_hard_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArena/DiffRow/BtnDiffHard
@onready var _arena_detail_label: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageArena/ArenaDetailCard/ArenaDetailLabel

@onready var _fps_30_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/FpsRow/BtnFps30
@onready var _fps_45_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/FpsRow/BtnFps45
@onready var _fps_60_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/FpsRow/BtnFps60
@onready var _qual_low_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/QualityRow/BtnQualLow
@onready var _qual_med_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/QualityRow/BtnQualMed
@onready var _qual_high_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/QualityRow/BtnQualHigh
@onready var _render_scale_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/RenderToggleRow/BtnRenderScale
@onready var _shadows_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/RenderToggleRow/BtnShadows
@onready var _show_fps_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/RenderToggleRow/BtnShowFps
@onready var _aim_mode_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/ControlsRow/BtnAimMode
@onready var _sensitivity_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/ControlsRow/BtnSensitivity
@onready var _cam_preset_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/ControlsRow/BtnCamPreset
@onready var _shake_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/FeelRow/BtnCameraShake
@onready var _haptics_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/FeelRow/BtnHaptics
@onready var _music_toggle_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/AudioRow/BtnMusicToggle
@onready var _sfx_toggle_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/AudioRow/BtnSfxToggle
@onready var _master_vol_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/AudioRow/BtnMasterVol
@onready var _music_vol_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/AudioMixRow/BtnMusicVol
@onready var _sfx_vol_btn: Button = $SafeMargin/MainLayout/ContentSplit/PageStage/PageSettings/SettingsVBox/AudioMixRow/BtnSfxVol

@onready var _profile_rank_label: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageProfile/RankProgressCard/VBox/ProfileRankLabel
@onready var _profile_xp_bar: ProgressBar = $SafeMargin/MainLayout/ContentSplit/PageStage/PageProfile/RankProgressCard/VBox/ProfileXpBar
@onready var _profile_detail_label: Label = $SafeMargin/MainLayout/ContentSplit/PageStage/PageProfile/ProfileStatsCard/ProfileDetailLabel

@onready var _status_label: Label = $SafeMargin/MainLayout/BottomLaunchDock/TicketCard/StatusLabel
@onready var _enter_arena_btn: Button = $SafeMargin/MainLayout/BottomLaunchDock/BtnEnterArena

var _active_tab: int = -1
var _stat_tween: Tween = null
var _tab_tween: Tween = null
var _cta_pulse_time: float = 0.0
var _weapon_cache: Dictionary = {}
var _icon_cache: Dictionary = {}


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	if _safe_margin != null:
		_safe_margin.layout_direction = Control.LAYOUT_DIRECTION_RTL
	GameManager.current_state = GameManager.AppState.MAIN_MENU
	AudioManager.play_menu_music()
	_preload_weapons()
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
		var pulse: float = 0.94 + 0.06 * sin(_cta_pulse_time * 3.0)
		_enter_arena_btn.modulate = Color(1.0, pulse, clampf(pulse - 0.03, 0.88, 1.0), 1.0)


func _preload_weapons() -> void:
	for wid in WEAPON_PATHS.keys():
		var path: String = WEAPON_PATHS[wid]
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path)
			if res is EnergyBlasterData:
				var wb := res as EnergyBlasterData
				_weapon_cache[wid] = wb
				if not wb.icon_path.is_empty() and ResourceLoader.exists(wb.icon_path):
					var tex: Resource = ResourceLoader.load(wb.icon_path)
					if tex is Texture2D:
						_icon_cache[wid] = tex


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
	_active_tab = clampi(tab_idx, 0, _pages.size() - 1)
	for i in _pages.size():
		if _pages[i] != null:
			_pages[i].visible = (i == _active_tab)
	for i in _tab_btns.size():
		if _tab_btns[i] != null:
			_tab_btns[i].button_pressed = (i == _active_tab)

	if animate and changed and is_inside_tree():
		var active_page: Control = _pages[_active_tab]
		if active_page != null:
			if _tab_tween != null and _tab_tween.is_valid():
				_tab_tween.kill()
			active_page.modulate = Color(1.0, 1.0, 1.0, 0.28)
			_tab_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tab_tween.tween_property(active_page, "modulate", Color.WHITE, 0.20)


func _refresh_ui() -> void:
	var rank: Dictionary = SaveManager.get_rank_info()
	var win_pct: int = int(round((float(SaveManager.total_wins) / float(SaveManager.total_matches)) * 100.0)) if SaveManager.total_matches > 0 else 0
	if _rank_num_label != null:
		_rank_num_label.text = str(int(rank["level"]))
	if _rank_title_header_label != null:
		_rank_title_header_label.text = "%s • %d XP" % [str(rank["title_fa"]), int(rank["xp"])]
	if _rank_xp_header_bar != null:
		_rank_xp_header_bar.value = float(rank["progress"]) * 100.0

	var music_txt: String = "موسیقی: روشن" if SaveManager.music_enabled else "موسیقی: خاموش"
	var sfx_txt: String = "افکت: روشن" if SaveManager.sfx_enabled else "افکت: خاموش"
	if _quick_music_btn != null:
		_quick_music_btn.button_pressed = SaveManager.music_enabled
		_quick_music_btn.text = music_txt
	if _quick_sfx_btn != null:
		_quick_sfx_btn.button_pressed = SaveManager.sfx_enabled
		_quick_sfx_btn.text = sfx_txt

	var wid: String = SaveManager.starting_blaster_id
	var weapon: EnergyBlasterData = _weapon_cache.get(wid, null) as EnergyBlasterData
	var w_tex: Texture2D = _icon_cache.get(wid, null) as Texture2D

	if _btn_m4 != null:
		_btn_m4.button_pressed = (wid == "pulse_blaster")
	if _btn_uzi != null:
		_btn_uzi.button_pressed = (wid == "rapid_repeater")
	if _btn_shotgun != null:
		_btn_shotgun.button_pressed = (wid == "plasma_scatter")
	if _btn_sniper != null:
		_btn_sniper.button_pressed = (wid == "arc_railgun")

	if weapon != null:
		var total_dmg: int = int(round(weapon.damage * float(weapon.pellets)))
		var rof: float = 1.0 / maxf(0.05, weapon.fire_interval)
		if _home_weapon_title != null:
			_home_weapon_title.text = weapon.display_name
		if _home_weapon_stats != null:
			_home_weapon_stats.text = "آسیب: %d  •  سرعت شلیک: %.1f/ث  •  خشاب: %d" % [total_dmg, rof, weapon.energy_cell_capacity]
		if _home_weapon_icon != null and w_tex != null:
			_home_weapon_icon.texture = w_tex
		if _arsenal_preview_icon != null and w_tex != null:
			_arsenal_preview_icon.texture = w_tex
		if _weapon_desc_label != null:
			_weapon_desc_label.text = _get_weapon_desc_fa(wid)
		_animate_weapon_bars(total_dmg, rof, weapon.energy_cell_capacity, weapon.projectile_speed)

	var is_s02: bool = (SaveManager.selected_map_id == "sector_02")
	var map_name: String = "پایگاه کویری براوو" if is_s02 else "پایگاه نظامی آلفا"
	if _map_s01_btn != null:
		_map_s01_btn.button_pressed = not is_s02
	if _map_s02_btn != null:
		_map_s02_btn.button_pressed = is_s02

	var mode_cfg: ArenaModeConfig = GameManager.get_active_mode_config()
	var mode_name: String = mode_cfg.display_name if mode_cfg != null else "کنترل منطقه"
	var mid: String = SaveManager.selected_mode_id
	if _mode_zc_btn != null:
		_mode_zc_btn.button_pressed = (mid == "zone_control")
	if _mode_tr_btn != null:
		_mode_tr_btn.button_pressed = (mid == "team_score_rush")
	if _mode_zb_btn != null:
		_mode_zb_btn.button_pressed = (mid == "zone_blitz")

	var diff_fa: String = "متعادل"
	match SaveManager.bot_difficulty:
		"easy":
			diff_fa = "آسان"
		"hard":
			diff_fa = "حرفه‌ای"
	if _diff_easy_btn != null:
		_diff_easy_btn.button_pressed = (SaveManager.bot_difficulty == "easy")
	if _diff_bal_btn != null:
		_diff_bal_btn.button_pressed = (SaveManager.bot_difficulty == "balanced")
	if _diff_hard_btn != null:
		_diff_hard_btn.button_pressed = (SaveManager.bot_difficulty == "hard")
	if _home_diff_btn != null:
		_home_diff_btn.text = "سختی حریف: %s" % diff_fa

	var mode_desc: String = mode_cfg.description_fa if mode_cfg != null else ""
	var map_desc: String = (
		"نبرد در پایگاه خشک کویری با جعبه‌های انبار گسترده و خطوط کمین میانی."
		if is_s02
		else "پایگاه بتنی استاندارد با موانع تاکتیکی متقارن و نبرد سریع در دو جناح."
	)
	if _mission_summary_label != null:
		_mission_summary_label.text = (
			"• نقشه فعال: %s\n"
			+ "• حالت بازی: %s (هدف %d امتیاز | %d ثانیه)\n"
			+ "• سطح هوش مصنوعی: %s\n"
			+ "• ترکیب تیم‌ها: شما + ۱ هم‌تیمی کماندو در برابر ۳ سرباز دشمن\n"
			+ "• تنظیم فعلی تصویر: %d FPS | کیفیت %s"
		) % [
			map_name,
			mode_name,
			mode_cfg.target_score if mode_cfg != null else 25,
			mode_cfg.round_duration_sec if mode_cfg != null else 120,
			diff_fa,
			SaveManager.target_fps,
			_get_quality_fa(SaveManager.quality_preset)
		]
	if _arena_detail_label != null:
		_arena_detail_label.text = "%s\n%s" % [map_desc, mode_desc]

	if _quick_status_label != null:
		_quick_status_label.text = (
			"سلاح:\n%s\n\nنقشه:\n%s\n\nحالت:\n%s\n\nهدف تصویر:\n%d FPS"
		) % [weapon.display_name if weapon != null else "کاربین M4", map_name, mode_name, SaveManager.target_fps]

	if _fps_30_btn != null:
		_fps_30_btn.button_pressed = (SaveManager.target_fps == 30)
	if _fps_45_btn != null:
		_fps_45_btn.button_pressed = (SaveManager.target_fps == 45)
	if _fps_60_btn != null:
		_fps_60_btn.button_pressed = (SaveManager.target_fps == 60)
	if _qual_low_btn != null:
		_qual_low_btn.button_pressed = (SaveManager.quality_preset == "low")
	if _qual_med_btn != null:
		_qual_med_btn.button_pressed = (SaveManager.quality_preset == "medium")
	if _qual_high_btn != null:
		_qual_high_btn.button_pressed = (SaveManager.quality_preset == "high")

	if _render_scale_btn != null:
		_render_scale_btn.text = "وضوح رندر: %d٪" % int(round(SaveManager.render_scale * 100.0))
	if _shadows_btn != null:
		_shadows_btn.button_pressed = SaveManager.shadows_enabled
		_shadows_btn.text = "سایه‌ها: روشن" if SaveManager.shadows_enabled else "سایه‌ها: خاموش"
	if _show_fps_btn != null:
		_show_fps_btn.button_pressed = SaveManager.show_fps
		_show_fps_btn.text = "نمایش FPS: روشن" if SaveManager.show_fps else "نمایش FPS: خاموش"

	if _aim_mode_btn != null:
		_aim_mode_btn.text = "نشانه: دکمه شلیک جدا" if SaveManager.aim_fire_mode == "fire_button" else "نشانه: دو جوی‌استیک"
	if _sensitivity_btn != null:
		var sens_txt: String = "معمولی"
		if SaveManager.joystick_sensitivity < 0.92:
			sens_txt = "دقیق (آرام)"
		elif SaveManager.joystick_sensitivity > 1.12:
			sens_txt = "تند (سریع)"
		_sensitivity_btn.text = "حساسیت: %s" % sens_txt
	if _cam_preset_btn != null:
		var cam_txt: String = "استاندارد"
		if SaveManager.camera_preset == "tactical":
			cam_txt = "گسترده"
		elif SaveManager.camera_preset == "close":
			cam_txt = "نزدیک اکشن"
		_cam_preset_btn.text = "نمای نبرد: %s" % cam_txt

	if _shake_btn != null:
		_shake_btn.button_pressed = SaveManager.camera_shake_enabled
		_shake_btn.text = "لرزش دوربین: روشن" if SaveManager.camera_shake_enabled else "لرزش دوربین: خاموش"
	if _haptics_btn != null:
		_haptics_btn.button_pressed = SaveManager.haptics_enabled
		_haptics_btn.text = "ویبره لمسی: روشن" if SaveManager.haptics_enabled else "ویبره لمسی: خاموش"

	if _music_toggle_btn != null:
		_music_toggle_btn.button_pressed = SaveManager.music_enabled
		_music_toggle_btn.text = music_txt
	if _sfx_toggle_btn != null:
		_sfx_toggle_btn.button_pressed = SaveManager.sfx_enabled
		_sfx_toggle_btn.text = sfx_txt
	if _master_vol_btn != null:
		_master_vol_btn.text = "بلندی کل: %d٪" % int(round(SaveManager.master_volume * 100.0))
	if _music_vol_btn != null:
		_music_vol_btn.text = "صدای موسیقی: %d٪" % int(round(SaveManager.music_volume * 100.0))
	if _sfx_vol_btn != null:
		_sfx_vol_btn.text = "صدای شلیک: %d٪" % int(round(SaveManager.sfx_volume * 100.0))

	if _profile_rank_label != null:
		_profile_rank_label.text = "درجه %d: %s  (%d / %d XP)" % [
			int(rank["level"]),
			str(rank["title_fa"]),
			int(rank["xp"]),
			int(rank["next_xp"])
		]
	if _profile_xp_bar != null:
		_profile_xp_bar.value = float(rank["progress"]) * 100.0
	if _profile_detail_label != null:
		_profile_detail_label.text = (
			"• کل نبردهای انجام‌شده: %d نبرد\n"
			+ "• تعداد پیروزی‌ها: %d پیروزی (%d٪ نرخ برد)\n"
			+ "• مجموع حذف نیروهای دشمن: %d حذف\n"
			+ "• بهترین رکورد حذف در یک نبرد: %d حذف\n\n"
			+ "تمام اطلاعات و کارنامه شما به صورت کاملاً آفلاین روی حافظه دستگاه ذخیره می‌شود."
		) % [
			SaveManager.total_matches,
			SaveManager.total_wins,
			win_pct,
			SaveManager.total_eliminations,
			SaveManager.best_match_eliminations
		]

	if _status_label != null:
		_status_label.text = "%s  •  %s  •  %s  •  %d FPS" % [
			weapon.display_name if weapon != null else "کاربین M4",
			map_name,
			mode_name,
			SaveManager.target_fps
		]


func _animate_weapon_bars(dmg: int, rof: float, ammo: int, vel: float) -> void:
	if _damage_val != null:
		_damage_val.text = str(dmg)
	if _rate_val != null:
		_rate_val.text = "%.1f/ث" % rof
	if _ammo_val != null:
		_ammo_val.text = str(ammo)
	if _speed_val != null:
		_speed_val.text = "%d" % int(round(vel))

	var t_dmg: float = clampf(float(dmg) / 60.0 * 100.0, 8.0, 100.0)
	var t_rof: float = clampf(rof / 11.5 * 100.0, 8.0, 100.0)
	var t_ammo: float = clampf(float(ammo) / 36.0 * 100.0, 8.0, 100.0)
	var t_vel: float = clampf(vel / 48.0 * 100.0, 8.0, 100.0)

	if not is_inside_tree():
		return
	if _stat_tween != null and _stat_tween.is_valid():
		_stat_tween.kill()
	_stat_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _damage_bar != null:
		_stat_tween.tween_property(_damage_bar, "value", t_dmg, 0.22)
	if _rate_bar != null:
		_stat_tween.tween_property(_rate_bar, "value", t_rof, 0.22)
	if _ammo_bar != null:
		_stat_tween.tween_property(_ammo_bar, "value", t_ammo, 0.22)
	if _speed_bar != null:
		_stat_tween.tween_property(_speed_bar, "value", t_vel, 0.22)


func _get_weapon_desc_fa(wid: String) -> String:
	match wid:
		"rapid_repeater":
			return "مسلسل سبک یوزی صداخفه‌کن با نواخت شلیک فوق‌سریع و خشاب ۳۶ تیری؛ مناسب هجوم سریع و درگیری نزدیک."
		"plasma_scatter":
			return "شاتگان نظامی M870 با شلیک ۵ ساچمه هم‌زمان و قدرت ضربه ویرانگر در فواصل کوتاه پشت سنگرها."
		"arc_railgun":
			return "تفنگ تک‌تیرانداز سنگین AWP با گلوله پرسرعت، دقت بالا و آسیب کشنده برای شکار اهداف دوربرد."
		_:
			return "کاربین تهاجمی استاندارد M4 با تعادل عالی میان دقت، سرعت گلوله و قدرت آتش در تمام فواصل نبرد."


func _get_quality_fa(preset: String) -> String:
	match preset:
		"low":
			return "پایین"
		"high":
			return "بالا"
		_:
			return "متوسط"


func _on_tab_pressed(tab_idx: int) -> void:
	AudioManager.play_ui_menu()
	_show_tab(tab_idx, true)


func _on_select_weapon(wid: String) -> void:
	AudioManager.play_ui_click()
	GameManager.set_starting_blaster(wid)
	_refresh_ui()


func _on_select_map(map_id: String) -> void:
	AudioManager.play_ui_click()
	GameManager.set_selected_map(map_id)
	_refresh_ui()


func _on_select_mode(mode_id: String) -> void:
	AudioManager.play_ui_click()
	GameManager.set_selected_mode(mode_id)
	_refresh_ui()


func _on_select_diff(diff_id: String) -> void:
	AudioManager.play_ui_click()
	GameManager.set_bot_difficulty(diff_id)
	_refresh_ui()


func _on_quick_switch_map() -> void:
	AudioManager.play_ui_click()
	var next_map: String = "sector_02" if SaveManager.selected_map_id == "sector_01" else "sector_01"
	GameManager.set_selected_map(next_map)
	_refresh_ui()


func _on_quick_switch_mode() -> void:
	AudioManager.play_ui_click()
	var idx: int = MODE_ORDER.find(SaveManager.selected_mode_id)
	GameManager.set_selected_mode(MODE_ORDER[(idx + 1) % MODE_ORDER.size()])
	_refresh_ui()


func _on_quick_switch_diff() -> void:
	AudioManager.play_ui_click()
	var idx: int = DIFF_ORDER.find(SaveManager.bot_difficulty)
	GameManager.set_bot_difficulty(DIFF_ORDER[(idx + 1) % DIFF_ORDER.size()])
	_refresh_ui()


func _on_fps_pressed(fps_val: int) -> void:
	AudioManager.play_ui_click()
	GameManager.set_target_fps(fps_val)
	_refresh_ui()


func _on_quality_pressed(preset_name: String) -> void:
	AudioManager.play_ui_click()
	GameManager.set_quality_preset(preset_name)
	_refresh_ui()


func _on_render_scale_pressed() -> void:
	AudioManager.play_ui_click()
	var next_scale: float = 0.85
	if SaveManager.render_scale < 0.78:
		next_scale = 0.85
	elif SaveManager.render_scale < 0.94:
		next_scale = 1.0
	else:
		next_scale = 0.72
	GameManager.set_render_scale(next_scale)
	_refresh_ui()


func _on_shadows_pressed() -> void:
	AudioManager.play_ui_click()
	GameManager.set_shadows_enabled(not SaveManager.shadows_enabled)
	_refresh_ui()


func _on_show_fps_pressed() -> void:
	AudioManager.play_ui_click()
	GameManager.set_show_fps(not SaveManager.show_fps)
	_refresh_ui()


func _on_aim_mode_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_mode: String = "fire_button" if SaveManager.aim_fire_mode == "twin_stick" else "twin_stick"
	GameManager.set_aim_fire_mode(next_mode)
	_refresh_ui()


func _on_sensitivity_pressed() -> void:
	AudioManager.play_ui_click()
	var next_sens: float = 1.0
	if SaveManager.joystick_sensitivity < 0.92:
		next_sens = 1.0
	elif SaveManager.joystick_sensitivity < 1.12:
		next_sens = 1.25
	else:
		next_sens = 0.85
	GameManager.set_joystick_sensitivity(next_sens)
	_refresh_ui()


func _on_cam_preset_pressed() -> void:
	AudioManager.play_ui_click()
	var presets: Array[String] = ["classic", "tactical", "close"]
	var idx: int = presets.find(SaveManager.camera_preset)
	GameManager.set_camera_preset(presets[(idx + 1) % presets.size()])
	_refresh_ui()


func _on_shake_pressed() -> void:
	AudioManager.play_ui_click()
	GameManager.set_camera_shake_enabled(not SaveManager.camera_shake_enabled)
	_refresh_ui()


func _on_haptics_pressed() -> void:
	AudioManager.play_ui_click()
	GameManager.set_haptics_enabled(not SaveManager.haptics_enabled)
	if SaveManager.haptics_enabled:
		GameManager.trigger_haptic(25)
	_refresh_ui()


func _on_btn_music_pressed() -> void:
	AudioManager.set_music_enabled(not SaveManager.music_enabled)
	AudioManager.play_ui_click()
	_refresh_ui()


func _on_btn_sfx_pressed() -> void:
	var next_sfx: bool = not SaveManager.sfx_enabled
	AudioManager.set_sfx_enabled(next_sfx)
	if next_sfx:
		AudioManager.play_ui_pop()
	_refresh_ui()


func _on_master_vol_pressed() -> void:
	var next_vol: float = 1.0
	if SaveManager.master_volume >= 0.95:
		next_vol = 0.35
	elif SaveManager.master_volume < 0.50:
		next_vol = 0.65
	elif SaveManager.master_volume < 0.78:
		next_vol = 0.85
	else:
		next_vol = 1.0
	AudioManager.set_master_volume(next_vol)
	AudioManager.play_ui_click()
	_refresh_ui()


func _on_music_vol_pressed() -> void:
	var next_vol: float = 0.75
	if SaveManager.music_volume >= 0.92:
		next_vol = 0.25
	elif SaveManager.music_volume < 0.45:
		next_vol = 0.50
	elif SaveManager.music_volume < 0.68:
		next_vol = 0.75
	else:
		next_vol = 1.0
	AudioManager.set_music_volume(next_vol)
	AudioManager.play_ui_click()
	_refresh_ui()


func _on_sfx_vol_pressed() -> void:
	var next_vol: float = 0.90
	if SaveManager.sfx_volume >= 0.95:
		next_vol = 0.40
	elif SaveManager.sfx_volume < 0.58:
		next_vol = 0.70
	elif SaveManager.sfx_volume < 0.85:
		next_vol = 0.90
	else:
		next_vol = 1.0
	AudioManager.set_sfx_volume(next_vol)
	AudioManager.play_ui_click()
	_refresh_ui()


func _on_reset_settings_pressed() -> void:
	GameManager.reset_settings_to_defaults()
	AudioManager.play_ui_pop()
	_refresh_ui()


func _on_enter_arena_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_selected_arena()
