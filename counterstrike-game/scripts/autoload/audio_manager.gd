extends Node
## مدیر صدای مستقل و آفلاین برای افکت‌های رابط کاربری و صدای گیم‌پلی (اختصاصی + Kenney CC0/MIT).

const UI_TAP_PATH: String = "res://assets/audio/sfx_ui_tap.wav"
const UI_SWITCH_PATH: String = "res://assets/audio/sfx_ui_switch.wav"
const UI_CONFIRM_PATH: String = "res://assets/audio/sfx_ui_confirm.wav"
const MENU_BGM_PATH: String = "res://assets/audio/bgm_menu_arcade.wav"
const PICKUP_SFX_PATH: String = "res://assets/audio/sfx_pickup_item.wav"
const RECHARGE_SFX_PATH: String = "res://assets/audio/sfx_recharge_done.wav"
const ZONE_CAPTURE_SFX_PATH: String = "res://assets/audio/sfx_zone_capture.wav"
const PLAYER_HIT_SFX_PATH: String = "res://assets/audio/sfx_player_hit.wav"

const MAX_UI_PLAYERS: int = 4
const MAX_SFX_PLAYERS: int = 10

var _music_player: AudioStreamPlayer = null
var _ui_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_cursor: int = 0
var _sfx_cursor: int = 0

var _menu_music: AudioStream = null
var _ui_tap_sfx: AudioStream = null
var _ui_switch_sfx: AudioStream = null
var _ui_confirm_sfx: AudioStream = null
var _sfx_cache: Dictionary = {}
var _menu_music_requested: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_player_pools()
	_load_bundled_audio()
	apply_volumes()


func _exit_tree() -> void:
	_menu_music_requested = false
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	for p in _ui_players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for p in _sfx_players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_menu_music = null
	_ui_tap_sfx = null
	_ui_switch_sfx = null
	_ui_confirm_sfx = null
	_sfx_cache.clear()


func _build_player_pools() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

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


func register_menu_music(stream: AudioStream) -> void:
	_menu_music = stream
	if _menu_music_requested:
		play_menu_music()


func apply_volumes() -> void:
	var music_lin: float = SaveManager.master_volume * SaveManager.music_volume if SaveManager.music_enabled else 0.0
	var ui_lin: float = SaveManager.master_volume * SaveManager.ui_volume if SaveManager.sfx_enabled else 0.0
	var sfx_lin: float = SaveManager.master_volume * SaveManager.sfx_volume if SaveManager.sfx_enabled else 0.0

	if _music_player != null:
		_music_player.volume_db = linear_to_db(music_lin) if music_lin > 0.001 else -80.0
		if not SaveManager.music_enabled and _music_player.playing:
			_music_player.stop()
		elif SaveManager.music_enabled and _menu_music_requested and _menu_music != null and not _music_player.playing:
			play_menu_music()

	var ui_db: float = linear_to_db(ui_lin) if ui_lin > 0.001 else -80.0
	var sfx_db: float = linear_to_db(sfx_lin) if sfx_lin > 0.001 else -80.0
	for p in _ui_players:
		p.volume_db = ui_db
	for p in _sfx_players:
		p.volume_db = sfx_db


func play_menu_music() -> void:
	_menu_music_requested = true
	if not SaveManager.music_enabled or _music_player == null or _menu_music == null:
		return
	if _music_player.stream != _menu_music:
		_music_player.stream = _menu_music
	if not _music_player.playing:
		_music_player.play()


func stop_menu_music() -> void:
	_menu_music_requested = false
	if _music_player != null and _music_player.playing:
		_music_player.stop()


func set_music_enabled(enabled: bool) -> void:
	SaveManager.music_enabled = enabled
	SaveManager.save_settings()
	apply_volumes()


func set_sfx_enabled(enabled: bool) -> void:
	SaveManager.sfx_enabled = enabled
	SaveManager.save_settings()
	apply_volumes()


func set_master_volume(volume: float) -> void:
	SaveManager.master_volume = clampf(volume, 0.1, 1.0)
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


func play_ui_click(pitch_scale: float = 1.0) -> void:
	play_ui_stream(_ui_tap_sfx, pitch_scale)


func play_ui_menu(pitch_scale: float = 1.0) -> void:
	play_ui_stream(_ui_switch_sfx, pitch_scale)


func play_ui_pop(pitch_scale: float = 1.0) -> void:
	play_ui_stream(_ui_confirm_sfx, pitch_scale)


func play_sfx_path(resource_path: String, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not SaveManager.sfx_enabled or resource_path.is_empty():
		return
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
	player.play()


func _on_music_finished() -> void:
	if _menu_music_requested and SaveManager.music_enabled and _music_player != null and _menu_music != null:
		_music_player.play()
