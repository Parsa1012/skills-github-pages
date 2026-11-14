@tool
class_name ArenaCameraRig
extends Node3D
## Smooth, fixed-yaw orthographic 2.5D camera with aspect-aware map framing.

@export var target_path: NodePath
@export var config_override: CameraConfig:
	set(value):
		config_override = value
		if is_node_ready():
			apply_camera_settings()

@export var target_vertical_offset: float = 0.85
@export_range(0.0, 2.0, 0.05) var screen_focus_offset: float = 0.65
@export var use_arena_bounds: bool = true
## Bounds are world X/Z walkable limits (Vector2.x = world X, Vector2.y = world Z).
@export var bounds_min: Vector2 = Vector2(-14.5, -10.5)
@export var bounds_max: Vector2 = Vector2(14.5, 10.5)

@onready var _yaw_pivot: Node3D = $CameraYawPivot
@onready var _pitch_pivot: Node3D = $CameraYawPivot/CameraPitchPivot
@onready var _camera: Camera3D = $CameraYawPivot/CameraPitchPivot/Camera3D

var _target_node: Node3D = null
var _active_pitch: float = 57.5
var _active_yaw: float = 0.0
## Retained for existing settings and preset compatibility; now means orthographic view height.
var _active_distance: float = 19.5
var _active_fov: float = 44.0
var _follow_smoothness: float = 6.5
var _look_ahead_distance: float = 1.25
var _viewport_size: Vector2 = Vector2(1280.0, 720.0)
var _last_target_pos: Vector3 = Vector3.ZERO
var _has_last_target_pos: bool = false
var _trauma: float = 0.0
var _shake_time: float = 0.0


func _ready() -> void:
	if get_viewport() != null:
		_viewport_size = get_viewport().get_visible_rect().size
		if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
			get_viewport().size_changed.connect(_on_viewport_size_changed)
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
	if get_viewport() != null and get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.disconnect(_on_viewport_size_changed)
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
		_trauma = maxf(0.0, _trauma - delta * 2.4)
		_shake_time += delta * 36.0
		if _camera != null:
			var mag: float = _trauma * _trauma * 0.08
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


func _on_viewport_size_changed() -> void:
	if get_viewport() != null:
		configure_for_viewport(get_viewport().get_visible_rect().size)


## Public and deterministic so viewport fitting can be tested at multiple aspect ratios.
func configure_for_viewport(viewport_size: Vector2) -> void:
	if viewport_size.x > 1.0 and viewport_size.y > 1.0:
		_viewport_size = viewport_size
	_update_orthographic_framing()


func add_trauma(amount: float) -> void:
	if not SaveManager.camera_shake_enabled:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _on_camera_preset_changed(_preset: String) -> void:
	apply_camera_settings()


func reload_from_project_settings() -> void:
	config_override = null
	apply_camera_settings()


func apply_camera_settings() -> void:
	var cfg: CameraConfig = config_override if config_override != null else CameraConfig.from_project_settings()
	_active_pitch = clampf(cfg.pitch_degrees, 45.0, 75.0)
	_active_yaw = clampf(cfg.yaw_degrees, -45.0, 45.0)
	_active_distance = clampf(cfg.distance, 12.0, 32.0)
	_active_fov = clampf(cfg.fov_degrees, 32.0, 60.0)
	_follow_smoothness = clampf(cfg.follow_smoothness, 1.0, 20.0)
	_look_ahead_distance = clampf(cfg.look_ahead_distance, 0.0, 4.0)
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
	global_position = _clamp_focus(_target_node.global_position + Vector3(0.0, target_vertical_offset, 0.0) + _get_screen_focus_offset())


func get_active_pitch() -> float:
	return _active_pitch


func get_active_distance() -> float:
	return _active_distance


func get_active_fov() -> float:
	return _active_fov


func get_orthographic_size() -> float:
	return _camera.size if _camera != null else _active_distance


func get_camera_world_height() -> float:
	return get_orthographic_size() / maxf(sin(deg_to_rad(_active_pitch)), 0.1)


