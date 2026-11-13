class_name PulseBomb
extends Node3D
## بمب پالس تاکتیکی استخری (Pooled) با پرتاب سهموی، رانش انفجاری، اعداد آسیب و آگاهی تاکتیکی بات‌ها.

const POOL_ID: StringName = &"pulse_bomb"

@onready var _core_mesh: MeshInstance3D = $CoreMesh
@onready var _halo_mesh: MeshInstance3D = $HaloMesh

var _vel: Vector3 = Vector3.ZERO
var _gravity: float = 16.5
var _team_id: int = 0
var _shooter_is_player: bool = false
var _exclude_rids: Array[RID] = []
var _fuse_timer: float = 1.05
var _max_damage: float = 58.0
var _blast_radius: float = 3.55
var _active: bool = false
var _pulse_time: float = 0.0
var _core_mat: StandardMaterial3D = null
var _halo_mat: StandardMaterial3D = null


func _ready() -> void:
	_ensure_materials()


func _exit_tree() -> void:
	if is_in_group("pulse_bombs"):
		remove_from_group("pulse_bombs")


func _ensure_materials() -> void:
	if _core_mat == null and _core_mesh != null:
		_core_mat = StandardMaterial3D.new()
		_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_mat.albedo_color = Color(0.984314, 0.74902, 0.141176, 1.0)
		_core_mesh.material_override = _core_mat
	if _halo_mat == null and _halo_mesh != null:
		_halo_mat = StandardMaterial3D.new()
		_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_halo_mat.albedo_color = Color(0.219608, 0.741176, 0.972549, 0.55)
		_halo_mesh.material_override = _halo_mat


func launch(
	origin: Vector3,
	forward_dir: Vector3,
	team_id: int,
	shooter: CollisionObject3D,
	shooter_is_player: bool = true,
	damage_mult: float = 1.0
) -> void:
	_ensure_materials()
	global_position = origin
	var flat := Vector3(forward_dir.x, 0.0, forward_dir.z)
	if flat.length_squared() < 0.001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	_vel = flat * 11.4 + Vector3(0.0, 5.2, 0.0)
	_team_id = team_id
	_shooter_is_player = shooter_is_player
	_fuse_timer = 1.05
	_max_damage = 58.0 * maxf(damage_mult, 0.5)
	_pulse_time = 0.0
	_active = true
	scale = Vector3.ONE
	if not is_in_group("pulse_bombs"):
		add_to_group("pulse_bombs")

	_exclude_rids.clear()
	if shooter != null and is_instance_valid(shooter):
		_exclude_rids.append(shooter.get_rid())


func _physics_process(delta: float) -> void:
	if not _active:
		return

	_fuse_timer -= delta
	_pulse_time += delta * 18.0
	if _core_mat != null:
		var blink: float = 0.5 + 0.5 * sin(_pulse_time)
		_core_mat.albedo_color = Color(0.984314, 0.74902, 0.141176, 1.0).lerp(Color(0.98, 0.30, 0.25, 1.0), blink)
	if _halo_mesh != null:
		var hs: float = 1.0 + 0.22 * sin(_pulse_time)
		_halo_mesh.scale = Vector3(hs, hs, hs)

	_vel.y -= _gravity * delta
	var start_pos: Vector3 = global_position
	var next_pos: Vector3 = start_pos + _vel * delta

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(start_pos, next_pos, 1 | 2, _exclude_rids)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = space_state.intersect_ray(query)

	if not hit.is_empty():
		var collider: Object = hit.get("collider", null)
		var hit_pos: Vector3 = hit.get("position", next_pos)
		var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
		if collider != null and collider.has_method("take_damage"):
			var tid: Variant = collider.get("team_id")
			if tid == null or int(tid) != _team_id:
				global_position = hit_pos
				detonate()
				return
		global_position = hit_pos + hit_normal * 0.16
		_vel = _vel.bounce(hit_normal) * 0.55
	else:
		global_position = next_pos

	if global_position.y <= 0.18:
		global_position.y = 0.18
		if _vel.y < -0.5:
			_vel.y = absf(_vel.y) * 0.42
			_vel.x *= 0.72
			_vel.z *= 0.72
		else:
			_vel.y = 0.0
			_vel.x = move_toward(_vel.x, 0.0, 9.0 * delta)
			_vel.z = move_toward(_vel.z, 0.0, 9.0 * delta)

	if _fuse_timer <= 0.0:
		detonate()


