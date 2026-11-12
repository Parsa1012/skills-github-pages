extends CanvasLayer
## رابط کاربری چندلمسی میدان نبرد (جان/انرژی، تایمر، امتیاز، توقف بازی و نتیجه نهایی).

@onready var _damage_flash: ColorRect = $DamageFlashRect
@onready var _top_safe_margin: MarginContainer = $TopSafeMargin
@onready var _bottom_safe_margin: MarginContainer = $BottomSafeMargin
@onready var _left_move_stick: VirtualJoystick = $BottomSafeMargin/TouchControlsRow/LeftMoveStick
@onready var _right_aim_stick: VirtualJoystick = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/RightAimStick
@onready var _dedicated_fire_pad: TouchFirePad = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/FirePadAnchor/DedicatedFirePad
@onready var _btn_switch_blaster: TouchActionButton = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow/BtnSwitchBlaster
@onready var _btn_recharge: TouchActionButton = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow/BtnRecharge

@onready var _score_label: Label = $TopSafeMargin/TopHudBar/ScoreBadge/ScoreLabel
@onready var _timer_label: Label = $TopSafeMargin/TopHudBar/TimerBadge/TimerLabel
@onready var _stats_label: Label = $TopSafeMargin/TopHudBar/StatsBadge/StatsLabel
@onready var _zone_label: Label = $TopSafeMargin/TopHudBar/ZoneBadge/ZoneLabel
@onready var _perf_label: Label = $TopSafeMargin/TopHudBar/PerfBadge/PerfLabel
@onready var _aim_mode_btn: Button = $TopSafeMargin/TopHudBar/BtnAimMode

@onready var _toast_panel: PanelContainer = $CenterToastPanel
@onready var _toast_label: Label = $CenterToastPanel/ToastLabel
@onready var _pause_overlay: Control = $PauseOverlay
@onready var _pause_aim_btn: Button = $PauseOverlay/PauseCard/PauseMargin/PauseVBox/BtnPauseAimMode
@onready var _match_end_overlay: Control = $MatchEndOverlay
@onready var _end_title_label: Label = $MatchEndOverlay/EndCard/EndMargin/EndVBox/EndTitleLabel
@onready var _end_detail_label: Label = $MatchEndOverlay/EndCard/EndMargin/EndVBox/EndDetailLabel

var _active_zone_title: String = "میدان آزاد"
var _fps_sample_timer: float = 0.0
var _toast_timer: float = 0.0
var _respawn_active: bool = false
var _match_ended: bool = false
var _damage_alpha: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _top_safe_margin != null:
		_top_safe_margin.layout_direction = Control.LAYOUT_DIRECTION_RTL
	if _bottom_safe_margin != null:
		_bottom_safe_margin.layout_direction = Control.LAYOUT_DIRECTION_LTR
	if _pause_overlay != null:
		_pause_overlay.layout_direction = Control.LAYOUT_DIRECTION_RTL
		_pause_overlay.visible = false
	if _match_end_overlay != null:
		_match_end_overlay.layout_direction = Control.LAYOUT_DIRECTION_RTL
		_match_end_overlay.visible = false
	if _toast_panel != null:
		_toast_panel.visible = false

	_setup_excluded_controls()
	_apply_safe_area_margins()
	_apply_aim_fire_mode()
	_update_zone_badge("میدان آزاد")
	_update_score_badge(0, 0)
	_update_timer_badge(120)
	_update_perf_badge()

	get_viewport().size_changed.connect(_apply_safe_area_margins)
	EventBus.aim_fire_mode_changed.connect(_on_aim_fire_mode_changed)
	EventBus.player_zone_changed.connect(_on_player_zone_changed)
	EventBus.player_stats_updated.connect(_on_player_stats_updated)
	EventBus.player_damaged_feedback.connect(_on_player_damaged_feedback)
	EventBus.player_respawn_countdown.connect(_on_player_respawn_countdown)
	EventBus.score_updated.connect(_on_score_updated)
	EventBus.match_timer_updated.connect(_update_timer_badge)
	EventBus.hud_toast_requested.connect(_show_toast)
	EventBus.match_paused_changed.connect(_on_match_paused_changed)
	EventBus.match_ended.connect(_on_match_ended)

	if _btn_switch_blaster != null:
		_btn_switch_blaster.action_triggered.connect(_on_switch_blaster_triggered)
	if _btn_recharge != null:
		_btn_recharge.action_triggered.connect(_on_recharge_triggered)


