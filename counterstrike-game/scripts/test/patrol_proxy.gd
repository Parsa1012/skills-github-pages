extends Node3D
## Simple Phase 1 test proxy for evaluating BombSquad-style smooth camera follow.
## Note: Not a Phase 2 gameplay controller (no touch sticks, combat, or physics gameplay).

@export var auto_patrol: bool = true
@export var move_speed: float = 4.6

@onready var _visual_body: Node3D = $VisualBody

var _patrol_time: float = 0.0


func _process(delta: float) -> void:
	var manual_dir: Vector3 = _get_optional_keyboard_preview()
	if manual_dir.length_squared() > 0.01:
		var prev_pos: Vector3 = global_position
		global_position += manual_dir.normalized() * move_speed * delta
		global_position.x = clampf(global_position.x, -11.5, 11.5)
		global_position.z = clampf(global_position.z, -7.5, 7.5)
		_face_direction(global_position - prev_pos, delta)
		return

	if not auto_patrol:
		return

	_patrol_time += delta * 0.55
	var next_pos := Vector3(
		sin(_patrol_time) * 8.2,
		0.0,
		sin(_patrol_time * 2.0) * 4.4
	)
	var motion: Vector3 = next_pos - global_position
	global_position = next_pos
	_face_direction(motion, delta)


func _face_direction(motion: Vector3, delta: float) -> void:
	if _visual_body == null:
		return
	var flat := Vector3(motion.x, 0.0, motion.z)
	if flat.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(-flat.x, -flat.z)
	_visual_body.rotation.y = lerp_angle(_visual_body.rotation.y, target_yaw, minf(10.0 * delta, 1.0))


func _get_optional_keyboard_preview() -> Vector3:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	return dir