func detonate() -> void:
	if not _active:
		return
	_active = false
	if is_in_group("pulse_bombs"):
		remove_from_group("pulse_bombs")
	var blast_center: Vector3 = global_position
	var any_enemy_hit: bool = false
	var any_kill: bool = false

	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("arena_bots"))
	targets.append_array(get_tree().get_nodes_in_group("player"))
	targets.append_array(get_tree().get_nodes_in_group("explosive_crates"))

	for node in targets:
		if node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		var unit := node as Node3D
		if unit.has_method("is_alive") and not bool(unit.call("is_alive")):
			continue
		var tid: Variant = unit.get("team_id")
		if tid != null and int(tid) == _team_id:
			continue
		var delta_xz := Vector3(unit.global_position.x - blast_center.x, 0.0, unit.global_position.z - blast_center.z)
		var dist: float = delta_xz.length()
		if dist > _blast_radius:
			continue
		var ratio: float = clampf(dist / _blast_radius, 0.0, 1.0)
		var falloff: float = lerpf(1.0, 0.48, ratio)
		var dmg: float = _max_damage * falloff

		if unit is ArenaBot:
			var bot := unit as ArenaBot
			bot.take_damage(dmg, _team_id, _shooter_is_player)
			var push_dir: Vector3 = delta_xz.normalized() if dist > 0.05 else Vector3.FORWARD
			bot.apply_knockback(push_dir * lerpf(9.6, 4.2, ratio))
		elif unit is ExplosiveCrate:
			(unit as ExplosiveCrate).take_damage(dmg, _team_id, _shooter_is_player)
		elif unit is PlayerController:
			var p := unit as PlayerController
			p.take_damage(dmg, _team_id, blast_center)
			var push_dir_p: Vector3 = delta_xz.normalized() if dist > 0.05 else Vector3.FORWARD
			p.apply_knockback(push_dir_p * lerpf(8.0, 3.2, ratio))
		elif unit.has_method("take_damage"):
			unit.call("take_damage", dmg, _team_id)

		if unit is ArenaBot or unit is PlayerController:
			any_enemy_hit = true
			var killed_now: bool = unit.has_method("is_alive") and not bool(unit.call("is_alive"))
			if killed_now:
				any_kill = true
			if _shooter_is_player and unit is ArenaBot:
				EventBus.combat_callout_requested.emit(unit.global_position + Vector3(0.0, 1.3, 0.0), "-%d" % int(round(dmg)), Color(0.984314, 0.74902, 0.141176, 1.0), 1.30)
				if killed_now:
					EventBus.combat_callout_requested.emit(unit.global_position + Vector3(0.0, 1.85, 0.0), "+حذف!", Color(0.219608, 0.741176, 0.972549, 1.0), 1.38)

	AudioManager.play_bomb_explode_sfx()
	EventBus.camera_trauma_requested.emit(0.36)
	if _shooter_is_player and any_enemy_hit:
		AudioManager.play_hitmarker_sfx(any_kill)
		EventBus.enemy_hit_confirmed.emit(_max_damage, any_kill)

	var target_parent: Node = get_tree().current_scene if get_tree() != null else get_parent()
	var flash: Node = PoolManager.acquire(ImpactFlash.POOL_ID, target_parent)
	if flash is ImpactFlash:
		(flash as ImpactFlash).trigger(blast_center + Vector3(0.0, 0.35, 0.0), Color(0.984314, 0.74902, 0.141176, 1.0), 3.6, 0.24)

	scale = Vector3.ONE
	PoolManager.release(POOL_ID, self)
