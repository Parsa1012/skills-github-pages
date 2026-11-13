class_name EnergyProjectile
extends Node3D
## گلوله انرژی استخری (Pooled) با رهگیری پیوسته RayCast، عبور از جهش، نفوذ ریل‌گان و بازخورد اصابت.

const POOL_ID: StringName = &"energy_projectile"
const IMPACT_POOL_ID: StringName = &"impact_flash"

@onready var _bolt_mesh: MeshInstance3D = $BoltMesh

var _origin_pos: Vector3 = Vector3.ZERO
var _direction: Vector3 = Vector3.FORWARD
var _speed: float = 26.0
var _damage: float = 25.0
var _team_id: int = 0
var _exclude_rids: Array[RID] = []
var _color: Color = Color(0.219608, 0.741176, 0.972549, 1.0)
var _age: float = 0.0
var _max_lifetime: float = 1.35
var _active: bool = false
var _pierce_left: int = 0
var _shooter_is_player: bool = false
var _outer_mat: StandardMaterial3D = null


func _ready() -> void:
	_ensure_material()


func _ensure_material() -> void:
	if _outer_mat == null and _bolt_mesh != null:
		_outer_mat = StandardMaterial3D.new()
		_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_bolt_mesh.material_override = _outer_mat


func launch(
	origin: Vector3,
	direction: Vector3,
	speed: float,
	damage: float,
	team_id: int,
	shooter: CollisionObject3D,
	bolt_color: Color,
	bolt_scale: Vector3 = Vector3.ONE,
	pierce_count: int = 0,
	shooter_is_player: bool = false
) -> void:
	_ensure_material()
	global_position = origin
	_origin_pos = origin
	var flat_dir := Vector3(direction.x, direction.y * 0.25, direction.z)
	if flat_dir.length_squared() < 0.0001:
		flat_dir = Vector3.FORWARD
	_direction = flat_dir.normalized()
	_speed = maxf(speed, 4.0)
	_damage = maxf(damage, 1.0)
	_team_id = team_id
	_color = bolt_color
	_age = 0.0
	_active = true
	_pierce_left = maxi(0, pierce_count)
	_shooter_is_player = shooter_is_player
	scale = bolt_scale

	_exclude_rids.clear()
	if shooter != null and is_instance_valid(shooter):
		_exclude_rids.append(shooter.get_rid())

	rotation.y = atan2(-_direction.x, -_direction.z)
	if _outer_mat != null:
		_outer_mat.albedo_color = Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.90)


func _physics_process(delta: float) -> void:
	if not _active:
		return

	_age += delta
	if _age >= _max_lifetime:
		_recycle()
		return

	var start_pos: Vector3 = global_position
	var end_pos: Vector3 = start_pos + _direction * (_speed * delta)

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(start_pos, end_pos, 1 | 2, _exclude_rids)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true

	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_pos: Vector3 = hit.get("position", end_pos)
		var collider: Object = hit.get("collider", null)

		# Pass cleanly through a dashing player with i-frames
		if collider is PlayerController and (collider as PlayerController).is_dashing():
			_exclude_rids.append((collider as CollisionObject3D).get_rid())
			global_position = hit_pos + _direction * 0.18
			return

		var hit_damageable: bool = false
		if collider != null and collider.has_method("take_damage"):
			var target_team: Variant = collider.get("team_id")
			if target_team == null or int(target_team) != _team_id:
				hit_damageable = true
				if collider is ArenaBot or collider is ExplosiveCrate:
					collider.call("take_damage", _damage, _team_id, _shooter_is_player)
				elif collider is PlayerController:
					collider.call("take_damage", _damage, _team_id, _origin_pos)
				else:
					collider.call("take_damage", _damage, _team_id)

				if _shooter_is_player:
					var killed: bool = collider.has_method("is_alive") and not bool(collider.call("is_alive"))
					AudioManager.play_hitmarker_sfx(killed)
					EventBus.enemy_hit_confirmed.emit(_damage, killed)

		_spawn_impact(hit_pos)
		if hit_damageable and _pierce_left > 0 and collider is CollisionObject3D:
			_pierce_left -= 1
			_exclude_rids.append((collider as CollisionObject3D).get_rid())
			global_position = hit_pos + _direction * 0.18
			return

		_recycle()
		return

	global_position = end_pos


func _spawn_impact(world_pos: Vector3) -> void:
	var target_parent: Node = get_tree().current_scene if get_tree() != null else get_parent()
	var flash: Node = PoolManager.acquire(IMPACT_POOL_ID, target_parent)
	if flash is ImpactFlash:
		(flash as ImpactFlash).trigger(world_pos, _color)


func _recycle() -> void:
	_active = false
	scale = Vector3.ONE
	PoolManager.release(POOL_ID, self)
