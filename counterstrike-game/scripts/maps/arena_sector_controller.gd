extends Node3D
## کنترلر میدان نبرد آرکید (حالت‌های بازی، تایمر نبرد، تصرف مناطق، خوراک کشته‌ها، زنجیره حذف و امتیاز تجربه).

const PROJECTILE_SCENE_PATH: String = "res://scenes/combat/energy_projectile.tscn"
const IMPACT_FLASH_SCENE_PATH: String = "res://scenes/combat/impact_flash.tscn"
const PULSE_BOMB_SCENE_PATH: String = "res://scenes/combat/pulse_bomb.tscn"

@onready var _world_env: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
@onready var _sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var _rim_light: DirectionalLight3D = get_node_or_null("RimLight") as DirectionalLight3D
@onready var _camera_rig: ArenaCameraRig = $ArenaCameraRig
@onready var _player: PlayerController = $PlayerCharacter

var _mode_config: ArenaModeConfig = null
var _blue_score: int = 0
var _orange_score: int = 0
var _player_eliminations: int = 0
var _player_kill_streak: int = 0
var _last_xp_gained: int = 0
var player_eliminations: int = 0
var _collision_overlay: Node = null
var _target_score: int = 25
var _time_remaining: float = 120.0
var _last_reported_second: int = -1
var _zone_tick_timer: float = 0.0
var _match_over: bool = false


func _ready() -> void:
	add_to_group("arena_match_controller")
	get_tree().paused = false
	_setup_bot_navigation()
	AudioManager.play_arena_music()
	GameManager.current_state = GameManager.AppState.ARENA_PLAY
	_mode_config = GameManager.get_active_mode_config()
	if _mode_config != null:
		_target_score = maxi(1, _mode_config.target_score)
		_time_remaining = maxf(15.0, float(_mode_config.round_duration_sec))
		GameManager.start_offline_match(String(_mode_config.mode_id), _target_score, _mode_config.round_duration_sec)
		_time_remaining = GameManager.round_time_remaining

	_setup_collision_debug()
	GameManager.assign_match_teams(_player, get_tree().get_nodes_in_group("arena_bots"))
	_prewarm_combat_pools()
	_apply_quality_lighting(SaveManager.quality_preset)
	EventBus.quality_preset_changed.connect(_apply_quality_lighting)
	EventBus.zone_captured.connect(_on_zone_captured)
	EventBus.round_time_expired.connect(_on_round_time_expired)
	EventBus.next_round_requested.connect(_on_next_round_requested)

	if _camera_rig != null and _player != null:
		_camera_rig.set_target(_player)
	if _player != null:
		_player.player_defeated.connect(_on_player_defeated)

	for bot in get_tree().get_nodes_in_group("arena_bots"):
		if bot is ArenaBot:
			(bot as ArenaBot).bot_defeated.connect(_on_bot_defeated)

	for zone in get_tree().get_nodes_in_group("capture_zones"):
		if zone is CaptureZonePad:
			var pad := zone as CaptureZonePad
			if _mode_config != null:
				pad.capture_seconds = maxf(1.0, _mode_config.zone_capture_seconds)
				if not _mode_config.enable_capture_zones:
					pad.visible = false
					pad.monitoring = false
					var pole_col: CollisionShape3D = pad.get_node_or_null("ZoneFlagBody/CollisionShape3D") as CollisionShape3D
					if pole_col != null:
						pole_col.set_deferred("disabled", true)

	EventBus.score_updated.emit(_blue_score, _orange_score)
	_report_timer_if_changed()
	if _mode_config != null:
		var map_label: String = "پایگاه کویری براوو" if SaveManager.selected_map_id == "sector_02" else "پایگاه نظامی آلفا"
		EventBus.hud_toast_requested.emit(
			"%s • %s (هدف: %d)" % [map_label, _mode_config.display_name, _target_score],
			Color(0.219608, 0.741176, 0.972549, 1.0)
		)


