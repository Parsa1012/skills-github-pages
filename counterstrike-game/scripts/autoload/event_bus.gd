extends Node
## مرکز سیگنال‌های تایپ‌شده برای ارتباط غیرمتمرکز بین زیرسیستم‌های آفلاین بازی.

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
signal selected_mode_changed(mode_id: String)

@warning_ignore("unused_signal")
signal selected_map_changed(map_id: String)

@warning_ignore("unused_signal")
signal starting_blaster_changed(blaster_id: String)

@warning_ignore("unused_signal")
signal player_buff_updated(damage_secs: float, speed_secs: float)

@warning_ignore("unused_signal")
signal player_dash_updated(cooldown_left: float, cooldown_total: float, ready: bool)

@warning_ignore("unused_signal")
signal enemy_hit_confirmed(damage: float, is_kill: bool)

@warning_ignore("unused_signal")
signal kill_feed_event(killer_fa: String, victim_fa: String, killer_team: int)

@warning_ignore("unused_signal")
signal kill_streak_announced(streak_count: int, title_fa: String)

@warning_ignore("unused_signal")
signal camera_trauma_requested(amount: float)

@warning_ignore("unused_signal")
signal player_zone_changed(zone_id: String, zone_title_fa: String, inside: bool)

@warning_ignore("unused_signal")
signal player_stats_updated(hp: int, max_hp: int, energy: int, max_energy: int, blaster_name_fa: String, recharging: bool)

@warning_ignore("unused_signal")
signal player_damaged_feedback(hp_ratio: float)

@warning_ignore("unused_signal")
signal player_respawn_countdown(seconds_left: float, active: bool)

@warning_ignore("unused_signal")
signal blaster_switch_requested()

@warning_ignore("unused_signal")
signal blaster_recharge_requested()

@warning_ignore("unused_signal")
signal player_dash_requested()

@warning_ignore("unused_signal")
signal match_started(mode_id: String, target_score: int)

@warning_ignore("unused_signal")
signal match_timer_updated(seconds_remaining: int)

@warning_ignore("unused_signal")
signal match_paused_changed(is_paused: bool)

@warning_ignore("unused_signal")
signal hud_toast_requested(message_fa: String, accent_color: Color)

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
signal match_ended(winning_team: int, blue_score: int, orange_score: int, player_eliminations: int)
