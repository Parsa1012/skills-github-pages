extends CanvasLayer
## رابط کاربری کنترل لمسی چندلمسی، جان/انرژی، امتیاز و وضعیت میدان نبرد.

@onready var _top_safe_margin: MarginContainer = $TopSafeMargin
@onready var _bottom_safe_margin: MarginContainer = $BottomSafeMargin
@onready var _left_move_stick: VirtualJoystick = $BottomSafeMargin/TouchControlsRow/LeftMoveStick
@onready var _right_aim_stick: VirtualJoystick = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/RightAimStick
@onready var _dedicated_fire_pad: TouchFirePad = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/FirePadAnchor/DedicatedFirePad
@onready var _btn_switch_blaster: TouchActionButton = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow/BtnSwitchBlaster
@onready var _btn_recharge: TouchActionButton = $BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow/BtnRecharge
@onready var _score_label: Label = $TopSafeMargin/TopHudBar/ScoreBadge/ScoreLabel
@onready var _stats_label: Label = $TopSafeMargin/TopHudBar/StatsBadge/StatsLabel
@onready var _zone_label: Label = $TopSafeMargin/TopHudBar/ZoneBadge/ZoneLabel
@onready var _perf_label: Label = $TopSafeMargin/TopHudBar/PerfBadge/PerfLabel
@onready var _aim_mode_btn: Button = $TopSafeMargin/TopHudBar/BtnAimMode

var _active_zone_title: String = "میدان آزاد"
var _fps_sample_timer: float = 0.0


func _ready() -> void:
	if _top_safe_margin != null:
		_top_safe_margin.layout_direction = Control.LAYOUT_DIRECTION_RTL
	if _bottom_safe_margin != null:
		_bottom_safe_margin.layout_direction = Control.LAYOUT_DIRECTION_LTR

	_setup_excluded_controls()
	_apply_safe_area_margins()
	_apply_aim_fire_mode()
	_update_zone_badge("میدان آزاد")
	_update_score_badge(0, 0)
	_update_perf_badge()

	get_viewport().size_changed.connect(_apply_safe_area_margins)
	EventBus.aim_fire_mode_changed.connect(_on_aim_fire_mode_changed)
	EventBus.player_zone_changed.connect(_on_player_zone_changed)
	EventBus.player_stats_updated.connect(_on_player_stats_updated)
	EventBus.score_updated.connect(_on_score_updated)

	if _btn_switch_blaster != null:
		_btn_switch_blaster.action_triggered.connect(_on_switch_blaster_triggered)
	if _btn_recharge != null:
		_btn_recharge.action_triggered.connect(_on_recharge_triggered)


func _process(delta: float) -> void:
	_fps_sample_timer += delta
	if _fps_sample_timer >= 0.45:
		_fps_sample_timer = 0.0
		_update_perf_badge()


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
	if _aim_mode_btn != null:
		_aim_mode_btn.text = "حالت: دکمه شلیک" if is_fire_button_mode else "حالت: دو جوی‌استیک"


func _on_aim_fire_mode_changed(_mode_name: String) -> void:
	_apply_aim_fire_mode()


func _on_player_zone_changed(_zone_id: String, zone_title_fa: String, inside: bool) -> void:
	_active_zone_title = zone_title_fa if inside else "میدان آزاد"
	_update_zone_badge(_active_zone_title)


func _on_player_stats_updated(hp: int, max_hp: int, energy: int, max_energy: int, blaster_name_fa: String, recharging: bool) -> void:
	if _stats_label == null:
		return
	var energy_str: String = "در حال شارژ..." if recharging else "%d / %d" % [energy, max_energy]
	_stats_label.text = "جان: %d/%d  |  %s: %s" % [hp, max_hp, blaster_name_fa, energy_str]
	if hp <= 30:
		_stats_label.add_theme_color_override("font_color", Color(0.984314, 0.45098, 0.086275, 1.0))
	else:
		_stats_label.add_theme_color_override("font_color", Color(0.901961, 0.960784, 1.0, 1.0))


func _on_score_updated(blue_score: int, orange_score: int) -> void:
	_update_score_badge(blue_score, orange_score)


func _update_score_badge(blue_score: int, orange_score: int) -> void:
	if _score_label != null:
		_score_label.text = "آبی %d  —  %d نارنجی" % [blue_score, orange_score]


func _update_zone_badge(zone_title: String) -> void:
	if _zone_label != null:
		_zone_label.text = "موقعیت: %s" % zone_title


func _update_perf_badge() -> void:
	if _perf_label == null:
		return
	var current_fps: int = int(round(Engine.get_frames_per_second()))
	_perf_label.text = "%d/%d FPS" % [current_fps, SaveManager.target_fps]


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


func _on_btn_back_menu_pressed() -> void:
	AudioManager.play_ui_pop()
	GameManager.go_to_main_menu()


func _on_btn_aim_mode_pressed() -> void:
	AudioManager.play_ui_menu()
	var next_mode: String = "fire_button" if SaveManager.aim_fire_mode == "twin_stick" else "twin_stick"
	GameManager.set_aim_fire_mode(next_mode)
