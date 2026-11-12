class_name PlayerController
extends CharacterBody3D
## کنترلر سه‌بعدی بازیکن در نمای 2.5D BombSquad (حرکت نرم، چرخش مستقل نشانه، سازگار با مدل‌های Kenney).

@export var walk_speed: float = 3.8
@export var run_speed: float = 6.4
@export var acceleration: float = 28.0
@export var deceleration: float = 34.0
@export var turn_speed: float = 16.0
@export var camera_rig_path: NodePath
@export var touch_hud_path: NodePath
@export var kenney_character_scene: PackedScene

@onready var _visual_root: Node3D = $VisualRoot
@onready var _procedural_rig: Node3D = $VisualRoot/ProceduralRig
@onready var _left_leg: Node3D = $VisualRoot/ProceduralRig/LeftLegPivot
@onready var _right_leg: Node3D = $VisualRoot/ProceduralRig/RightLegPivot
@onready var _weapon_arm: Node3D = $VisualRoot/ProceduralRig/WeaponArmPivot
@onready var _muzzle_tip: MeshInstance3D = $VisualRoot/ProceduralRig/WeaponArmPivot/MuzzleTip
@onready var _aim_indicator: Node3D = $AimIndicatorPivot
@onready var _aim_beam: MeshInstance3D = $AimIndicatorPivot/AimBeamMesh
@onready var _aim_tip: MeshInstance3D = $AimIndicatorPivot/AimTipMesh

var _gravity: float = 18.0
var _camera_rig: Node3D = null
var _touch_hud: Node = null
var _walk_cycle: float = 0.0
var _fire_pulse_timer: float = 0.0
var _aim_beam_mat: StandardMaterial3D = null
var _muzzle_mat: StandardMaterial3D = null
var _facing_yaw: float = 0.0
var _kenney_instance: Node3D = null


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	if _gravity < 9.8:
		_gravity = 18.0

	_resolve_references()
	_setup_materials()
	_apply_kenney_override_if_present()


func _resolve_references() -> void:
	if not camera_rig_path.is_empty() and has_node(camera_rig_path):
		_camera_rig = get_node(camera_rig_path) as Node3D
	if not touch_hud_path.is_empty() and has_node(touch_hud_path):
		_touch_hud = get_node(touch_hud_path)


func _setup_materials() -> void:
	if _aim_beam != null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.219608, 0.741176, 0.972549, 0.55)
		_aim_beam.material_override = mat
		if _aim_tip != null:
			_aim_tip.material_override = mat
		_aim_beam_mat = mat

	if _muzzle_tip != null:
		var m_mat := StandardMaterial3D.new()
		m_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m_mat.albedo_color = Color(0.219608, 0.741176, 0.972549, 1.0)
		_muzzle_tip.material_override = m_mat
		_muzzle_mat = m_mat


func _apply_kenney_override_if_present() -> void:
	if kenney_character_scene == null or _visual_root == null:
		return
	var instance: Node = kenney_character_scene.instantiate()
	if instance is Node3D:
		_kenney_instance = instance as Node3D
		_visual_root.add_child(_kenney_instance)
		if _procedural_rig != null:
			_procedural_rig.visible = false


func _physics_process(delta: float) -> void:
	var move_2d: Vector2 = _read_move_input()
	var aim_2d: Vector2 = _read_aim_input()
	var fire_active: bool = _read_fire_input()

	var cam_yaw_rad: float = _get_camera_yaw_radians()
	var move_world: Vector3 = _stick_to_world_dir(move_2d, cam_yaw_rad)
	var aim_world: Vector3 = _stick_to_world_dir(aim_2d, cam_yaw_rad)

	var move_mag: float = clampf(move_2d.length(), 0.0, 1.0)
	var target_speed: float = 0.0
	if move_mag > 0.01:
		target_speed = lerpf(walk_speed, run_speed, clampf((move_mag - 0.15) / 0.85, 0.0, 1.0))

	var desired_vel_xz: Vector3 = move_world * target_speed
	var current_vel_xz := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float = acceleration if desired_vel_xz.length_squared() > 0.01 else deceleration
	current_vel_xz = current_vel_xz.move_toward(desired_vel_xz, rate * delta)

	velocity.x = current_vel_xz.x
	velocity.z = current_vel_xz.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

	move_and_slide()

	_update_facing_and_aim(move_world, aim_world, move_2d.length(), aim_2d.length(), fire_active, delta)
	_update_procedural_animation(current_vel_xz.length(), fire_active, delta)


