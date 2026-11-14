class_name ArenaBotProfile
extends Resource
## Fictional offline AI bot difficulty profile (implemented in Phase 4).

enum DifficultyTier {
	ROOKIE,
	TACTICAL,
	ACE
}

@export var profile_id: StringName = &"tactical_bot"
@export var display_name: String = "Tactical Drone"
@export var difficulty: DifficultyTier = DifficultyTier.TACTICAL
@export_range(40.0, 200.0, 5.0) var max_shield: float = 100.0
@export_range(2.0, 10.0, 0.25) var move_speed: float = 5.6
@export_range(0.05, 1.2, 0.05) var reaction_delay_sec: float = 0.30
@export_range(0.2, 1.0, 0.05) var aim_precision: float = 0.72
@export_range(6.0, 26.0, 1.0) var sight_range: float = 15.0
@export_range(0.0, 1.0, 0.05) var zone_objective_focus: float = 0.75
