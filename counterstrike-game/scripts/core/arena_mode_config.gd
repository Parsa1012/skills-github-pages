class_name ArenaModeConfig
extends Resource
## Fictional arcade match ruleset with capturable zones and round scoring (Phase 5).

enum ModeType {
	ZONE_CONTROL_ROUNDS,
	TEAM_SCORE_RUSH,
	PRACTICE_ARENA
}

@export var mode_id: StringName = &"zone_control"
@export var display_name: String = "Zone Control"
@export var mode_type: ModeType = ModeType.ZONE_CONTROL_ROUNDS
@export_range(1, 15, 1) var rounds_to_win: int = 5
@export_range(30.0, 240.0, 5.0) var round_duration_sec: float = 90.0
@export_range(1.0, 15.0, 0.5) var zone_capture_seconds: float = 4.0
@export_range(10, 100, 5) var target_score: int = 30
@export_range(1, 5, 1) var bots_per_team: int = 3