func _setup_collision_debug() -> void:
	if not OS.is_debug_build():
		return
	_collision_overlay = ArenaCollisionDebugOverlay.new()
	_collision_overlay.name = "CollisionDebugOverlay"
	add_child(_collision_overlay)
	var layer := CanvasLayer.new()
	layer.name = "CollisionDebugTouchLayer"
	add_child(layer)
	var button := Button.new()
	button.name = "CollisionDebugToggle"
	button.text = "COLLISIONS OFF"
	button.custom_minimum_size = Vector2(150, 46)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -168.0
	button.offset_right = -16.0
	button.offset_top = 14.0
	button.offset_bottom = 60.0
	button.pressed.connect(_toggle_collision_debug)
	layer.add_child(button)


func _toggle_collision_debug() -> void:
	if _collision_overlay == null:
		return
	var overlay := _collision_overlay as ArenaCollisionDebugOverlay
	overlay.set_enabled(not overlay.enabled)
	var button := get_node_or_null("CollisionDebugTouchLayer/CollisionDebugToggle") as Button
	if button != null:
		button.text = "COLLISIONS ON" if overlay.enabled else "COLLISIONS OFF"


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F3:
		_toggle_collision_debug()


func _setup_bot_navigation() -> void:
	var navigation := ArenaNavigationGrid.new()
	navigation.name = "ArenaNavigationGrid"
	navigation.debug_navigation = OS.is_debug_build() and bool(ProjectSettings.get_setting("application/run/enable_navigation_debug", false))
	add_child(navigation)
	navigation.add_to_group("arena_navigation")
	var nav_min: Vector2 = _camera_rig.bounds_min if _camera_rig != null else Vector2(-14.5, -10.5)
	var nav_max: Vector2 = _camera_rig.bounds_max if _camera_rig != null else Vector2(14.5, 10.5)
	navigation.configure(nav_min + Vector2(0.55, 0.55), nav_max - Vector2(0.55, 0.55))


func _exit_tree() -> void:
	get_tree().paused = false
	if EventBus.quality_preset_changed.is_connected(_apply_quality_lighting):
		EventBus.quality_preset_changed.disconnect(_apply_quality_lighting)
	if EventBus.zone_captured.is_connected(_on_zone_captured):
		EventBus.zone_captured.disconnect(_on_zone_captured)
	if EventBus.round_time_expired.is_connected(_on_round_time_expired):
		EventBus.round_time_expired.disconnect(_on_round_time_expired)
	if EventBus.next_round_requested.is_connected(_on_next_round_requested):
		EventBus.next_round_requested.disconnect(_on_next_round_requested)
	PoolManager.clear_all_pools()
	VisualFxUtils.clear_caches()


func _process(delta: float) -> void:
	if _match_over or GameManager.is_match_complete() or not GameManager.is_match_live():
		return
	_time_remaining = GameManager.round_time_remaining
	_report_timer_if_changed()
	if _mode_config != null and _mode_config.enable_capture_zones:
		_zone_tick_timer += delta
		var tick_interval: float = maxf(1.0, _mode_config.zone_hold_tick_interval)
		if _zone_tick_timer >= tick_interval:
			_zone_tick_timer -= tick_interval
			_award_zone_hold_points()


func _report_timer_if_changed() -> void:
	var sec_int: int = int(ceil(_time_remaining))
	if sec_int != _last_reported_second:
		_last_reported_second = sec_int
		EventBus.match_timer_updated.emit(sec_int)


