extends Node
## مدیر صدای مستقل و آفلاین برای موسیقی جنگی منو و نبرد + افکت‌های صوتی سلاح‌ها.

const UI_TAP_PATH: String = "res://assets/audio/sfx_ui_tap.wav"
const UI_SWITCH_PATH: String = "res://assets/audio/sfx_ui_switch.wav"
const UI_CONFIRM_PATH: String = "res://assets/audio/sfx_ui_confirm.wav"
const MENU_BGM_PATH: String = "res://assets/audio/bgm_menu_arcade.wav"
const ARENA_BGM_PATH: String = "res://assets/audio/bgm_arena_combat.wav"
const ARENA_AMBIENCE_PATH: String = "res://assets/audio/bgm_arena_ambience.wav"
const FOOTSTEP_SFX_PATH: String = "res://assets/audio/sfx_step_soft.wav"
const PICKUP_SFX_PATH: String = "res://assets/audio/sfx_pickup_item.wav"
const RECHARGE_SFX_PATH: String = "res://assets/audio/sfx_recharge_done.wav"
const ZONE_CAPTURE_SFX_PATH: String = "res://assets/audio/sfx_zone_capture.wav"
const PLAYER_HIT_SFX_PATH: String = "res://assets/audio/sfx_player_hit.wav"
const DASH_SFX_PATH: String = "res://assets/audio/sfx_dash_whoosh.wav"
const HITMARKER_SFX_PATH: String = "res://assets/audio/sfx_hitmarker.wav"
const VICTORY_SFX_PATH: String = "res://assets/audio/sfx_match_victory.wav"
const DEFEAT_SFX_PATH: String = "res://assets/audio/sfx_match_defeat.wav"
const BOMB_THROW_SFX_PATH: String = "res://assets/audio/sfx_bomb_throw.wav"
const BOMB_EXPLODE_SFX_PATH: String = "res://assets/audio/sfx_bomb_explode.wav"

const MAX_UI_PLAYERS: int = 4
const MAX_SFX_PLAYERS: int = 12

var _music_player: AudioStreamPlayer = null
var _ambience_player: AudioStreamPlayer = null
var _ui_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_cursor: int = 0
var _sfx_cursor: int = 0

var _menu_music: AudioStream = null
var _arena_music: AudioStream = null
var _arena_ambience: AudioStream = null
var _sfx_cooldown_until_msec: Dictionary = {}
var _ui_tap_sfx: AudioStream = null
var _ui_switch_sfx: AudioStream = null
var _ui_confirm_sfx: AudioStream = null
var _sfx_cache: Dictionary = {}
var _music_mode: String = "" # "" | "menu" | "arena"
var _music_ducked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_player_pools()
	_load_bundled_audio()
	apply_volumes()


func _exit_tree() -> void:
	_music_mode = ""
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	if _ambience_player != null:
		_ambience_player.stop()
		_ambience_player.stream = null
	for p in _ui_players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for p in _sfx_players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_menu_music = null
	_arena_music = null
	_arena_ambience = null
	_sfx_cooldown_until_msec.clear()
	_ui_tap_sfx = null
	_ui_switch_sfx = null
	_ui_confirm_sfx = null
	_sfx_cache.clear()


func _build_player_pools() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "ArenaAmbiencePlayer"
	_ambience_player.finished.connect(_on_ambience_finished)
	add_child(_ambience_player)

	for i in MAX_UI_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.name = "UIAudio_%d" % i
		add_child(p)
		_ui_players.append(p)

	for i in MAX_SFX_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.name = "SFXAudio_%d" % i
		add_child(p)
		_sfx_players.append(p)


func _load_bundled_audio() -> void:
	# Avoid loading/caching audio resources on silent runners or devices without an output driver.
	if _is_dummy_audio_driver():
		return
	if ResourceLoader.exists(UI_TAP_PATH):
		_ui_tap_sfx = ResourceLoader.load(UI_TAP_PATH)
	if ResourceLoader.exists(UI_SWITCH_PATH):
		_ui_switch_sfx = ResourceLoader.load(UI_SWITCH_PATH)
	if ResourceLoader.exists(UI_CONFIRM_PATH):
		_ui_confirm_sfx = ResourceLoader.load(UI_CONFIRM_PATH)
	if ResourceLoader.exists(MENU_BGM_PATH):
		var bgm: Resource = ResourceLoader.load(MENU_BGM_PATH)
		if bgm is AudioStream:
			_menu_music = bgm as AudioStream
	if ResourceLoader.exists(ARENA_BGM_PATH):
		var abgm: Resource = ResourceLoader.load(ARENA_BGM_PATH)
		if abgm is AudioStream:
			_arena_music = abgm as AudioStream
	if ResourceLoader.exists(ARENA_AMBIENCE_PATH):
		var ambient: Resource = ResourceLoader.load(ARENA_AMBIENCE_PATH)
		if ambient is AudioStreamWAV:
			var ambient_wav := ambient as AudioStreamWAV
			ambient_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			_arena_ambience = ambient_wav