func _read_move_input() -> Vector2:
	var vec: Vector2 = Vector2.ZERO
	if _touch_hud != null and _touch_hud.has_method("get_move_vector"):
		vec = _touch_hud.call("get_move_vector")
	if vec.length_squared() < 0.001:
		var kb := Vector2(
			float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
		)
		if kb.length_squared() > 1.0:
			kb = kb.normalized()
		vec = kb
	return vec


func _read_aim_input() -> Vector2:
	if _touch_hud != null and _touch_hud.has_method("get_aim_vector"):
		return _touch_hud.call("get_aim_vector")
	return Vector2.ZERO


func _read_fire_input() -> bool:
	if _touch_hud != null and _touch_hud.has_method("is_fire_active"):
		if bool(_touch_hud.call("is_fire_active")):
			return true
	return Input.is_key_pressed(KEY_SPACE)


func _get_camera_yaw_radians() -> float:
	if _camera_rig != null and is_instance_valid(_camera_rig):
		var yaw_pivot: Node3D = _camera_rig.get_node_or_null("CameraYawPivot") as Node3D
		if yaw_pivot != null:
			return yaw_pivot.global_rotation.y
	return 0.0


func _stick_to_world_dir(stick: Vector2, yaw_rad: float) -> Vector3:
	if stick.length_squared() < 0.0001:
		return Vector3.ZERO
	var dir := Vector3(stick.x, 0.0, stick.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir.rotated(Vector3.UP, yaw_rad)


func _update_facing_and_aim(move_world: Vector3, aim_world: Vector3, move_len: float, aim_len: float, fire_active: bool, delta: float) -> void:
	var has_aim: bool = aim_len > 0.10 and aim_world.length_squared() > 0.001
	var has_move: bool = move_len > 0.10 and move_world.length_squared() > 0.001

	var target_dir: Vector3 = Vector3.ZERO
	if has_aim:
		target_dir = aim_world.normalized()
	elif has_move:
		target_dir = move_world.normalized()

	if target_dir.length_squared() > 0.001:
		var target_yaw: float = atan2(-target_dir.x, -target_dir.z)
		var turn_blend: float = clampf(turn_speed * delta, 0.0, 1.0)
		_facing_yaw = lerp_angle(_facing_yaw, target_yaw, turn_blend)

	if _visual_root != null:
		_visual_root.rotation.y = _facing_yaw
	if _aim_indicator != null:
		_aim_indicator.rotation.y = _facing_yaw
		var show_beam: bool = has_aim or fire_active
		if _aim_beam != null:
			_aim_beam.visible = show_beam
		if _aim_tip != null:
			_aim_tip.visible = show_beam or has_move

	if _aim_beam_mat != null:
		_aim_beam_mat.albedo_color = Color(0.984314, 0.45098, 0.086275, 0.85) if fire_active else Color(0.219608, 0.741176, 0.972549, 0.58)
	if _muzzle_mat != null:
		_muzzle_mat.albedo_color = Color(0.984314, 0.572549, 0.235294, 1.0) if fire_active else Color(0.219608, 0.741176, 0.972549, 1.0)


func _update_procedural_animation(horiz_speed: float, fire_active: bool, delta: float) -> void:
	if _procedural_rig == null or not _procedural_rig.visible:
		return

	if horiz_speed > 0.25:
		_walk_cycle += horiz_speed * delta * 2.2
		var swing: float = sin(_walk_cycle) * minf(horiz_speed / run_speed, 1.0) * 0.52
		if _left_leg != null:
			_left_leg.rotation.x = swing
		if _right_leg != null:
			_right_leg.rotation.x = -swing
		_procedural_rig.position.y = absf(cos(_walk_cycle)) * 0.06
	else:
		if _left_leg != null:
			_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, clampf(12.0 * delta, 0.0, 1.0))
		if _right_leg != null:
			_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, clampf(12.0 * delta, 0.0, 1.0))
		_procedural_rig.position.y = lerpf(_procedural_rig.position.y, 0.0, clampf(12.0 * delta, 0.0, 1.0))

	if _weapon_arm != null:
		if fire_active:
			_fire_pulse_timer += delta * 18.0
			_weapon_arm.position.z = -0.18 + absf(sin(_fire_pulse_timer)) * 0.06
		else:
			_fire_pulse_timer = 0.0
			_weapon_arm.position.z = lerpf(_weapon_arm.position.z, -0.18, clampf(14.0 * delta, 0.0, 1.0))