func _prewarm_combat_pools() -> void:
	if ResourceLoader.exists(PROJECTILE_SCENE_PATH):
		var proj_scene: Resource = ResourceLoader.load(PROJECTILE_SCENE_PATH)
		if proj_scene is PackedScene:
			PoolManager.register_pool(EnergyProjectile.POOL_ID, proj_scene as PackedScene, 48)
	if ResourceLoader.exists(IMPACT_FLASH_SCENE_PATH):
		var flash_scene: Resource = ResourceLoader.load(IMPACT_FLASH_SCENE_PATH)
		if flash_scene is PackedScene:
			PoolManager.register_pool(ImpactFlash.POOL_ID, flash_scene as PackedScene, 24)
	if ResourceLoader.exists(PULSE_BOMB_SCENE_PATH):
		var bomb_scene: Resource = ResourceLoader.load(PULSE_BOMB_SCENE_PATH)
		if bomb_scene is PackedScene:
			PoolManager.register_pool(PulseBomb.POOL_ID, bomb_scene as PackedScene, 6)


func _award_zone_hold_points() -> void:
	if _match_over:
		return
	var blue_gain: int = 0
	var orange_gain: int = 0
	var pts_per_zone: int = _mode_config.zone_hold_points if _mode_config != null else 1
	for zone in get_tree().get_nodes_in_group("capture_zones"):
		if zone is CaptureZonePad:
			var owner_team: int = (zone as CaptureZonePad).get_owner_team()
			if owner_team == 0:
				blue_gain += pts_per_zone
			elif owner_team == 1:
				orange_gain += pts_per_zone

	if blue_gain > 0 or orange_gain > 0:
		_add_round_score(0, blue_gain)
		_add_round_score(1, orange_gain)
		_check_win_conditions()


func _on_zone_captured(zone_id: String, capturing_team: int) -> void:
	if _match_over:
		return
	if _mode_config != null and not _mode_config.enable_capture_zones:
		return

	var zone_title_fa: String = zone_id
	for zone in get_tree().get_nodes_in_group("capture_zones"):
		if zone is CaptureZonePad and (zone as CaptureZonePad).zone_id == zone_id:
			zone_title_fa = (zone as CaptureZonePad).zone_title_fa
			break

	var bonus: int = _mode_config.zone_capture_bonus if _mode_config != null else 2
	if capturing_team == 0:
		_add_round_score(0, bonus)
		EventBus.hud_toast_requested.emit(
			"تیم آبی %s را تصرف کرد! (+%d)" % [zone_title_fa, bonus],
			Color(0.219608, 0.741176, 0.972549, 1.0)
		)
	elif capturing_team == 1:
		_add_round_score(1, bonus)
		EventBus.hud_toast_requested.emit(
			"تیم نارنجی %s را تصرف کرد! (+%d)" % [zone_title_fa, bonus],
			Color(0.984314, 0.45098, 0.086275, 1.0)
		)

	_check_win_conditions()


func _on_bot_defeated(bot: ArenaBot, attacker_team: int) -> void:
	if _match_over:
		return
	if bot != null and bot.team_id == attacker_team:
		return

	var bot_name_fa: String = bot.profile.display_name if (bot != null and bot.profile != null) else "سرباز"
	if attacker_team == 0:
		_add_round_score(0, 1)
		if bot != null and bot.team_id == 1:
			var by_player: bool = bot.was_last_hit_by_player()
			_player_eliminations += 1
			GameManager.record_player_elimination()
			if by_player:
				_player_kill_streak += 1
				EventBus.kill_feed_event.emit("بازیکن", bot_name_fa, 0)
				_announce_streak_if_reached()
			else:
				EventBus.kill_feed_event.emit("هم‌تیمی آبی", bot_name_fa, 0)
				EventBus.hud_toast_requested.emit(
					"%s نابود شد! (+1)" % bot_name_fa,
					Color(0.219608, 0.741176, 0.972549, 1.0)
				)
	else:
		_add_round_score(1, 1)
		EventBus.kill_feed_event.emit("تیم نارنجی", bot_name_fa, 1)

	_check_win_conditions()


func _announce_streak_if_reached() -> void:
	if _player_kill_streak < 2:
		return
	var streak_fa: String = "دو حذف پیاپی!"
	if _player_kill_streak == 3:
		streak_fa = "سه حذف متوالی!"
	elif _player_kill_streak >= 4:
		streak_fa = "توقف‌ناپذیر! (%d حذف)" % _player_kill_streak
	EventBus.kill_streak_announced.emit(_player_kill_streak, streak_fa)
	EventBus.hud_toast_requested.emit(streak_fa, Color(0.984314, 0.74902, 0.141176, 1.0))


