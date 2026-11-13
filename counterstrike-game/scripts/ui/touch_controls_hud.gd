extends CanvasLayer
## رابط کاربری چندلمسی میدان نبرد (جان/انرژی، اعداد آسیب شناور، رادار تاکتیکی، دکمه بمب و جهش، جهت‌نمای آسیب).

@onready var _damage_flash: ColorRect = $DamageFlashRect
@onready var _hit_dir_indicator: HitDirectionIndicator = $HitDirectionIndicator
@onready var _damage_numbers: DamageNumbersOverlay = $DamageNumbersOverlay
@onready var _hitmarker_label: Label = $HitmarkerLabel
@onready var _top_safe_margin: MarginContainer = $TopSafeMargin
@onready var _bottom_safe_margin: MarginContainer = $BottomSafeMargin
@onready var _left_move_stick: VirtualJoystick = $BottomSafeMargin/TouchControlsRow/LeftMoveStick
@onready var _right_aim_stick: VirtualJoystick = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/RightAimStick
@onready var _dedicated_fire_pad: TouchFirePad = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/FirePadAnchor/DedicatedFirePad
@onready var _btn_bomb: TouchActionButton = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow/BtnBomb
@onready var _btn_dash: TouchActionButton = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow/BtnDash
@onready var _btn_switch_blaster: TouchActionButton = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow/BtnSwitchBlaster
@onready var _btn_recharge: TouchActionButton = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow/BtnRecharge

@onready var _score_label: Label = $TopSafeMargin/TopHudBar/ScoreBadge/ScoreLabel
@onready var _zone_mini_a: PanelContainer = $TopSafeMargin/TopHudBar/ZoneMiniA
@onready var _zone_mini_a_label: Label = $TopSafeMargin/TopHudBar/ZoneMiniA/Label
@onready var _zone_mini_b: PanelContainer = $TopSafeMargin/TopHudBar/ZoneMiniB
@onready var _zone_mini_b_label: Label = $TopSafeMargin/TopHudBar/ZoneMiniB/Label
@onready var _timer_label: Label = $TopSafeMargin/TopHudBar/TimerBadge/TimerLabel
@onready var _stats_label: Label = $TopSafeMargin/TopHudBar/StatsBadge/StatsVBox/StatsLabel
@onready var _hp_bar: ProgressBar = $TopSafeMargin/TopHudBar/StatsBadge/StatsVBox/BarsRow/HpBar
@onready var _energy_bar: ProgressBar = $TopSafeMargin/TopHudBar/StatsBadge/StatsVBox/BarsRow/EnergyBar
@onready var _buff_badge: PanelContainer = $TopSafeMargin/TopHudBar/BuffBadge
@onready var _buff_label: Label = $TopSafeMargin/TopHudBar/BuffBadge/BuffLabel

@onready var _kill_feed_panel: PanelContainer = $KillFeedPanel
@onready var _kill_feed_box: VBoxContainer = $KillFeedPanel/KillFeedBox
@onready var _toast_panel: PanelContainer = $CenterToastPanel
@onready var _toast_label: Label = $CenterToastPanel/ToastLabel
@onready var _pause_overlay: Control = $PauseOverlay
@onready var _pause_aim_btn: Button = $PauseOverlay/PauseCard/PauseMargin/PauseVBox/BtnPauseAimMode
@onready var _pause_music_btn: Button = $PauseOverlay/PauseCard/PauseMargin/PauseVBox/PauseAudioRow/BtnPauseMusic
@onready var _pause_sfx_btn: Button = $PauseOverlay/PauseCard/PauseMargin/PauseVBox/PauseAudioRow/BtnPauseSfx
@onready var _match_end_overlay: Control = $MatchEndOverlay
@onready var _end_title_label: Label = $MatchEndOverlay/EndCard/EndMargin/EndVBox/EndTitleLabel
@onready var _end_detail_label: Label = $MatchEndOverlay/EndCard/EndMargin/EndVBox/EndDetailLabel

