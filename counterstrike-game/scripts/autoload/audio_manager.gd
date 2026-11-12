extends Node
## Independent offline audio manager using bundled MP3 assets inside counterstrike-game/assets/audio/.

const MENU_MUSIC_PATH: String = "res://assets/audio/main_menu.mp3"
const UI_CLICK_PATH: String = "res://assets/audio/ui_click.mp3"
const UI_MENU_PATH: String = "res://assets/audio/ui_menu.mp3"
const UI_POP_PATH: String = "res://assets/audio/ui_pop.mp3"

const MAX_UI_PLAYERS: int = 4
const MAX_SFX_PLAYERS: int = 8

var _music_player: AudioStreamPlayer = null
var _ui_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_cursor: int = 0
var _sfx_cursor: int = 0

var _menu_music: AudioStream = null
var _ui_click_sfx: AudioStream = null
var _ui_menu_sfx: AudioStream = null
var _ui_pop_sfx: AudioStream = null
var _menu_music_requested: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_player_pools()
	_load_bundled_audio()
	apply_volumes()


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
	if ResourceLoader.exists(MENU_MUSIC_PATH):
		_menu_music = ResourceLoader.load(MENU_MUSIC_PATH)
		if _menu_music is AudioStreamMP3:
			(_menu_music as AudioStreamMP3).loop = true

	if ResourceLoader.exists(UI_CLICK_PATH):
		_ui_click_sfx = ResourceLoader.load(UI_CLICK_PATH)
	if ResourceLoader.exists(UI_MENU_PATH):
		_ui_menu_sfx = ResourceLoader.load(UI_MENU_PATH)
	if ResourceLoader.exists(UI_POP_PATH):
		_ui_pop_sfx = ResourceLoader.load(UI_POP_PATH)


func apply_volumes() -> void:
	var music_lin: float = SaveManager.master_volume * SaveManager.music_volume if SaveManager.music_enabled else 0.0
	var ui_lin: float = SaveManager.master_volume * SaveManager.ui_volume if SaveManager.sfx_enabled else 0.0
	var sfx_lin: float = SaveManager.master_volume * SaveManager.sfx_volume if SaveManager.sfx_enabled else 0.0

	if _music_player != null:
		_music_player.volume_db = linear_to_db(music_lin) if music_lin > 0.001 else -80.0
		if not SaveManager.music_enabled and _music_player.playing:
			_music_player.stop()
		elif SaveManager.music_enabled and _menu_music_requested and not _music_player.playing:
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


func play_ui_click(pitch_scale: float = 1.0) -> void:
	play_ui_stream(_ui_click_sfx, pitch_scale)


func play_ui_menu(pitch_scale: float = 1.0) -> void:
	play_ui_stream(_ui_menu_sfx, pitch_scale)


func play_ui_pop(pitch_scale: float = 1.0) -> void:
	play_ui_stream(_ui_pop_sfx, pitch_scale)


func play_ui_stream(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	if not SaveManager.sfx_enabled or stream == null or _ui_players.is_empty():
		return
	var player: AudioStreamPlayer = _ui_players[_ui_cursor]
	_ui_cursor = (_ui_cursor + 1) % _ui_players.size()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.play()


func play_sfx_stream(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	if not SaveManager.sfx_enabled or stream == null or _sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.play()


func _on_music_finished() -> void:
	if _menu_music_requested and SaveManager.music_enabled and _music_player != null and _menu_music != null:
		_music_player.play()