func _on_player_defeated(_attacker_team: int) -> void:
	if _match_over:
		return
	_player_kill_streak = 0
	_add_round_score(1, 1)
	EventBus.kill_feed_event.emit("تیم نارنجی", "بازیکن", 1)
	_check_win_conditions()


func _add_round_score(team_id: int, points: int) -> void:
	GameManager.award_round_points(team_id, points)
	_blue_score = GameManager.round_blue_score
	_orange_score = GameManager.round_orange_score


func _check_win_conditions() -> void:
	if not GameManager.is_match_live():
		return
	if _blue_score >= _target_score or _orange_score >= _target_score:
		_complete_round("target_score")


func _on_round_time_expired() -> void:
	if not _match_over and GameManager.is_match_live():
		_complete_round("timer")


func _complete_round(reason: String) -> void:
	if _match_over or not GameManager.is_match_live():
		return
	var winner := 0 if _blue_score > _orange_score else (1 if _orange_score > _blue_score else -1)
	var match_finished: bool = GameManager.complete_current_round(winner, reason)
	if match_finished:
		_match_over = true
	else:
		EventBus.hud_toast_requested.emit(
			"پایان دور %d — امتیاز دورها آبی %d : %d نارنجی" % [GameManager.round_index, GameManager.blue_round_wins, GameManager.orange_round_wins],
			Color(0.984314, 0.74902, 0.141176, 1.0)
		)


func _on_next_round_requested() -> void:
	if _match_over or not GameManager.start_next_round():
		return
	_blue_score = 0
	_orange_score = 0
	_time_remaining = GameManager.round_duration_sec
	_zone_tick_timer = 0.0
	_player_kill_streak = 0
	if _player != null and _player.has_method("reset_for_new_round"):
		_player.call("reset_for_new_round")
	for bot in get_tree().get_nodes_in_group("arena_bots"):
		if bot.has_method("reset_for_new_round"):
			bot.call("reset_for_new_round")
	for zone in get_tree().get_nodes_in_group("capture_zones"):
		if zone.has_method("reset_for_new_round"):
			zone.call("reset_for_new_round")
	_last_reported_second = -1
	_report_timer_if_changed()


func get_last_xp_gained() -> int:
	return GameManager.last_match_xp if GameManager.is_match_complete() else _last_xp_gained


func get_match_state() -> Dictionary:
	var snapshot := GameManager.get_match_snapshot()
	snapshot["target_score"] = _target_score
	snapshot["player_eliminations"] = _player_eliminations
	snapshot["player_kill_streak"] = _player_kill_streak
	snapshot["xp_gained"] = get_last_xp_gained()
	snapshot["match_over"] = GameManager.is_match_complete()
	return snapshot


func _apply_quality_lighting(preset_name: String) -> void:
	VisualFxUtils.apply_environment_quality(
		_world_env,
		preset_name,
		SaveManager.selected_map_id == "sector_02"
	)
	if _rim_light != null:
		# روی موبایل حذف نور دوم در کیفیت کم و متوسط سرعت رندر را به شکل محسوسی افزایش می‌دهد
		_rim_light.visible = (preset_name == "high")
		_rim_light.light_energy = 0.65
	if _sun_light == null:
		return
	_sun_light.directional_shadow_max_distance = 40.0
	_sun_light.shadow_bias = 0.05
	_sun_light.shadow_normal_bias = 1.2
	var allow_shadow: bool = SaveManager.shadows_enabled and (preset_name != "low")
	_sun_light.shadow_enabled = allow_shadow
	if allow_shadow:
		_sun_light.directional_shadow_mode = (
			DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			if preset_name == "high"
			else DirectionalLight3D.SHADOW_ORTHOGONAL
		)