var _toast_timer: float = 0.0
var _hitmarker_timer: float = 0.0
var _kill_feed_expire_timer: float = 0.0
var _respawn_active: bool = false
var _match_ended: bool = false
var _damage_alpha: float = 0.0
var _low_hp_warning: bool = false
var _low_hp_pulse_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _top_safe_margin != null:
		_top_safe_margin.layout_direction = Control.LAYOUT_DIRECTION_RTL
	if _bottom_safe_margin != null:
		_bottom_safe_margin.layout_direction = Control.LAYOUT_DIRECTION_LTR
	if _kill_feed_panel != null:
		_kill_feed_panel.layout_direction = Control.LAYOUT_DIRECTION_RTL
		_kill_feed_panel.visible = false
	if _pause_overlay != null:
		_pause_overlay.layout_direction = Control.LAYOUT_DIRECTION_RTL
		_pause_overlay.visible = false
	if _match_end_overlay != null:
		_match_end_overlay.layout_direction = Control.LAYOUT_DIRECTION_RTL
		_match_end_overlay.visible = false
	if _toast_panel != null:
		_toast_panel.visible = false
	if _hitmarker_label != null:
		_hitmarker_label.visible = false

	_setup_excluded_controls()
	_apply_safe_area_margins()
	_apply_aim_fire_mode()
	_refresh_pause_audio_buttons()
	_init_zone_mini_badges()
	_update_score_badge(0, 0)
	_update_timer_badge(120)

	get_viewport().size_changed.connect(_apply_safe_area_margins)
	EventBus.aim_fire_mode_changed.connect(_on_aim_fire_mode_changed)
	EventBus.player_stats_updated.connect(_on_player_stats_updated)
	EventBus.player_buff_updated.connect(_on_player_buff_updated)
	EventBus.player_dash_updated.connect(_on_player_dash_updated)
	EventBus.player_bomb_updated.connect(_on_player_bomb_updated)
	EventBus.enemy_hit_confirmed.connect(_on_enemy_hit_confirmed)
	EventBus.combat_callout_requested.connect(_on_combat_callout_requested)
	EventBus.kill_feed_event.connect(_on_kill_feed_event)
	EventBus.player_damaged_feedback.connect(_on_player_damaged_feedback)
	EventBus.player_damaged_direction.connect(_on_player_damaged_direction)
	EventBus.player_respawn_countdown.connect(_on_player_respawn_countdown)
	EventBus.zone_capture_progress.connect(_on_zone_capture_progress)
	EventBus.zone_captured.connect(_on_zone_captured)
	EventBus.score_updated.connect(_on_score_updated)
	EventBus.match_timer_updated.connect(_update_timer_badge)
	EventBus.hud_toast_requested.connect(_show_toast)
	EventBus.match_paused_changed.connect(_on_match_paused_changed)
	EventBus.match_ended.connect(_on_match_ended)

	if _btn_bomb != null:
		_btn_bomb.action_triggered.connect(_on_bomb_triggered)
	if _btn_dash != null:
		_btn_dash.action_triggered.connect(_on_dash_triggered)
	if _btn_switch_blaster != null:
		_btn_switch_blaster.action_triggered.connect(_on_switch_blaster_triggered)
	if _btn_recharge != null:
		_btn_recharge.action_triggered.connect(_on_recharge_triggered)


