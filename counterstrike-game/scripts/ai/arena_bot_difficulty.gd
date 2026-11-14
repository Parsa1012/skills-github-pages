class_name ArenaBotDifficulty
extends RefCounted
## Fair, deterministic configuration for offline arcade bot decisions.

const EASY: StringName = &"easy"
const NORMAL: StringName = &"normal"
const HARD: StringName = &"hard"


static func normalize_id(raw_id: String) -> StringName:
	match raw_id.to_lower():
		"easy":
			return EASY
		"hard":
			return HARD
		"normal", "balanced":
			return NORMAL
		_:
			return NORMAL


static func get_settings(raw_id: String) -> Dictionary:
	match normalize_id(raw_id):
		EASY:
			return {
				"perception_interval": 0.40,
				"reaction_multiplier": 1.80,
				"aim_error_multiplier": 1.40,
				"navigation_interval": 1.35,
				"objective_bias": 0.55,
				"wait_min": 1.0,
				"wait_max": 1.65
			}
		HARD:
			return {
				"perception_interval": 0.19,
				"reaction_multiplier": 0.60,
				"aim_error_multiplier": 0.82,
				"navigation_interval": 0.58,
				"objective_bias": 0.92,
				"wait_min": 0.30,
				"wait_max": 0.65
			}
		_:
			return {
				"perception_interval": 0.28,
				"reaction_multiplier": 1.0,
				"aim_error_multiplier": 1.0,
				"navigation_interval": 0.88,
				"objective_bias": 0.74,
				"wait_min": 0.55,
				"wait_max": 1.0
			}


static func get_label_fa(raw_id: String) -> String:
	match normalize_id(raw_id):
		EASY:
			return "آسان"
		HARD:
			return "سخت"
		_:
			return "عادی"
