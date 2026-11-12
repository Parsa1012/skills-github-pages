extends Node
## Independent offline audio scaffold for UI and arena sound effects (populated in Phase 6).

const MAX_UI_PLAYERS: int = 4
const MAX_SFX_PLAYERS: int = 8

var _ui_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_cursor: int = 0
var _sfx_cursor: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_player_pools()
	apply_volumes()


func _build_player_pools() -> void:
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


func apply_volumes() -> void:
	var ui_db: float = linear_to_db(maxf(SaveManager.master_volume * SaveManager.ui_volume, 0.0001))
	var sfx_db: float = linear_to_db(maxf(SaveManager.master_volume * SaveManager.sfx_volume, 0.0001))

	for p in _ui_players:
		p.volume_db = ui_db if (SaveManager.master_volume * SaveManager.ui_volume) > 0.001 else -80.0
	for p in _sfx_players:
		p.volume_db = sfx_db if (SaveManager.master_volume * SaveManager.sfx_volume) > 0.001 else -80.0


func play_ui_stream(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	if stream == null or _ui_players.is_empty():
		return
	var player: AudioStreamPlayer = _ui_players[_ui_cursor]
	_ui_cursor = (_ui_cursor + 1) % _ui_players.size()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.play()


func play_sfx_stream(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	if stream == null or _sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.play()