func _exit_tree() -> void:
	if get_viewport() != null and get_viewport().size_changed.is_connected(_apply_safe_area_margins):
		get_viewport().size_changed.disconnect(_apply_safe_area_margins)
	if EventBus.aim_fire_mode_changed.is_connected(_on_aim_fire_mode_changed):
		EventBus.aim_fire_mode_changed.disconnect(_on_aim_fire_mode_changed)
	if EventBus.player_stats_updated.is_connected(_on_player_stats_updated):
		EventBus.player_stats_updated.disconnect(_on_player_stats_updated)
	if EventBus.player_buff_updated.is_connected(_on_player_buff_updated):
		EventBus.player_buff_updated.disconnect(_on_player_buff_updated)
	if EventBus.player_dash_updated.is_connected(_on_player_dash_updated):
		EventBus.player_dash_updated.disconnect(_on_player_dash_updated)
	if EventBus.player_bomb_updated.is_connected(_on_player_bomb_updated):
		EventBus.player_bomb_updated.disconnect(_on_player_bomb_updated)
	if EventBus.enemy_hit_confirmed.is_connected(_on_enemy_hit_confirmed):
		EventBus.enemy_hit_confirmed.disconnect(_on_enemy_hit_confirmed)
	if EventBus.combat_callout_requested.is_connected(_on_combat_callout_requested):
		EventBus.combat_callout_requested.disconnect(_on_combat_callout_requested)
	if EventBus.kill_feed_event.is_connected(_on_kill_feed_event):
		EventBus.kill_feed_event.disconnect(_on_kill_feed_event)
	if EventBus.player_damaged_feedback.is_connected(_on_player_damaged_feedback):
		EventBus.player_damaged_feedback.disconnect(_on_player_damaged_feedback)
	if EventBus.player_damaged_direction.is_connected(_on_player_damaged_direction):
		EventBus.player_damaged_direction.disconnect(_on_player_damaged_direction)
	if EventBus.player_respawn_countdown.is_connected(_on_player_respawn_countdown):
		EventBus.player_respawn_countdown.disconnect(_on_player_respawn_countdown)
	if EventBus.zone_capture_progress.is_connected(_on_zone_capture_progress):
		EventBus.zone_capture_progress.disconnect(_on_zone_capture_progress)
	if EventBus.zone_captured.is_connected(_on_zone_captured):
		EventBus.zone_captured.disconnect(_on_zone_captured)
	if EventBus.score_updated.is_connected(_on_score_updated):
		EventBus.score_updated.disconnect(_on_score_updated)
	if EventBus.match_timer_updated.is_connected(_update_timer_badge):
		EventBus.match_timer_updated.disconnect(_update_timer_badge)
	if EventBus.hud_toast_requested.is_connected(_show_toast):
		EventBus.hud_toast_requested.disconnect(_show_toast)
	if EventBus.match_paused_changed.is_connected(_on_match_paused_changed):
		EventBus.match_paused_changed.disconnect(_on_match_paused_changed)
	if EventBus.match_ended.is_connected(_on_match_ended):
		EventBus.match_ended.disconnect(_on_match_ended)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _match_ended:
		_toggle_pause()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE and not _match_ended:
			_toggle_pause()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _damage_alpha > 0.0:
		_damage_alpha = maxf(0.0, _damage_alpha - delta * 1.15)
	var min_warn_alpha: float = 0.0
	if _low_hp_warning and not _match_ended and not _respawn_active:
		_low_hp_pulse_time += delta * 5.0
		min_warn_alpha = 0.04 + 0.06 * (0.5 + 0.5 * sin(_low_hp_pulse_time))
	if _damage_flash != null:
		_damage_flash.color = Color(0.937255, 0.266667, 0.266667, maxf(_damage_alpha, min_warn_alpha))

	if _hitmarker_timer > 0.0 and _hitmarker_label != null:
		_hitmarker_timer -= delta
		if _hitmarker_timer <= 0.0:
			_hitmarker_label.visible = false

	if _kill_feed_expire_timer > 0.0 and _kill_feed_panel != null:
		_kill_feed_expire_timer -= delta
		if _kill_feed_expire_timer <= 0.0:
			_kill_feed_panel.visible = false

	if not _respawn_active and _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_panel != null:
			_toast_panel.visible = false


func _setup_excluded_controls() -> void:
	if _right_aim_stick == null:
		return
	var excl: Array[Control] = []
	if _dedicated_fire_pad != null:
		excl.append(_dedicated_fire_pad)
	if _btn_bomb != null:
		excl.append(_btn_bomb)
	if _btn_dash != null:
		excl.append(_btn_dash)
	if _btn_switch_blaster != null:
		excl.append(_btn_switch_blaster)
	if _btn_recharge != null:
		excl.append(_btn_recharge)
	_right_aim_stick.excluded_controls = excl


