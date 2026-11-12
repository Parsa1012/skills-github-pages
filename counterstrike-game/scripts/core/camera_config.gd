@tool
class_name CameraConfig
extends Resource
## Fixed-angle BombSquad-style 2.5D Bird's-Eye camera configuration.

@export_range(45.0, 75.0, 0.5) var pitch_degrees: float = 57.5
@export_range(-45.0, 45.0, 1.0) var yaw_degrees: float = 0.0
@export_range(12.0, 32.0, 0.5) var distance: float = 19.5
@export_range(32.0, 60.0, 0.5) var fov_degrees: float = 44.0
@export_range(1.0, 20.0, 0.5) var follow_smoothness: float = 6.5
@export_range(0.0, 4.0, 0.25) var look_ahead_distance: float = 1.25
@export var allow_free_rotation: bool = false


static func from_project_settings() -> CameraConfig:
	var cfg := CameraConfig.new()
	cfg.pitch_degrees = clampf(float(ProjectSettings.get_setting("arena_camera/pitch_degrees", 57.5)), 45.0, 75.0)
	cfg.yaw_degrees = clampf(float(ProjectSettings.get_setting("arena_camera/yaw_degrees", 0.0)), -45.0, 45.0)
	cfg.distance = clampf(float(ProjectSettings.get_setting("arena_camera/distance", 19.5)), 12.0, 32.0)
	cfg.fov_degrees = clampf(float(ProjectSettings.get_setting("arena_camera/fov_degrees", 44.0)), 32.0, 60.0)
	cfg.follow_smoothness = clampf(float(ProjectSettings.get_setting("arena_camera/follow_smoothness", 6.5)), 1.0, 20.0)
	cfg.look_ahead_distance = clampf(float(ProjectSettings.get_setting("arena_camera/look_ahead_distance", 1.25)), 0.0, 4.0)
	# 360-degree free camera rotation is intentionally disabled for mobile 2.5D clarity.
	cfg.allow_free_rotation = false
	return cfg