func apply_volumes() -> void:
	var music_scale: float = (0.38 if _music_ducked else 1.0) * (0.46 if _music_mode == "arena" else 0.72)
	var music_lin: float = SaveManager.master_volume * SaveManager.music_volume * music_scale if SaveManager.music_enabled else 0.0
	var ui_lin: float = SaveManager.master_volume * SaveManager.ui_volume if SaveManager.sfx_enabled else 0.0
	var sfx_lin: float = SaveManager.master_volume * SaveManager.sfx_volume if SaveManager.sfx_enabled else 0.0
	var ambience_lin: float = sfx_lin * 0.20

	if _ambience_player != null:
		_ambience_player.volume_db = linear_to_db(ambience_lin) if ambience_lin > 0.001 else -80.0
		if ambience_lin <= 0.001 and _ambience_player.playing:
			_ambience_player.stop()
		elif ambience_lin > 0.001 and _music_mode == "arena":
			_ensure_ambience_playing()

	if _music_player != null:
		_music_player.volume_db = linear_to_db(music_lin) if music_lin > 0.001 else -80.0
		if not SaveManager.music_enabled and _music_player.playing:
			_music_player.stop()

	var ui_db: float = linear_to_db(ui_lin) if ui_lin > 0.001 else -80.0
	var sfx_db: float = linear_to_db(sfx_lin) if sfx_lin > 0.001 else -80.0
	for p in _ui_players:
		p.volume_db = ui_db
	for p in _sfx_players:
		p.volume_db = sfx_db


func _ensure_music_playing() -> void:
	if not SaveManager.music_enabled or _music_player == null:
		return
	var target_stream: AudioStream = null
	if _music_mode == "menu":
		target_stream = _menu_music
	elif _music_mode == "arena":
		target_stream = _arena_music
	if target_stream == null:
		return
	if _music_player.stream != target_stream:
		_music_player.stop()
		_music_player.stream = target_stream
	if _is_dummy_audio_driver():
		return
	if not _music_player.playing:
		_music_player.play()


func play_menu_music() -> void:
	_music_mode = "menu"
	if _ambience_player != null:
		_ambience_player.stop()
	_music_ducked = false
	apply_volumes()
	_ensure_music_playing()


func play_arena_music() -> void:
	_music_mode = "arena"
	_music_ducked = false
	apply_volumes()
	_ensure_music_playing()
	_ensure_ambience_playing()


func stop_all_music() -> void:
	_music_mode = ""
	if _ambience_player != null and _ambience_player.playing:
		_ambience_player.stop()
	if _music_player != null and _music_player.playing:
		_music_player.stop()


func set_music_ducked(ducked: bool) -> void:
	_music_ducked = ducked
	apply_volumes()


func _ensure_ambience_playing() -> void:
	if _ambience_player == null or _arena_ambience == null or not SaveManager.sfx_enabled:
		return
	if _ambience_player.stream != _arena_ambience:
		_ambience_player.stop()
		_ambience_player.stream = _arena_ambience
	if not _is_dummy_audio_driver() and not _ambience_player.playing:
		_ambience_player.play()


func _on_ambience_finished() -> void:
	if _music_mode == "arena":
		_ensure_ambience_playing()


func set_music_enabled(enabled: bool) -> void:
	SaveManager.music_enabled = enabled
	SaveManager.save_settings()
	apply_volumes()
	if enabled and not _music_mode.is_empty():
		_ensure_music_playing()


func set_sfx_enabled(enabled: bool) -> void:
	SaveManager.sfx_enabled = enabled
	SaveManager.save_settings()
	apply_volumes()


func set_master_volume(volume: float) -> void:
	SaveManager.master_volume = clampf(volume, 0.1, 1.0)
	SaveManager.save_settings()
	apply_volumes()


func set_music_volume(volume: float) -> void:
	SaveManager.music_volume = clampf(volume, 0.0, 1.0)
	SaveManager.save_settings()
	apply_volumes()


func set_sfx_volume(volume: float) -> void:
	SaveManager.sfx_volume = clampf(volume, 0.0, 1.0)
	SaveManager.save_settings()
	apply_volumes()


func play_pickup_sfx() -> void:
	play_sfx_path(PICKUP_SFX_PATH, randf_range(0.97, 1.04), -1.0)