func _apply_safe_area_margins() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var pad: Dictionary = GameManager.get_safe_area_padding(vp_size)

	if _top_safe_margin != null:
		_top_safe_margin.add_theme_constant_override("margin_left", int(pad["left"]))
		_top_safe_margin.add_theme_constant_override("margin_right", int(pad["right"]))
		_top_safe_margin.add_theme_constant_override("margin_top", int(pad["top"]))
		_top_safe_margin.add_theme_constant_override("margin_bottom", 8)

	if _bottom_safe_margin != null:
		_bottom_safe_margin.add_theme_constant_override("margin_left", int(pad["left"]))
		_bottom_safe_margin.add_theme_constant_override("margin_right", int(pad["right"]))
		_bottom_safe_margin.add_theme_constant_override("margin_top", 8)
		_bottom_safe_margin.add_theme_constant_override("margin_bottom", int(pad["bottom"]))


func _apply_aim_fire_mode() -> void:
	var is_fire_button_mode: bool = (SaveManager.aim_fire_mode == "fire_button")
	if _right_aim_stick != null:
		_right_aim_stick.enable_fire_threshold = not is_fire_button_mode
		_right_aim_stick.stick_title = "نشانه" if is_fire_button_mode else "نشانه و شلیک"
		_right_aim_stick.queue_redraw()
	if _dedicated_fire_pad != null:
		_dedicated_fire_pad.visible = is_fire_button_mode
		if not is_fire_button_mode:
			_dedicated_fire_pad.release_pad()
	var mode_str: String = "حالت: دکمه شلیک" if is_fire_button_mode else "حالت: دو جوی‌استیک"
	if _pause_aim_btn != null:
		_pause_aim_btn.text = mode_str


func _reset_touch_controls() -> void:
	if _left_move_stick != null:
		_left_move_stick.reset_stick()
	if _right_aim_stick != null:
		_right_aim_stick.reset_stick()
	if _dedicated_fire_pad != null:
		_dedicated_fire_pad.release_pad()


func _toggle_pause() -> void:
	var next_paused: bool = not get_tree().paused
	GameManager.set_match_paused(next_paused)


func _on_match_paused_changed(is_paused: bool) -> void:
	if _match_ended:
		return
	if is_paused:
		_reset_touch_controls()
		_refresh_pause_audio_buttons()
	if _pause_overlay != null:
		_pause_overlay.visible = is_paused
	if _bottom_safe_margin != null:
		_bottom_safe_margin.visible = not is_paused


func _on_match_ended(winning_team: int, blue_score: int, orange_score: int, player_eliminations: int) -> void:
	_match_ended = true
	_respawn_active = false
	_low_hp_warning = false
	_reset_touch_controls()
	if _pause_overlay != null:
		_pause_overlay.visible = false
	if _toast_panel != null:
		_toast_panel.visible = false
	if _kill_feed_panel != null:
		_kill_feed_panel.visible = false
	if _bottom_safe_margin != null:
		_bottom_safe_margin.visible = false

	if _end_title_label != null:
		if winning_team == 0:
			_end_title_label.text = "پیروزی تیم آبی!"
			_end_title_label.add_theme_color_override("font_color", Color(0.219608, 0.741176, 0.972549, 1.0))
		elif winning_team == 1:
			_end_title_label.text = "پایان نبرد — تیم نارنجی پیروز شد"
			_end_title_label.add_theme_color_override("font_color", Color(0.984314, 0.45098, 0.086275, 1.0))
		else:
			_end_title_label.text = "نتیجه مساوی!"
			_end_title_label.add_theme_color_override("font_color", Color(0.984314, 0.74902, 0.141176, 1.0))

	var xp_gained: int = 50 + (75 if winning_team == 0 else 0) + maxi(0, player_eliminations) * 15
	var ctrl: Node = get_parent()
	if ctrl != null and ctrl.has_method("get_last_xp_gained"):
		xp_gained = int(ctrl.call("get_last_xp_gained"))
	var rank: Dictionary = SaveManager.get_rank_info()

	if _end_detail_label != null:
		_end_detail_label.text = (
			"امتیاز نهایی: آبی %d  —  %d نارنجی  |  حذف تیم آبی: %d\n"
			+ "تجربه کسب‌شده: +%d XP  •  رتبه %d (%s)\n"
			+ "کارنامه کل: %d پیروزی از %d نبرد"
		) % [
			blue_score,
			orange_score,
			player_eliminations,
			xp_gained,
			int(rank["level"]),
			str(rank["title_fa"]),
			SaveManager.total_wins,
			SaveManager.total_matches
		]

	if _match_end_overlay != null:
		_match_end_overlay.visible = true


