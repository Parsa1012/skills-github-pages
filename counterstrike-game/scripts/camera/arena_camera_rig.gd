@tool
class_name ArenaCameraRig
extends Node3D
## Fixed-yaw BombSquad-style Angled Top-Down / Bird's-Eye 2.5D camera rig.
## Reads pitch, distance, FOV, and smoothing from ProjectSettings ("arena_camera/*")
## unless overridden via `config_override` or runtime test controls.

@export var target_path: NodePath
@export var config_override: CameraConfig:
	set(value):
		config_override = value
		if is_node_ready():
			apply_camera_settings()

@export var target_vertical_offset: float = 0.85
@export var use_arena_bounds: bool = true
@export var bounds_min: Vector2 = Vector2(-10.5, -6.5)
@export var bounds_max: Vector2 = Vector2(10.5, 6.5)

@onready var _yaw_pivot: Node3D = $CameraYawPivot
@onready var _pitch_pivot: Node3D = $CameraYawPivot/CameraPitchPivot
@onready var _camera: Camera3D = $CameraYawPivot/CameraPitchPivot/Camera3D

var _target_node: Node3D = null
var _active_pitch: float = 57.5
var _active_yaw: float = 0.0
var _active_distance: float = 19.5
var _active_fov: float = 44.0
var _follow_smoothness: float = 6.5
var _look_ahead_distance: float = 1.25
var _last_target_pos: Vector3 = Vector3.ZERO
var _has_last_target_pos: bool = false
var _trauma: float = 0.0
var _shake_time: float = 0.0


func _ready() -> void:
	apply_camera_settings()
	if not Engine.is_editor_hint():
		_resolve_target()
		snap_to_target()
		var event_bus: Node = get_node_or_null("/root/EventBus")
		if event_bus != null:
			if not event_bus.is_connected("camera_settings_changed", reload_from_project_settings):
				event_bus.connect("camera_settings_changed", reload_from_project_settings)
			if event_bus.has_signal("camera_preset_changed") and not event_bus.is_connected("camera_preset_changed", _on_camera_preset_changed):
				event_bus.connect("camera_preset_changed", _on_camera_preset_changed)
			if event_bus.has_signal("camera_trauma_requested") and not event_bus.is_connected("camera_trauma_requested", add_trauma):
				event_bus.connect("camera_trauma_requested", add_trauma)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		var event_bus: Node = get_node_or_null("/root/EventBus")
		if event_bus != null:
			if event_bus.is_connected("camera_settings_changed", reload_from_project_settings):
				event_bus.disconnect("camera_settings_changed", reload_from_project_settings)
			if event_bus.has_signal("camera_preset_changed") and event_bus.is_connected("camera_preset_changed", _on_camera_preset_changed):
				event_bus.disconnect("camera_preset_changed", _on_camera_preset_changed)
			if event_bus.has_signal("camera_trauma_requested") and event_bus.is_connected("camera_trauma_requested", add_trauma):
				event_bus.disconnect("camera_trauma_requested", add_trauma)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 2.2)
		_shake_time += delta * 42.0
		if _camera != null:
			var mag: float = _trauma * _trauma * 0.14
			_camera.h_offset = sin(_shake_time * 1.13) * mag
			_camera.v_offset = cos(_shake_time * 1.37) * mag
	elif _camera != null and (_camera.h_offset != 0.0 or _camera.v_offset != 0.0):
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0

	if _target_node == null or not is_instance_valid(_target_node):
		_resolve_target()
		if _target_node == null:
			return

	var desired_focus: Vector3 = _compute_desired_focus(_target_node, delta)
	var blend: float = 1.0 - exp(-_follow_smoothness * maxf(delta, 0.0001))
	global_position = global_position.lerp(desired_focus, blend)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _on_camera_preset_changed(_preset: String) -> void:
	apply_camera_settings()


func reload_from_project_settings() -> void:
	config_override = null
	apply_camera_settings()


