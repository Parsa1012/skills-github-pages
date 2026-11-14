extends Node
## ذخیره آفلاین و ایمن تنظیمات گرافیک، کنترل، صدا و کارنامه نبرد بازیکن.

const SETTINGS_PATH: String = "user://arena_settings.cfg"

const RANK_THRESHOLDS: Array[Dictionary] = [
	{"level": 1, "xp": 0, "title": "سرباز تازه‌کار"},
	{"level": 2, "xp": 200, "title": "تکاور خط‌مقدم"},
	{"level": 3, "xp": 500, "title": "فرمانده عملیات"},
	{"level": 4, "xp": 950, "title": "شکارچی نخبگان"},
	{"level": 5, "xp": 1500, "title": "افسانه کانتر آرنا"}
]

var target_fps: int = 60
var quality_preset: String = "medium"
var render_scale: float = 0.85
var shadows_enabled: bool = true
var show_fps: bool = false

var aim_fire_mode: String = "twin_stick" # "twin_stick" | "fire_button"
var joystick_sensitivity: float = 1.0 # 0.85 | 1.0 | 1.25
var camera_preset: String = "classic" # "classic" | "tactical" | "close"
var camera_shake_enabled: bool = true
var haptics_enabled: bool = true
var large_text_enabled: bool = false

var selected_mode_id: String = "zone_control" # "zone_control" | "team_score_rush" | "zone_blitz"
var selected_map_id: String = "sector_01" # "sector_01" | "sector_02"
var starting_blaster_id: String = "pulse_blaster" # "pulse_blaster" | "rapid_repeater" | "plasma_scatter" | "arc_railgun"
var bot_difficulty: String = "balanced" # "easy" | "balanced" | "hard"

var master_volume: float = 0.85
var music_volume: float = 0.72
var sfx_volume: float = 0.90
var ui_volume: float = 0.85
var music_enabled: bool = true
var sfx_enabled: bool = true