func _on_aim_fire_mode_changed(_mode_name: String) -> void:
	_apply_aim_fire_mode()


func _on_player_stats_updated(hp: int, max_hp: int, energy: int, max_energy: int, blaster_name_fa: String, recharging: bool) -> void:
	_low_hp_warning = (hp > 0 and hp <= 30)
	if _stats_label != null:
		var energy_str: String = "در حال شارژ..." if recharging else "%d/%d" % [energy, max_energy]
		_stats_label.text = "جان: %d/%d | %s: %s" % [hp, max_hp, blaster_name_fa, energy_str]
		if _low_hp_warning:
			_stats_label.add_theme_color_override("font_color", Color(0.984314, 0.45098, 0.086275, 1.0))
		else:
			_stats_label.add_theme_color_override("font_color", Color(0.901961, 0.960784, 1.0, 1.0))
	if _hp_bar != null:
		_hp_bar.max_value = maxf(1.0, float(max_hp))
		_hp_bar.value = clampf(float(hp), 0.0, float(max_hp))
	if _energy_bar != null:
		_energy_bar.max_value = maxf(1.0, float(max_energy))
		_energy_bar.value = 0.0 if recharging else clampf(float(energy), 0.0, float(max_energy))

	if _btn_switch_blaster != null:
		if "رگبار" in blaster_name_fa:
			_btn_switch_blaster.title_text = "رگبار"
			_btn_switch_blaster.accent_color = Color(0.984314, 0.572549, 0.235294, 1.0)
		elif "پلاسما" in blaster_name_fa:
			_btn_switch_blaster.title_text = "پلاسما"
			_btn_switch_blaster.accent_color = Color(0.658824, 0.333333, 0.968627, 1.0)
		elif "ریل" in blaster_name_fa:
			_btn_switch_blaster.title_text = "ریل‌گان"
			_btn_switch_blaster.accent_color = Color(0.984314, 0.74902, 0.141176, 1.0)
		else:
			_btn_switch_blaster.title_text = "پالس"
			_btn_switch_blaster.accent_color = Color(0.219608, 0.741176, 0.972549, 1.0)
		_btn_switch_blaster.queue_redraw()


func _on_player_dash_updated(cooldown_left: float, cooldown_total: float, ready: bool) -> void:
	if _btn_dash == null:
		return
	if ready or cooldown_left <= 0.05:
		_btn_dash.set_cooldown_state(0.0, "جهش")
	else:
		var ratio: float = clampf(cooldown_left / maxf(cooldown_total, 0.1), 0.0, 1.0)
		_btn_dash.set_cooldown_state(ratio, "%.1fث" % cooldown_left)


func _on_player_bomb_updated(cooldown_left: float, cooldown_total: float, ready: bool) -> void:
	if _btn_bomb == null:
		return
	if ready or cooldown_left <= 0.05:
		_btn_bomb.set_cooldown_state(0.0, "بمب")
	else:
		var ratio: float = clampf(cooldown_left / maxf(cooldown_total, 0.1), 0.0, 1.0)
		_btn_bomb.set_cooldown_state(ratio, "%.1fث" % cooldown_left)


func _on_enemy_hit_confirmed(_damage: float, is_kill: bool) -> void:
	if _hitmarker_label == null:
		return
	_hitmarker_label.visible = true
	_hitmarker_timer = 0.20 if is_kill else 0.11
	_hitmarker_label.add_theme_color_override(
		"font_color",
		Color(0.937255, 0.266667, 0.266667, 1.0) if is_kill else Color(0.984314, 0.74902, 0.141176, 1.0)
	)


