class_name ImpactFlash
extends Node3D
## افکت نورانی برخورد گلوله انرژی و موج انفجار با قابلیت بازگشت به استخر (PoolManager).

const POOL_ID: StringName = &"impact_flash"

@onready var _mesh: MeshInstance3D = $FlashMesh

var _timer: float = 0.0
var _duration: float = 0.16
var _start_scale: float = 0.45
var _end_scale: float = 1.45
var _mat: StandardMaterial3D = null


func _ready() -> void:
	_ensure_material()


func _ensure_material() -> void:
	if _mat == null and _mesh != null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mesh.material_override = _mat


func trigger(world_pos: Vector3, flash_color: Color, end_scale: float = 1.45, duration: float = 0.16) -> void:
	_ensure_material()
	global_position = world_pos
	_timer = 0.0
	_duration = maxf(duration, 0.06)
	_start_scale = maxf(0.35, end_scale * 0.30)
	_end_scale = maxf(0.6, end_scale)
	scale = Vector3(_start_scale, _start_scale, _start_scale)
	if _mat != null:
		_mat.albedo_color = Color(flash_color.r, flash_color.g, flash_color.b, 0.95)


func _process(delta: float) -> void:
	_timer += delta
	var t: float = clampf(_timer / _duration, 0.0, 1.0)
	var s: float = lerpf(_start_scale, _end_scale, t)
	scale = Vector3(s, s, s)
	if _mat != null:
		var c: Color = _mat.albedo_color
		c.a = (1.0 - t) * 0.95
		_mat.albedo_color = c
	if _timer >= _duration:
		PoolManager.release(POOL_ID, self)