func get_camera_ground_extents() -> Vector2:
	var aspect: float = _viewport_size.x / maxf(_viewport_size.y, 1.0)
	var size: float = get_orthographic_size()
	var pitch_sin: float = maxf(sin(deg_to_rad(_active_pitch)), 0.1)
	var yaw_rad: float = deg_to_rad(_active_yaw)
	var half_width: float = size * aspect * 0.5
	var half_height_ground: float = size * 0.5 / pitch_sin
	return Vector2(
		half_width * absf(cos(yaw_rad)) + half_height_ground * absf(sin(yaw_rad)),
		half_width * absf(sin(yaw_rad)) + half_height_ground * absf(cos(yaw_rad))
	)


func _apply_rig_transforms() -> void:
	if _yaw_pivot != null:
		_yaw_pivot.rotation_degrees = Vector3(0.0, _active_yaw, 0.0)
	if _pitch_pivot != null:
		_pitch_pivot.rotation_degrees = Vector3(-_active_pitch, 0.0, 0.0)
	if _camera != null:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.position = Vector3(0.0, 0.0, _active_distance)
		_camera.size = _active_distance
		_camera.fov = _active_fov # Preserved as a setting for older config resources.
		_camera.far = 120.0
		_camera.near = 0.5
	_update_orthographic_framing()


func _update_orthographic_framing() -> void:
	if _camera == null:
		return
	var aspect: float = _viewport_size.x / maxf(_viewport_size.y, 1.0)
	var pitch_sin: float = maxf(sin(deg_to_rad(_active_pitch)), 0.1)
	var yaw_rad: float = deg_to_rad(_active_yaw)
	var width_per_size: float = aspect * 0.5 * absf(cos(yaw_rad)) + 0.5 / pitch_sin * absf(sin(yaw_rad))
	var depth_per_size: float = aspect * 0.5 * absf(sin(yaw_rad)) + 0.5 / pitch_sin * absf(cos(yaw_rad))
	var fitted_size: float = _active_distance
	if use_arena_bounds:
		var bounds_size: Vector2 = (bounds_max - bounds_min).abs()
		if width_per_size > 0.001:
			fitted_size = minf(fitted_size, bounds_size.x * 0.5 / width_per_size)
		if depth_per_size > 0.001:
			fitted_size = minf(fitted_size, bounds_size.y * 0.5 / depth_per_size)
	_camera.size = maxf(6.0, fitted_size)


func _resolve_target() -> void:
	if not target_path.is_empty() and has_node(target_path):
		var candidate: Node = get_node(target_path)
		if candidate is Node3D:
			_target_node = candidate as Node3D


func _compute_desired_focus(target: Node3D, delta: float) -> Vector3:
	var target_pos: Vector3 = target.global_position
	var look_ahead: Vector3 = Vector3.ZERO
	if _has_last_target_pos and delta > 0.0001 and _look_ahead_distance > 0.0:
		var target_velocity: Vector3 = (target_pos - _last_target_pos) / delta
		target_velocity.y = 0.0
		var speed: float = target_velocity.length()
		if speed > 0.15:
			look_ahead = target_velocity.normalized() * (_look_ahead_distance * clampf(speed / 6.0, 0.0, 1.0))
	_last_target_pos = target_pos
	_has_last_target_pos = true
	return _clamp_focus(target_pos + Vector3(0.0, target_vertical_offset, 0.0) + _get_screen_focus_offset() + look_ahead)


func _get_screen_focus_offset() -> Vector3:
	var pitch_rad: float = deg_to_rad(_active_pitch)
	var yaw_rad: float = deg_to_rad(_active_yaw)
	return Vector3(-sin(pitch_rad) * sin(yaw_rad), cos(pitch_rad), -sin(pitch_rad) * cos(yaw_rad)) * screen_focus_offset


func _clamp_focus(pos: Vector3) -> Vector3:
	if not use_arena_bounds:
		return pos
	var extents: Vector2 = get_camera_ground_extents()
	var min_x: float = bounds_min.x + extents.x
	var max_x: float = bounds_max.x - extents.x
	var min_z: float = bounds_min.y + extents.y
	var max_z: float = bounds_max.y - extents.y
	var x_val: float = (bounds_min.x + bounds_max.x) * 0.5 if min_x > max_x else clampf(pos.x, min_x, max_x)
	var z_val: float = (bounds_min.y + bounds_max.y) * 0.5 if min_z > max_z else clampf(pos.z, min_z, max_z)
	return Vector3(x_val, pos.y, z_val)
