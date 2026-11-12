extends Node
## Central typed signal hub for decoupled offline subsystems across phases.

@warning_ignore("unused_signal")
signal scene_change_requested(scene_path: String)

@warning_ignore("unused_signal")
signal fps_target_changed(target_fps: int)

@warning_ignore("unused_signal")
signal quality_preset_changed(preset_name: String)

@warning_ignore("unused_signal")
signal camera_settings_changed()

@warning_ignore("unused_signal")
signal aim_fire_mode_changed(mode_name: String)

@warning_ignore("unused_signal")
signal player_zone_changed(zone_id: String, zone_title_fa: String, inside: bool)

@warning_ignore("unused_signal")
signal match_started(mode_id: String)

@warning_ignore("unused_signal")
signal round_started(round_index: int)

@warning_ignore("unused_signal")
signal round_ended(winning_team: int, reason: String)

@warning_ignore("unused_signal")
signal zone_capture_progress(zone_id: String, team_id: int, progress: float)

@warning_ignore("unused_signal")
signal zone_captured(zone_id: String, team_id: int)

@warning_ignore("unused_signal")
signal score_updated(blue_score: int, orange_score: int)

@warning_ignore("unused_signal")
signal match_ended(winning_team: int)