var total_matches: int = 0
var total_wins: int = 0
var total_eliminations: int = 0
var best_match_eliminations: int = 0
var career_xp: int = 0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(SETTINGS_PATH)
	if err != OK:
		apply_defaults()
		return

	var loaded_fps: int = int(config.get_value("performance", "target_fps", 60))
	target_fps = loaded_fps if loaded_fps in [30, 45, 60] else 60

	var loaded_preset: String = str(config.get_value("performance", "quality_preset", "medium"))
	quality_preset = loaded_preset if loaded_preset in ["low", "medium", "high"] else "medium"
	render_scale = clampf(float(config.get_value("performance", "render_scale", 0.85)), 0.65, 1.0)
	shadows_enabled = bool(config.get_value("performance", "shadows_enabled", true))
	show_fps = bool(config.get_value("performance", "show_fps", false))

	var loaded_aim_mode: String = str(config.get_value("controls", "aim_fire_mode", "twin_stick"))
	aim_fire_mode = loaded_aim_mode if loaded_aim_mode in ["twin_stick", "fire_button"] else "twin_stick"
	joystick_sensitivity = clampf(float(config.get_value("controls", "joystick_sensitivity", 1.0)), 0.85, 1.35)
	camera_shake_enabled = bool(config.get_value("controls", "camera_shake_enabled", true))
	haptics_enabled = bool(config.get_value("controls", "haptics_enabled", true))
	large_text_enabled = bool(config.get_value("accessibility", "large_text_enabled", false))

	var loaded_cam: String = str(config.get_value("camera", "camera_preset", "classic"))
	camera_preset = loaded_cam if loaded_cam in ["classic", "tactical", "close"] else "classic"

	var loaded_mode: String = str(config.get_value("match", "selected_mode_id", "zone_control"))
	selected_mode_id = loaded_mode if loaded_mode in ["zone_control", "team_score_rush", "zone_blitz"] else "zone_control"

	var loaded_map: String = str(config.get_value("match", "selected_map_id", "sector_01"))
	selected_map_id = loaded_map if loaded_map in ["sector_01", "sector_02"] else "sector_01"

	var loaded_blaster: String = str(config.get_value("loadout", "starting_blaster_id", "pulse_blaster"))
	starting_blaster_id = loaded_blaster if loaded_blaster in ["pulse_blaster", "rapid_repeater", "plasma_scatter", "arc_railgun"] else "pulse_blaster"

	var loaded_diff: String = str(config.get_value("ai", "bot_difficulty", "balanced"))
	bot_difficulty = loaded_diff if loaded_diff in ["easy", "balanced", "hard"] else "balanced"

	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.85)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music_volume", 0.72)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 0.90)), 0.0, 1.0)
	ui_volume = clampf(float(config.get_value("audio", "ui_volume", 0.85)), 0.0, 1.0)
	music_enabled = bool(config.get_value("audio", "music_enabled", true))
	sfx_enabled = bool(config.get_value("audio", "sfx_enabled", true))

	total_matches = maxi(0, int(config.get_value("career", "total_matches", 0)))
	total_wins = maxi(0, int(config.get_value("career", "total_wins", 0)))
	total_eliminations = maxi(0, int(config.get_value("career", "total_eliminations", 0)))
	best_match_eliminations = maxi(0, int(config.get_value("career", "best_match_eliminations", 0)))
	career_xp = maxi(0, int(config.get_value("career", "career_xp", 0)))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("performance", "target_fps", target_fps)
	config.set_value("performance", "quality_preset", quality_preset)
	config.set_value("performance", "render_scale", render_scale)
	config.set_value("performance", "shadows_enabled", shadows_enabled)
	config.set_value("performance", "show_fps", show_fps)
	config.set_value("controls", "aim_fire_mode", aim_fire_mode)
	config.set_value("controls", "joystick_sensitivity", joystick_sensitivity)
	config.set_value("controls", "camera_shake_enabled", camera_shake_enabled)
	config.set_value("controls", "haptics_enabled", haptics_enabled)
	config.set_value("accessibility", "large_text_enabled", large_text_enabled)
	config.set_value("camera", "camera_preset", camera_preset)
	config.set_value("match", "selected_mode_id", selected_mode_id)
	config.set_value("match", "selected_map_id", selected_map_id)
	config.set_value("loadout", "starting_blaster_id", starting_blaster_id)
	config.set_value("ai", "bot_difficulty", bot_difficulty)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ui_volume", ui_volume)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.set_value("career", "total_matches", total_matches)
	config.set_value("career", "total_wins", total_wins)
	config.set_value("career", "total_eliminations", total_eliminations)
	config.set_value("career", "best_match_eliminations", best_match_eliminations)
	config.set_value("career", "career_xp", career_xp)
	config.save(SETTINGS_PATH)


func reset_settings_keep_career() -> void:
	target_fps = 60
	quality_preset = "medium"
	render_scale = 0.85
	shadows_enabled = true
	show_fps = false
	aim_fire_mode = "twin_stick"
	joystick_sensitivity = 1.0
	camera_preset = "classic"
	camera_shake_enabled = true
	haptics_enabled = true
	large_text_enabled = false
	bot_difficulty = "balanced"
	master_volume = 0.85
	music_volume = 0.72
	sfx_volume = 0.90
	ui_volume = 0.85
	music_enabled = true
	sfx_enabled = true
	save_settings()


func apply_defaults() -> void:
	reset_settings_keep_career()
	selected_mode_id = "zone_control"
	selected_map_id = "sector_01"
	starting_blaster_id = "pulse_blaster"
	total_matches = 0
	total_wins = 0
	total_eliminations = 0
	best_match_eliminations = 0
	career_xp = 0


func get_rank_info() -> Dictionary:
	var current: Dictionary = RANK_THRESHOLDS[0]
	var next_xp: int = int(RANK_THRESHOLDS[1]["xp"])
	for i in RANK_THRESHOLDS.size():
		var tier: Dictionary = RANK_THRESHOLDS[i]
		if career_xp >= int(tier["xp"]):
			current = tier
			next_xp = int(RANK_THRESHOLDS[i + 1]["xp"]) if i + 1 < RANK_THRESHOLDS.size() else int(tier["xp"])
	var base_xp: int = int(current["xp"])
	var progress: float = 1.0
	if next_xp > base_xp:
		progress = clampf(float(career_xp - base_xp) / float(next_xp - base_xp), 0.0, 1.0)
	return {
		"level": int(current["level"]),
		"title_fa": str(current["title"]),
		"xp": career_xp,
		"next_xp": next_xp,
		"progress": progress
	}
