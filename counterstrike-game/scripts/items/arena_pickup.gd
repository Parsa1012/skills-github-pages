class_name ArenaPickup
extends Area3D
## آیتم تعاملی زمین نبرد (بسته جان/سپر، تقویت‌کننده انرژی و شتاب‌دهنده حرکت).

enum PickupType {
	MEDKIT,
	OVERCHARGE,
	SPEED_BOOST
}

@export var pickup_type: PickupType = PickupType.MEDKIT
@export var respawn_seconds: float = 14.0
@export var pickup_value: float = 35.0

@onready var _visual_pivot: Node3D = $VisualPivot
@onready var _core_mesh: MeshInstance3D = $VisualPivot/PickupCoreMesh
@onready var _cross_mesh: MeshInstance3D = $VisualPivot/CrossBarMesh
@onready var _ammo_model: Node3D = $VisualPivot/AmmoCrateModel
@onready var _pad_mesh: MeshInstance3D = $PadRingMesh

var _available: bool = true
var _respawn_timer: float = 0.0
var _spin_time: float = 0.0
var _accent_color: Color = Color(0.062745, 0.72549, 0.505882, 1.0)
var _core_mat: StandardMaterial3D = null
var _pad_mat: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("arena_pickups")
	collision_layer = 8
	collision_mask = 2
	_spin_time = randf() * TAU
	_configure_visuals()
	body_entered.connect(_on_body_entered)


func is_available() -> bool:
	return _available


func _configure_visuals() -> void:
	match pickup_type:
		PickupType.MEDKIT:
			_accent_color = Color(0.062745, 0.72549, 0.505882, 1.0)
			if _cross_mesh != null:
				_cross_mesh.visible = true
			if _core_mesh != null:
				_core_mesh.visible = true
			if _ammo_model != null:
				_ammo_model.visible = false
		PickupType.OVERCHARGE:
			_accent_color = Color(0.960784, 0.619608, 0.043137, 1.0)
			if _cross_mesh != null:
				_cross_mesh.visible = false
			if _core_mesh != null:
				_core_mesh.visible = (_ammo_model == null)
			if _ammo_model != null:
				_ammo_model.visible = true
		PickupType.SPEED_BOOST:
			_accent_color = Color(0.658824, 0.333333, 0.968627, 1.0)
			if _cross_mesh != null:
				_cross_mesh.visible = false
			if _core_mesh != null:
				_core_mesh.visible = true
				_core_mesh.rotation_degrees = Vector3(0.0, 45.0, 45.0)
			if _ammo_model != null:
				_ammo_model.visible = false

	_core_mat = VisualFxUtils.make_emissive_pbr_material(_accent_color, _accent_color, 1.85, 0.45, 0.28)
	if _core_mesh != null:
		_core_mesh.material_override = _core_mat
	if _cross_mesh != null:
		_cross_mesh.material_override = _core_mat

	_pad_mat = VisualFxUtils.make_unshaded_hdr_material(_accent_color, 0.68, 1.55)
	if _pad_mesh != null:
		_pad_mesh.material_override = _pad_mat


func _process(delta: float) -> void:
	if _available:
		_spin_time += delta
		if _visual_pivot != null:
			_visual_pivot.rotation.y = _spin_time * 1.9
			_visual_pivot.position.y = 0.48 + sin(_spin_time * 3.2) * 0.11
	else:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn_item()


func _respawn_item() -> void:
	_available = true
	if _visual_pivot != null:
		_visual_pivot.visible = true
	if _pad_mat != null:
		_pad_mat.albedo_color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.65)
	for body in get_overlapping_bodies():
		if body is Node3D and _try_grant_to(body as Node3D):
			break


func _on_body_entered(body: Node3D) -> void:
	if not _available or body == null:
		return
	_try_grant_to(body)


func _try_grant_to(unit: Node3D) -> bool:
	if not _available or unit == null or not is_instance_valid(unit):
		return false
	if unit.has_method("is_alive") and not bool(unit.call("is_alive")):
		return false
	if not unit.has_method("apply_pickup"):
		return false

	var accepted: bool = bool(unit.call("apply_pickup", int(pickup_type), pickup_value))
	if not accepted:
		return false

	_available = false
	_respawn_timer = respawn_seconds
	if _visual_pivot != null:
		_visual_pivot.visible = false
	if _pad_mat != null:
		_pad_mat.albedo_color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.16)

	AudioManager.play_pickup_sfx()
	if unit.is_in_group("player"):
		var label_fa: String = "بسته سپر و جان (+%d)" % int(pickup_value)
		if pickup_type == PickupType.OVERCHARGE:
			label_fa = "تقویت انرژی پلاسما (%d ثانیه)!" % int(pickup_value)
		elif pickup_type == PickupType.SPEED_BOOST:
			label_fa = "شتاب‌دهنده حرکت (%d ثانیه)!" % int(pickup_value)
		EventBus.hud_toast_requested.emit(label_fa, _accent_color)

	return true
