extends Node
## Offline persistent configuration using Godot ConfigFile (no network calls).

const SETTINGS_PATH: String = "user://arena_settings.cfg"

var target_fps: int = 30
var quality_preset: String = "medium"
var master_volume: float = 0.85
var music_volume: float = 0.70
var sfx_volume: float = 0.85
var ui_volume: float = 0.85
var music_enabled: bool = true
var sfx_enabled: bool = true


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(SETTINGS_PATH)
	if err != OK:
		apply_defaults()
		return

	target_fps = clampi(int(config.get_value("performance", "target_fps", 30)), 30, 60)
	if target_fps != 30 and target_fps != 60:
		target_fps = 30

	var loaded_preset: String = str(config.get_value("performance", "quality_preset", "medium"))
	if loaded_preset in ["low", "medium", "high"]:
		quality_preset = loaded_preset
	else:
		quality_preset = "medium"

	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.85)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music_volume", 0.70)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 0.85)), 0.0, 1.0)
	ui_volume = clampf(float(config.get_value("audio", "ui_volume", 0.85)), 0.0, 1.0)
	music_enabled = bool(config.get_value("audio", "music_enabled", true))
	sfx_enabled = bool(config.get_value("audio", "sfx_enabled", true))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("performance", "target_fps", target_fps)
	config.set_value("performance", "quality_preset", quality_preset)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ui_volume", ui_volume)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.save(SETTINGS_PATH)


func apply_defaults() -> void:
	target_fps = 30
	quality_preset = "medium"
	master_volume = 0.85
	music_volume = 0.70
	sfx_volume = 0.85
	ui_volume = 0.85
	music_enabled = true
	sfx_enabled = true