func _on_combat_callout_requested(world_pos: Vector3, text_fa: String, color: Color, scale_boost: float) -> void:
	if _damage_numbers != null:
		_damage_numbers.spawn_callout(world_pos, text_fa, color, scale_boost)


func _on_kill_feed_event(killer_fa: String, victim_fa: String, killer_team: int) -> void:
	if _kill_feed_panel == null or _kill_feed_box == null:
		return
	var row := Label.new()
	row.text = "%s ← %s" % [killer_fa, victim_fa]
	row.add_theme_font_size_override("font_size", 12)
	row.add_theme_color_override(
		"font_color",
		Color(0.219608, 0.741176, 0.972549, 1.0) if killer_team == 0 else Color(0.984314, 0.45098, 0.086275, 1.0)
	)
	_kill_feed_box.add_child(row)
	while _kill_feed_box.get_child_count() > 3:
		var old: Node = _kill_feed_box.get_child(0)
		_kill_feed_box.remove_child(old)
		old.queue_free()
	_kill_feed_panel.visible = true
	_kill_feed_expire_timer = 4.5


func _init_zone_mini_badges() -> void:
	var active_mode: ArenaModeConfig = GameManager.get_active_mode_config()
	var show_zones: bool = active_mode == null or active_mode.enable_capture_zones
	if _zone_mini_a != null:
		_zone_mini_a.visible = show_zones
		_set_zone_mini_color(_zone_mini_a, _zone_mini_a_label, Color(0.580392, 0.639216, 0.721569, 1.0))
	if _zone_mini_b != null:
		_zone_mini_b.visible = show_zones
		_set_zone_mini_color(_zone_mini_b, _zone_mini_b_label, Color(0.580392, 0.639216, 0.721569, 1.0))


func _set_zone_mini_color(panel: PanelContainer, label: Label, col: Color) -> void:
	if panel != null:
		panel.self_modulate = Color(col.r * 0.45 + 0.55, col.g * 0.45 + 0.55, col.b * 0.45 + 0.55, 1.0)
	if label != null:
		label.add_theme_color_override("font_color", col)


func _on_zone_capture_progress(zone_id: String, team_id: int, progress: float) -> void:
	var target_panel: PanelContainer = _zone_mini_a if zone_id == "zone_a" else _zone_mini_b
	var target_label: Label = _zone_mini_a_label if zone_id == "zone_a" else _zone_mini_b_label
	var neutral_col := Color(0.580392, 0.639216, 0.721569, 1.0)
	var team_col := Color(0.219608, 0.741176, 0.972549, 1.0) if team_id == 0 else Color(0.984314, 0.45098, 0.086275, 1.0)
	_set_zone_mini_color(target_panel, target_label, neutral_col.lerp(team_col, clampf(progress, 0.0, 1.0)))


func _on_zone_captured(zone_id: String, team_id: int) -> void:
	var target_panel: PanelContainer = _zone_mini_a if zone_id == "zone_a" else _zone_mini_b
	var target_label: Label = _zone_mini_a_label if zone_id == "zone_a" else _zone_mini_b_label
	var team_col := Color(0.219608, 0.741176, 0.972549, 1.0) if team_id == 0 else Color(0.984314, 0.45098, 0.086275, 1.0)
	_set_zone_mini_color(target_panel, target_label, team_col)


func _on_player_buff_updated(damage_secs: float, speed_secs: float) -> void:
	if _buff_badge == null or _buff_label == null:
		return
	var parts: Array[String] = []
	if damage_secs > 0.1:
		parts.append("تقویت %dث" % maxi(1, int(ceil(damage_secs))))
	if speed_secs > 0.1:
		parts.append("شتاب %dث" % maxi(1, int(ceil(speed_secs))))
	if parts.is_empty():
		_buff_badge.visible = false
	else:
		_buff_badge.visible = true
		_buff_label.text = " | ".join(parts)
		if damage_secs > 0.1:
			_buff_label.add_theme_color_override("font_color", Color(0.984314, 0.74902, 0.141176, 1.0))
		else:
			_buff_label.add_theme_color_override("font_color", Color(0.752941, 0.517647, 0.988235, 1.0))