func _exit_tree() -> void:
	if EventBus.aim_fire_mode_changed.is_connected(_on_aim_fire_mode_changed):
		EventBus.aim_fire_mode_changed.disconnect(_on_aim_fire_mode_changed)
	if EventBus.player_zone_changed.is_connected(_on_player_zone_changed):
		EventBus.player_zone_changed.disconnect(_on_player_zone_changed)
	if EventBus.player_stats_updated.is_connected(_on_player_stats_updated):
		EventBus.player_stats_updated.disconnect(_on_player_stats_updated)
	if EventBus.player_damaged_feedback.is_connected(_on_player_damaged_feedback):
		EventBus.player_damaged_feedback.disconnect(_on_player_damaged_feedback)
	if EventBus.player_respawn_countdown.is_connected(_on_player_respawn_countdown):
		EventBus.player_respawn_countdown.disconnect(_on_player_respawn_countdown)
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
	_fps_sample_timer += delta
	if _fps_sample_timer >= 0.45:
		_fps_sample_timer = 0.0
		_update_perf_badge()

	if _damage_alpha > 0.0 and _damage_flash != null:
		_damage_alpha = maxf(0.0, _damage_alpha - delta * 1.1)
		_damage_flash.color = Color(0.937255, 0.266667, 0.266667, _damage_alpha)

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
	if _aim_mode_btn != null:
		_aim_mode_btn.text = mode_str
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
	if _pause_overlay != null:
		_pause_overlay.visible = is_paused
	if _bottom_safe_margin != null:
		_bottom_safe_margin.visible = not is_paused


func _on_match_ended(winning_team: int, blue_score: int, orange_score: int, player_eliminations: int) -> void:
	_match_ended = true
	_respawn_active = false
	_reset_touch_controls()
	if _pause_overlay != null:
		_pause_overlay.visible = false
	if _toast_panel != null:
		_toast_panel.visible = false
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

	if _end_detail_label != null:
		_end_detail_label.text = (
			"امتیاز نهایی: آبی %d  —  %d نارنجی\n"
			+ "تعداد حذف تیم آبی: %d\n"
			+ "آمار کلی ذخیره شده: %d پیروزی از %d نبرد"
		) % [blue_score, orange_score, player_eliminations, SaveManager.total_wins, SaveManager.total_matches]

	if _match_end_overlay != null:
		_match_end_overlay.visible = true


func _on_aim_fire_mode_changed(_mode_name: String) -> void:
	_apply_aim_fire_mode()


func _on_player_zone_changed(_zone_id: String, zone_title_fa: String, inside: bool) -> void:
	_active_zone_title = zone_title_fa if inside else "میدان آزاد"
	_update_zone_badge(_active_zone_title)


func _on_player_stats_updated(hp: int, max_hp: int, energy: int, max_energy: int, blaster_name_fa: String, recharging: bool) -> void:
	if _stats_label == null:
		return
	var energy_str: String = "در حال شارژ..." if recharging else "%d/%d" % [energy, max_energy]
	_stats_label.text = "جان: %d/%d | %s: %s" % [hp, max_hp, blaster_name_fa, energy_str]
	if hp <= 30:
		_stats_label.add_theme_color_override("font_color", Color(0.984314, 0.45098, 0.086275, 1.0))
	else:
		_stats_label.add_theme_color_override("font_color", Color(0.901961, 0.960784, 1.0, 1.0))


func _on_player_damaged_feedback(_hp_ratio: float) -> void:
	_damage_alpha = 0.28


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


func _update_zone_badge(zone_title: String) -> void:
	if _zone_label != null:
		_zone_label.text = "منطقه: %s" % zone_title


func _update_perf_badge() -> void:
	if _perf_label == null:
		return
	var current_fps: int = int(round(Engine.get_frames_per_second()))
	_perf_label.text = "%d FPS" % current_fps


func get_move_vector() -> Vector2:
	return _left_move_stick.output_vector if _left_move_stick != null else Vector2.ZERO


func get_aim_vector() -> Vector2:
	return _right_aim_stick.output_vector if _right_aim_stick != null else Vector2.ZERO


func is_fire_active() -> bool:
	if SaveManager.aim_fire_mode == "fire_button":
		return _dedicated_fire_pad != null and _dedicated_fire_pad.is_pressed
	return _right_aim_stick != null and _right_aim_stick.is_fire_engaged


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
	GameManager.go_to_arena_sector_01()


func _on_btn_back_menu_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_main_menu()


func _on_btn_aim_mode_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_mode: String = "fire_button" if SaveManager.aim_fire_mode == "twin_stick" else "twin_stick"
	GameManager.set_aim_fire_mode(next_mode)
