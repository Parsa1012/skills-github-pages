extends Node
## ذخیره آفلاین و ایمن تنظیمات و آمار بازیکن با استفاده از Godot ConfigFile (بدون نیاز به اینترنت).

const SETTINGS_PATH: String = "user://arena_settings.cfg"

var target_fps: int = 30
var quality_preset: String = "medium"
var aim_fire_mode: String = "twin_stick" # "twin_stick" | "fire_button"
var selected_mode_id: String = "zone_control" # "zone_control" | "team_score_rush"
var master_volume: float = 0.85
var music_volume: float = 0.70
var sfx_volume: float = 0.85
var ui_volume: float = 0.85
var music_enabled: bool = true
var sfx_enabled: bool = true

var total_matches: int = 0
var total_wins: int = 0
var total_eliminations: int = 0


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
	quality_preset = loaded_preset if loaded_preset in ["low", "medium", "high"] else "medium"

	var loaded_aim_mode: String = str(config.get_value("controls", "aim_fire_mode", "twin_stick"))
	aim_fire_mode = loaded_aim_mode if loaded_aim_mode in ["twin_stick", "fire_button"] else "twin_stick"

	var loaded_mode: String = str(config.get_value("match", "selected_mode_id", "zone_control"))
	selected_mode_id = loaded_mode if loaded_mode in ["zone_control", "team_score_rush"] else "zone_control"

	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.85)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music_volume", 0.70)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 0.85)), 0.0, 1.0)
	ui_volume = clampf(float(config.get_value("audio", "ui_volume", 0.85)), 0.0, 1.0)
	music_enabled = bool(config.get_value("audio", "music_enabled", true))
	sfx_enabled = bool(config.get_value("audio", "sfx_enabled", true))

	total_matches = maxi(0, int(config.get_value("career", "total_matches", 0)))
	total_wins = maxi(0, int(config.get_value("career", "total_wins", 0)))
	total_eliminations = maxi(0, int(config.get_value("career", "total_eliminations", 0)))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("performance", "target_fps", target_fps)
	config.set_value("performance", "quality_preset", quality_preset)
	config.set_value("controls", "aim_fire_mode", aim_fire_mode)
	config.set_value("match", "selected_mode_id", selected_mode_id)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ui_volume", ui_volume)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.set_value("career", "total_matches", total_matches)
	config.set_value("career", "total_wins", total_wins)
	config.set_value("career", "total_eliminations", total_eliminations)
	config.save(SETTINGS_PATH)


func apply_defaults() -> void:
	target_fps = 30
	quality_preset = "medium"
	aim_fire_mode = "twin_stick"
	selected_mode_id = "zone_control"
	master_volume = 0.85
	music_volume = 0.70
	sfx_volume = 0.85
	ui_volume = 0.85
	music_enabled = true
	sfx_enabled = true
	total_matches = 0
	total_wins = 0
	total_eliminations = 0