func _refresh_pause_audio_buttons() -> void:
	if _pause_music_btn != null:
		_pause_music_btn.text = "موسیقی: روشن" if SaveManager.music_enabled else "موسیقی: خاموش"
	if _pause_sfx_btn != null:
		_pause_sfx_btn.text = "افکت: روشن" if SaveManager.sfx_enabled else "افکت: خاموش"


func _on_btn_pause_music_pressed() -> void:
	var next_music: bool = not SaveManager.music_enabled
	AudioManager.set_music_enabled(next_music)
	AudioManager.play_ui_click()
	_refresh_pause_audio_buttons()


func _on_btn_pause_sfx_pressed() -> void:
	var next_sfx: bool = not SaveManager.sfx_enabled
	AudioManager.set_sfx_enabled(next_sfx)
	if next_sfx:
		AudioManager.play_ui_pop()
	_refresh_pause_audio_buttons()


func _on_player_damaged_feedback(_hp_ratio: float) -> void:
	_damage_alpha = 0.28


func _on_player_damaged_direction(angle_rad: float) -> void:
	if _hit_dir_indicator != null:
		_hit_dir_indicator.add_hit_direction(angle_rad)


func _on_player_respawn_countdown(seconds_left: float, active: bool) -> void:
	_respawn_active = active
	if _toast_panel == null or _toast_label == null:
		return
	if active:
		_toast_panel.visible = true
		_toast_label.add_theme_color_override("font_color", Color(0.984314, 0.572549, 0.235294, 1.0))
		_toast_label.text = "بازگشت به میدان تا %d ثانیه..." % maxi(1, int(ceil(seconds_left)))
	else:
		_toast_panel.visible = false


func _show_toast(message_fa: String, accent_color: Color) -> void:
	if _respawn_active or _toast_panel == null or _toast_label == null:
		return
	_toast_label.text = message_fa
	_toast_label.add_theme_color_override("font_color", accent_color)
	_toast_panel.visible = true
	_toast_timer = 2.2


func _on_score_updated(blue_score: int, orange_score: int) -> void:
	_update_score_badge(blue_score, orange_score)


func _update_score_badge(blue_score: int, orange_score: int) -> void:
	if _score_label != null:
		_score_label.text = "آبی %d — %d نارنجی" % [blue_score, orange_score]


func _update_timer_badge(seconds_remaining: int) -> void:
	if _timer_label == null:
		return
	var s: int = maxi(0, seconds_remaining)
	var mins: int = s / 60
	var secs: int = s % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]
	if s <= 15:
		_timer_label.add_theme_color_override("font_color", Color(0.984314, 0.45098, 0.086275, 1.0))
	else:
		_timer_label.add_theme_color_override("font_color", Color(0.972549, 0.980392, 0.988235, 1.0))


func get_move_vector() -> Vector2:
	return _left_move_stick.output_vector if _left_move_stick != null else Vector2.ZERO


func get_aim_vector() -> Vector2:
	return _right_aim_stick.output_vector if _right_aim_stick != null else Vector2.ZERO


func is_fire_active() -> bool:
	if SaveManager.aim_fire_mode == "fire_button":
		return _dedicated_fire_pad != null and _dedicated_fire_pad.is_pressed
	return _right_aim_stick != null and _right_aim_stick.is_fire_engaged


func _on_bomb_triggered() -> void:
	EventBus.player_bomb_requested.emit()


func _on_dash_triggered() -> void:
	EventBus.player_dash_requested.emit()


func _on_switch_blaster_triggered() -> void:
	EventBus.blaster_switch_requested.emit()


func _on_recharge_triggered() -> void:
	EventBus.blaster_recharge_requested.emit()


func _on_btn_pause_pressed() -> void:
	AudioManager.play_ui_menu()
	_toggle_pause()


func _on_btn_resume_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.set_match_paused(false)


func _on_btn_restart_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_selected_arena()


func _on_btn_back_menu_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_main_menu()


func _on_btn_aim_mode_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_mode: String = "fire_button" if SaveManager.aim_fire_mode == "twin_stick" else "twin_stick"
	GameManager.set_aim_fire_mode(next_mode)