func play_recharge_done_sfx() -> void:
	play_sfx_path(RECHARGE_SFX_PATH, 1.0, -2.0)


func play_zone_capture_sfx(pitch_scale: float = 1.0) -> void:
	play_sfx_path(ZONE_CAPTURE_SFX_PATH, pitch_scale, -1.5)


func play_player_hit_sfx() -> void:
	play_sfx_path(PLAYER_HIT_SFX_PATH, randf_range(0.92, 1.05), -1.0)


func play_dash_sfx() -> void:
	play_sfx_path(DASH_SFX_PATH, randf_range(0.96, 1.06), -2.5)


func play_footstep_sfx() -> void:
	play_sfx_path(FOOTSTEP_SFX_PATH, randf_range(0.94, 1.06), -14.0)


func play_hitmarker_sfx(is_kill: bool = false) -> void:
	play_sfx_path(HITMARKER_SFX_PATH, 1.24 if is_kill else randf_range(0.96, 1.04), -1.5 if is_kill else -5.5)


func play_match_end_sfx(winning_team: int) -> void:
	if winning_team == 0:
		play_sfx_path(VICTORY_SFX_PATH, 1.0, 0.0)
	elif winning_team == 1:
		play_sfx_path(DEFEAT_SFX_PATH, 1.0, 0.0)
	else:
		play_sfx_path(UI_CONFIRM_PATH, 0.88, -3.0)


func play_bomb_throw_sfx() -> void:
	play_sfx_path(BOMB_THROW_SFX_PATH, randf_range(0.95, 1.05), -2.0)


func play_bomb_explode_sfx() -> void:
	play_sfx_path(BOMB_EXPLODE_SFX_PATH, randf_range(0.93, 1.04), 0.5)


func play_ui_click(pitch_scale: float = 1.0) -> void:
	play_ui_stream(_ui_tap_sfx, pitch_scale)


func play_ui_menu(pitch_scale: float = 1.0) -> void:
	play_ui_stream(_ui_switch_sfx, pitch_scale)


func play_ui_pop(pitch_scale: float = 1.0) -> void:
	play_ui_stream(_ui_confirm_sfx, pitch_scale)


func play_sfx_path(resource_path: String, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if _is_dummy_audio_driver() or not SaveManager.sfx_enabled or resource_path.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var next_allowed: int = int(_sfx_cooldown_until_msec.get(resource_path, 0))
	if now_msec < next_allowed:
		return
	var min_gap: int = 190 if resource_path == FOOTSTEP_SFX_PATH else 42
	_sfx_cooldown_until_msec[resource_path] = now_msec + min_gap
	var stream: AudioStream = _sfx_cache.get(resource_path, null) as AudioStream
	if stream == null and ResourceLoader.exists(resource_path):
		var loaded: Resource = ResourceLoader.load(resource_path)
		if loaded is AudioStream:
			stream = loaded as AudioStream
			_sfx_cache[resource_path] = stream
	if stream != null:
		play_sfx_stream(stream, pitch_scale, volume_offset_db)


func play_ui_stream(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	if not SaveManager.sfx_enabled or stream == null or _ui_players.is_empty():
		return
	var player: AudioStreamPlayer = _ui_players[_ui_cursor]
	_ui_cursor = (_ui_cursor + 1) % _ui_players.size()
	player.stream = stream
	player.pitch_scale = pitch_scale
	if not _is_dummy_audio_driver():
		player.play()


func play_sfx_stream(stream: AudioStream, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not SaveManager.sfx_enabled or stream == null or _sfx_players.is_empty():
		return
	var sfx_lin: float = SaveManager.master_volume * SaveManager.sfx_volume
	var base_db: float = linear_to_db(sfx_lin) if sfx_lin > 0.001 else -80.0
	var player: AudioStreamPlayer = _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = base_db + volume_offset_db
	if not _is_dummy_audio_driver():
		player.play()


func _on_music_finished() -> void:
	if _is_dummy_audio_driver() or not SaveManager.music_enabled or _music_player == null:
		return
	if _music_mode == "menu" and _menu_music != null:
		_music_player.play()
	elif _music_mode == "arena" and _arena_music != null:
		_music_player.play()


func _is_dummy_audio_driver() -> bool:
	if DisplayServer.get_name().to_lower() == "headless" or OS.get_environment("ARENA_CI_SILENT_AUDIO") == "1":
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--audio-driver" and i + 1 < args.size() and args[i + 1].to_lower() == "dummy":
			return true
		if args[i].begins_with("--audio-driver=") and args[i].get_slice("=", 1).to_lower() == "dummy":
			return true
	return false
