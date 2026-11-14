class_name ArenaModeConfig
extends Resource
## قوانین آفلاین حالت‌های مسابقه (کنترل مناطق و نبرد سریع تیمی).

enum ModeType {
	ZONE_CONTROL_ROUNDS,
	TEAM_SCORE_RUSH,
	PRACTICE_ARENA
}

@export var mode_id: StringName = &"zone_control"
@export var display_name: String = "کنترل مناطق"
@export var mode_type: ModeType = ModeType.ZONE_CONTROL_ROUNDS
@export var enable_capture_zones: bool = true
@export_range(1, 15, 1) var rounds_to_win: int = 1
@export_range(30.0, 240.0, 5.0) var round_duration_sec: float = 120.0
@export_range(1.0, 15.0, 0.5) var zone_capture_seconds: float = 4.0
@export_range(0, 10, 1) var zone_capture_bonus: int = 2
@export_range(1.0, 15.0, 0.5) var zone_hold_tick_interval: float = 5.0
@export_range(0, 5, 1) var zone_hold_points: int = 1
@export_range(10, 100, 5) var target_score: int = 25
@export_range(1, 5, 1) var bots_per_team: int = 3