func apply_camera_settings() -> void:
	var cfg: CameraConfig = config_override if config_override != null else CameraConfig.from_project_settings()
	_active_pitch = clampf(cfg.pitch_degrees, 45.0, 75.0)
	# Yaw remains fixed (no 360-degree free rotation in mobile 2.5D mode).
	_active_yaw = clampf(cfg.yaw_degrees, -45.0, 45.0)
	_active_distance = clampf(cfg.distance, 12.0, 32.0)
	if not Engine.is_editor_hint() and config_override == null:
		var sm: Node = get_node_or_null("/root/SaveManager")
		if sm != null:
			var preset: String = str(sm.get("camera_preset"))
			if preset == "tactical":
				_active_pitch = 63.0
				_active_distance = 22.5
			elif preset == "close":
				_active_pitch = 52.0
				_active_distance = 16.5
	_active_fov = clampf(cfg.fov_degrees, 32.0, 60.0)
	_follow_smoothness = clampf(cfg.follow_smoothness, 1.0, 20.0)
	_look_ahead_distance = clampf(cfg.look_ahead_distance, 0.0, 4.0)
	_apply_rig_transforms()


func set_test_parameters(pitch_deg: float, distance_m: float, fov_deg: float = -1.0) -> void:
	_active_pitch = clampf(pitch_deg, 45.0, 75.0)
	_active_distance = clampf(distance_m, 12.0, 32.0)
	if fov_deg > 0.0:
		_active_fov = clampf(fov_deg, 32.0, 60.0)
	_apply_rig_transforms()


func set_target(node: Node3D) -> void:
	_target_node = node
	_has_last_target_pos = false
	snap_to_target()


func snap_to_target() -> void:
	if _target_node == null or not is_instance_valid(_target_node):
		return
	_last_target_pos = _target_node.global_position
	_has_last_target_pos = true
	global_position = _clamp_focus(_target_node.global_position + Vector3(0.0, target_vertical_offset, 0.0))


func get_active_pitch() -> float:
	return _active_pitch


func get_active_distance() -> float:
	return _active_distance


func get_active_fov() -> float:
	return _active_fov


func get_camera_world_height() -> float:
	return _active_distance * sin(deg_to_rad(_active_pitch))


func _apply_rig_transforms() -> void:
	if _yaw_pivot != null:
		_yaw_pivot.rotation_degrees = Vector3(0.0, _active_yaw, 0.0)
	if _pitch_pivot != null:
		_pitch_pivot.rotation_degrees = Vector3(-_active_pitch, 0.0, 0.0)
	if _camera != null:
		_camera.position = Vector3(0.0, 0.0, _active_distance)
		_camera.fov = _active_fov
		_camera.far = 120.0
		_camera.near = 0.5


func _resolve_target() -> void:
	if not target_path.is_empty() and has_node(target_path):
		var candidate: Node = get_node(target_path)
		if candidate is Node3D:
			_target_node = candidate as Node3D


func _compute_desired_focus(target: Node3D, delta: float) -> Vector3:
	var target_pos: Vector3 = target.global_position
	var look_ahead: Vector3 = Vector3.ZERO

	if _has_last_target_pos and delta > 0.0001 and _look_ahead_distance > 0.0:
		var vel_xz: Vector3 = (target_pos - _last_target_pos) / delta
		vel_xz.y = 0.0
		var speed: float = vel_xz.length()
		if speed > 0.15:
			var clamped_ratio: float = clampf(speed / 6.0, 0.0, 1.0)
			look_ahead = vel_xz.normalized() * (_look_ahead_distance * clamped_ratio)

	_last_target_pos = target_pos
	_has_last_target_pos = true

	var raw_focus: Vector3 = target_pos + Vector3(0.0, target_vertical_offset, 0.0) + look_ahead
	return _clamp_focus(raw_focus)


func _clamp_focus(pos: Vector3) -> Vector3:
	if not use_arena_bounds:
		return pos
	return Vector3(
		clampf(pos.x, bounds_min.x, bounds_max.x),
		pos.y,
		clampf(pos.z, bounds_min.y, bounds_max.y)
	)
