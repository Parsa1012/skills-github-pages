extends Node3D
## کنترلر میدان نبرد آرکید (حالت‌های بازی، تایمر نبرد، تصرف مناطق، امتیازدهی و پایان مسابقه).

const PROJECTILE_SCENE_PATH: String = "res://scenes/combat/energy_projectile.tscn"
const IMPACT_FLASH_SCENE_PATH: String = "res://scenes/combat/impact_flash.tscn"

@onready var _sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var _camera_rig: ArenaCameraRig = $ArenaCameraRig
@onready var _player: PlayerController = $PlayerCharacter

var _mode_config: ArenaModeConfig = null
var _blue_score: int = 0
var _orange_score: int = 0
var _player_eliminations: int = 0
var _target_score: int = 25
var _time_remaining: float = 120.0
var _last_reported_second: int = -1
var _zone_tick_timer: float = 0.0
var _match_over: bool = false


func _ready() -> void:
	get_tree().paused = false
	AudioManager.stop_menu_music()
	GameManager.current_state = GameManager.AppState.ARENA_PLAY
	_mode_config = GameManager.get_active_mode_config()
	if _mode_config != null:
		_target_score = maxi(1, _mode_config.target_score)
		_time_remaining = maxf(15.0, float(_mode_config.round_duration_sec))

	_prewarm_combat_pools()
	_apply_quality_lighting(SaveManager.quality_preset)
	EventBus.quality_preset_changed.connect(_apply_quality_lighting)
	EventBus.zone_captured.connect(_on_zone_captured)

	if _camera_rig != null and _player != null:
		_camera_rig.set_target(_player)
	if _player != null:
		_player.player_defeated.connect(_on_player_defeated)

	for bot in get_tree().get_nodes_in_group("arena_bots"):
		if bot is ArenaBot:
			(bot as ArenaBot).bot_defeated.connect(_on_bot_defeated)

	if _mode_config != null and not _mode_config.enable_capture_zones:
		for zone in get_tree().get_nodes_in_group("capture_zones"):
			if zone is CaptureZonePad:
				(zone as CaptureZonePad).visible = false
				(zone as CaptureZonePad).monitoring = false

	EventBus.score_updated.emit(_blue_score, _orange_score)
	_report_timer_if_changed()
	if _mode_config != null:
		EventBus.hud_toast_requested.emit(
			"%s — هدف: %d امتیاز" % [_mode_config.display_name, _target_score],
			Color(0.219608, 0.741176, 0.972549, 1.0)
		)


func _exit_tree() -> void:
	get_tree().paused = false
	if EventBus.quality_preset_changed.is_connected(_apply_quality_lighting):
		EventBus.quality_preset_changed.disconnect(_apply_quality_lighting)
	if EventBus.zone_captured.is_connected(_on_zone_captured):
		EventBus.zone_captured.disconnect(_on_zone_captured)
	PoolManager.clear_all_pools()


func _process(delta: float) -> void:
	if _match_over:
		return

	_time_remaining = maxf(0.0, _time_remaining - delta)
	_report_timer_if_changed()

	if _mode_config != null and _mode_config.enable_capture_zones:
		_zone_tick_timer += delta
		var tick_interval: float = maxf(1.0, _mode_config.zone_hold_tick_interval)
		if _zone_tick_timer >= tick_interval:
			_zone_tick_timer -= tick_interval
			_award_zone_hold_points()

	if _time_remaining <= 0.0:
		_finish_match()


func _report_timer_if_changed() -> void:
	var sec_int: int = int(ceil(_time_remaining))
	if sec_int != _last_reported_second:
		_last_reported_second = sec_int
		EventBus.match_timer_updated.emit(sec_int)


func _prewarm_combat_pools() -> void:
	if ResourceLoader.exists(PROJECTILE_SCENE_PATH):
		var proj_scene: Resource = ResourceLoader.load(PROJECTILE_SCENE_PATH)
		if proj_scene is PackedScene:
			PoolManager.register_pool(EnergyProjectile.POOL_ID, proj_scene as PackedScene, 36)
	if ResourceLoader.exists(IMPACT_FLASH_SCENE_PATH):
		var flash_scene: Resource = ResourceLoader.load(IMPACT_FLASH_SCENE_PATH)
		if flash_scene is PackedScene:
			PoolManager.register_pool(ImpactFlash.POOL_ID, flash_scene as PackedScene, 18)


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
		_blue_score += blue_gain
		_orange_score += orange_gain
		EventBus.score_updated.emit(_blue_score, _orange_score)
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
		_blue_score += bonus
		EventBus.hud_toast_requested.emit(
			"تیم آبی %s را تصرف کرد! (+%d)" % [zone_title_fa, bonus],
			Color(0.219608, 0.741176, 0.972549, 1.0)
		)
	elif capturing_team == 1:
		_orange_score += bonus
		EventBus.hud_toast_requested.emit(
			"تیم نارنجی %s را تصرف کرد! (+%d)" % [zone_title_fa, bonus],
			Color(0.984314, 0.45098, 0.086275, 1.0)
		)

	EventBus.score_updated.emit(_blue_score, _orange_score)
	_check_win_conditions()


func _on_bot_defeated(bot: ArenaBot, attacker_team: int) -> void:
	if _match_over:
		return
	if bot != null and bot.team_id == attacker_team:
		return
	if attacker_team == 0:
		_blue_score += 1
		if bot != null and bot.team_id == 1:
			_player_eliminations += 1
			EventBus.hud_toast_requested.emit(
				"%s نابود شد! (+1)" % (bot.profile.display_name if bot.profile != null else "پهپاد دشمن"),
				Color(0.219608, 0.741176, 0.972549, 1.0)
			)
	else:
		_orange_score += 1
	EventBus.score_updated.emit(_blue_score, _orange_score)
	_check_win_conditions()


func _on_player_defeated(_attacker_team: int) -> void:
	if _match_over:
		return
	_orange_score += 1
	EventBus.score_updated.emit(_blue_score, _orange_score)
	_check_win_conditions()


func _check_win_conditions() -> void:
	if _match_over:
		return
	if _blue_score >= _target_score or _orange_score >= _target_score:
		_finish_match()


func _finish_match() -> void:
	if _match_over:
		return
	_match_over = true
	var winning_team: int = -1
	if _blue_score > _orange_score:
		winning_team = 0
	elif _orange_score > _blue_score:
		winning_team = 1

	GameManager.record_match_result(winning_team == 0, _player_eliminations)
	get_tree().paused = true
	AudioManager.play_ui_pop()
	EventBus.match_ended.emit(winning_team, _blue_score, _orange_score, _player_eliminations)


func get_match_state() -> Dictionary:
	return {
		"blue_score": _blue_score,
		"orange_score": _orange_score,
		"target_score": _target_score,
		"time_remaining": _time_remaining,
		"player_eliminations": _player_eliminations,
		"match_over": _match_over,
		"mode_id": _mode_config.mode_id if _mode_config != null else "zone_control"
	}


func _apply_quality_lighting(preset_name: String) -> void:
	if _sun_light == null:
		return
	match preset_name:
		"low":
			_sun_light.shadow_enabled = false
		"medium":
			_sun_light.shadow_enabled = true
			_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		"high":
			_sun_light.shadow_enabled = true
			_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
