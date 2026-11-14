class_name ImpactFlash
extends Node3D
## افکت نورانی برخورد گلوله و موج شوک انفجار HDR با قابلیت بازگشت به استخر (PoolManager).

const POOL_ID: StringName = &"impact_flash"

@onready var _mesh: MeshInstance3D = $FlashMesh
@onready var _ring_mesh: MeshInstance3D = $ShockRingMesh

var _timer: float = 0.0
var _duration: float = 0.16
var _start_scale: float = 0.45
var _end_scale: float = 1.45
var _base_color: Color = Color(0.219608, 0.741176, 0.972549, 1.0)
var _mat: StandardMaterial3D = null
var _ring_mat: StandardMaterial3D = null


func _ready() -> void:
	_ensure_material()


func _ensure_material() -> void:
	if _mat == null and _mesh != null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mesh.material_override = _mat
	if _ring_mat == null and _ring_mesh != null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mesh.material_override = _ring_mat


func trigger(world_pos: Vector3, flash_color: Color, end_scale: float = 1.45, duration: float = 0.16) -> void:
	_ensure_material()
	global_position = world_pos
	_timer = 0.0
	_duration = maxf(duration, 0.06)
	_start_scale = maxf(0.35, end_scale * 0.30)
	_end_scale = maxf(0.6, end_scale)
	_base_color = flash_color
	scale = Vector3(_start_scale, _start_scale, _start_scale)
	if _ring_mesh != null:
		_ring_mesh.scale = Vector3(0.45, 0.45, 0.45)
	if _mat != null:
		_mat.albedo_color = Color(flash_color.r * 1.9, flash_color.g * 1.9, flash_color.b * 1.9, 0.95)
	if _ring_mat != null:
		_ring_mat.albedo_color = Color(flash_color.r * 1.6, flash_color.g * 1.6, flash_color.b * 1.6, 0.85)


func _process(delta: float) -> void:
	_timer += delta
	var t: float = clampf(_timer / _duration, 0.0, 1.0)
	var ease_out: float = 1.0 - pow(1.0 - t, 2.0)
	var s: float = lerpf(_start_scale, _end_scale, ease_out)
	scale = Vector3(s, s, s)
	if _ring_mesh != null:
		var rs: float = lerpf(0.55, 2.05, ease_out)
		_ring_mesh.scale = Vector3(rs, 1.0, rs)
	if _mat != null:
		_mat.albedo_color = Color(_base_color.r * 1.9, _base_color.g * 1.9, _base_color.b * 1.9, (1.0 - t) * 0.95)
	if _ring_mat != null:
		_ring_mat.albedo_color = Color(_base_color.r * 1.6, _base_color.g * 1.6, _base_color.b * 1.6, (1.0 - t) * 0.82)
	if _timer >= _duration:
		PoolManager.release(POOL_ID, self)
