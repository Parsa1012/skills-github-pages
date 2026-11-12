class_name ArenaBot
extends CharacterBody3D
## هوش مصنوعی بات دشمن آفلاین (مدل پهپاد Kenney، گشت‌زنی، خط دید، تیراندازی انرژی و بازگشت).

signal bot_defeated(bot: ArenaBot, attacker_team: int)

enum BotState {
	PATROL,
	ENGAGE,
	RESPAWN
}

@export var team_id: int = 1
@export var profile: ArenaBotProfile
@export var patrol_offset_a: Vector3 = Vector3(0.0, 0.0, -3.2)
@export var patrol_offset_b: Vector3 = Vector3(0.0, 0.0, 3.2)
@export var fire_cooldown: float = 1.05
@export var projectile_speed: float = 16.0
@export var projectile_damage: float = 10.0

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _visual_root: Node3D = $VisualRoot
@onready var _model_pivot: Node3D = $VisualRoot/ModelPivot
@onready var _muzzle_left: Marker3D = $VisualRoot/MuzzleLeft
@onready var _muzzle_right: Marker3D = $VisualRoot/MuzzleRight
@onready var _team_ring: MeshInstance3D = $TeamRingMesh
@onready var _hp_bar_pivot: Node3D = $HpBarPivot
@onready var _hp_bar_fill: MeshInstance3D = $HpBarPivot/HpBarFill

var _state: BotState = BotState.PATROL
var _home_pos: Vector3 = Vector3.ZERO
var _max_hp: float = 100.0
var _hp: float = 100.0
var _patrol_index: int = 0
var _patrol_leg_timer: float = 0.0
var _patrol_stuck_timer: float = 0.0
var _patrol_check_pos: Vector3 = Vector3.ZERO
var _hover_time: float = 0.0
var _los_timer: float = 0.0
var _fire_timer: float = 0.6
var _respawn_timer: float = 0.0
var _has_los: bool = false
var _player_ref: Node3D = null
var _facing_yaw: float = PI * 0.5
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _use_left_muzzle: bool = true
var _gravity: float = 18.0


func _ready() -> void:
	add_to_group("arena_bots")
	_home_pos = global_position
	_patrol_check_pos = _home_pos
	_max_hp = profile.max_shield if profile != null else 100.0
	_hp = _max_hp
	_hover_time = randf() * TAU
	_los_timer = randf() * 0.25
	_strafe_sign = 1.0 if randf() >= 0.5 else -1.0
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	_hover_time += delta * 3.4
	if _model_pivot != null:
		_model_pivot.position.y = 0.52 + sin(_hover_time) * 0.10

	if _state == BotState.RESPAWN:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn_at_home()
		return

	if _player_ref == null or not is_instance_valid(_player_ref):
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_player_ref = players[0] as Node3D

	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = 0.22
		_has_los = _check_player_line_of_sight()

	if _has_los and _player_ref != null:
		_state = BotState.ENGAGE
	else:
		_state = BotState.PATROL

	match _state:
		BotState.PATROL:
			_process_patrol(delta)
		BotState.ENGAGE:
			_process_engage(delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

	move_and_slide()

	if _visual_root != null:
		_visual_root.rotation.y = _facing_yaw


func _process_patrol(delta: float) -> void:
	var offset: Vector3 = patrol_offset_a if _patrol_index == 0 else patrol_offset_b
	var target: Vector3 = _home_pos + offset
	var to_target := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)

	_patrol_leg_timer += delta
	_patrol_stuck_timer += delta
	if _patrol_stuck_timer >= 1.25:
		_patrol_stuck_timer = 0.0
		if global_position.distance_to(_patrol_check_pos) < 0.25:
			_patrol_index = 1 - _patrol_index
			_patrol_leg_timer = 0.0
		_patrol_check_pos = global_position

	if to_target.length() < 0.65 or _patrol_leg_timer >= 5.0:
		_patrol_index = 1 - _patrol_index
		_patrol_leg_timer = 0.0
		return

	var dir: Vector3 = to_target.normalized()
	var spd: float = (profile.move_speed if profile != null else 3.4) * 0.78
	velocity.x = move_toward(velocity.x, dir.x * spd, 14.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, 14.0 * delta)
	_facing_yaw = lerp_angle(_facing_yaw, atan2(-dir.x, -dir.z), clampf(8.0 * delta, 0.0, 1.0))


func _process_engage(delta: float) -> void:
	if _player_ref == null:
		return
	var to_player := Vector3(_player_ref.global_position.x - global_position.x, 0.0, _player_ref.global_position.z - global_position.z)
	var dist: float = to_player.length()
	if dist < 0.01:
		return
	var dir_to_player: Vector3 = to_player / dist
	_facing_yaw = lerp_angle(_facing_yaw, atan2(-dir_to_player.x, -dir_to_player.z), clampf(12.0 * delta, 0.0, 1.0))

	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.1, 2.2)
		_strafe_sign *= -1.0

	var strafe_vec := Vector3(-dir_to_player.z, 0.0, dir_to_player.x) * _strafe_sign
	var radial_factor: float = 0.0
	if dist > 9.8:
		radial_factor = 0.65
	elif dist < 5.6:
		radial_factor = -0.75

	var move_dir: Vector3 = (strafe_vec * 0.75 + dir_to_player * radial_factor)
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
	var spd: float = profile.move_speed if profile != null else 3.4
	velocity.x = move_toward(velocity.x, move_dir.x * spd, 16.0 * delta)
	velocity.z = move_toward(velocity.z, move_dir.z * spd, 16.0 * delta)

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_cooldown
		_fire_energy_bolt(dir_to_player)


func _check_player_line_of_sight() -> bool:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return false
	if _player_ref.has_method("is_alive") and not bool(_player_ref.call("is_alive")):
		return false

	var sight_range: float = profile.sight_range if profile != null else 15.5
	var origin: Vector3 = global_position + Vector3(0.0, 0.95, 0.0)
	var target: Vector3 = _player_ref.global_position + Vector3(0.0, 0.95, 0.0)
	if origin.distance_to(target) > sight_range:
		return false

	var query := PhysicsRayQueryParameters3D.create(origin, target, 1 | 2, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	return hit.get("collider") == _player_ref


func _fire_energy_bolt(aim_dir: Vector3) -> void:
	var muzzle: Marker3D = _muzzle_left if _use_left_muzzle else _muzzle_right
	_use_left_muzzle = not _use_left_muzzle
	var torso_origin := global_position + Vector3(0.0, 0.96, 0.0)
	var spawn_pos: Vector3 = muzzle.global_position if muzzle != null else torso_origin + aim_dir * 0.65

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var pre_query := PhysicsRayQueryParameters3D.create(torso_origin, spawn_pos, 1 | 2, [get_rid()])
	pre_query.collide_with_areas = false
	pre_query.collide_with_bodies = true
	pre_query.hit_from_inside = true
	var pre_hit: Dictionary = space_state.intersect_ray(pre_query)

	var proj_parent: Node = get_tree().current_scene if get_tree() != null else get_parent()
	var bolt_col := Color(0.984314, 0.45098, 0.086275, 1.0)

	if not pre_hit.is_empty():
		var hit_pos: Vector3 = pre_hit.get("position", spawn_pos)
		var collider: Object = pre_hit.get("collider", null)
		if collider != null and collider.has_method("take_damage"):
			var target_team: Variant = collider.get("team_id")
			if target_team == null or int(target_team) != team_id:
				collider.call("take_damage", projectile_damage, team_id)
		var flash: Node = PoolManager.acquire(ImpactFlash.POOL_ID, proj_parent)
		if flash is ImpactFlash:
			(flash as ImpactFlash).trigger(hit_pos, bolt_col)
	else:
		var precision: float = profile.aim_precision if profile != null else 0.72
		var max_err_rad: float = deg_to_rad((1.0 - precision) * 14.0)
		var shoot_dir: Vector3 = aim_dir.rotated(Vector3.UP, randf_range(-max_err_rad, max_err_rad))

		var proj: Node = PoolManager.acquire(EnergyProjectile.POOL_ID, proj_parent)
		if proj is EnergyProjectile:
			(proj as EnergyProjectile).launch(
				spawn_pos,
				shoot_dir,
				projectile_speed,
				projectile_damage,
				team_id,
				self,
				bolt_col
			)
	AudioManager.play_sfx_path("res://assets/kenney/audio/enemy_attack.ogg", randf_range(0.94, 1.06))


func take_damage(amount: float, attacker_team: int) -> void:
	if _state == BotState.RESPAWN or attacker_team == team_id:
		return

	_hp = maxf(_hp - amount, 0.0)
	_update_hp_bar()
	if _hp <= 0.0:
		_enter_respawn(attacker_team)
	else:
		AudioManager.play_sfx_path("res://assets/kenney/audio/enemy_hurt.ogg", randf_range(0.95, 1.08))


func _enter_respawn(attacker_team: int) -> void:
	_state = BotState.RESPAWN
	_respawn_timer = 3.0
	velocity = Vector3.ZERO
	AudioManager.play_sfx_path("res://assets/kenney/audio/enemy_destroy.ogg", randf_range(0.94, 1.04))

	var proj_parent: Node = get_tree().current_scene if get_tree() != null else get_parent()
	var flash: Node = PoolManager.acquire(ImpactFlash.POOL_ID, proj_parent)
	if flash is ImpactFlash:
		(flash as ImpactFlash).trigger(global_position + Vector3(0.0, 0.9, 0.0), Color(0.984314, 0.572549, 0.235294, 1.0))

	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	if _visual_root != null:
		_visual_root.visible = false
	if _team_ring != null:
		_team_ring.visible = false
	if _hp_bar_pivot != null:
		_hp_bar_pivot.visible = false

	bot_defeated.emit(self, attacker_team)


func _find_safe_home_pos() -> Vector3:
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(0.0, 0.0, -1.6),
		Vector3(0.0, 0.0, 1.6),
		Vector3(-1.6, 0.0, 0.0)
	]
	for off in offsets:
		var cand := Vector3(
			clampf(_home_pos.x + off.x, -13.6, 13.6),
			_home_pos.y,
			clampf(_home_pos.z + off.z, -9.6, 9.6)
		)
		if _player_ref == null or not is_instance_valid(_player_ref) or _player_ref.global_position.distance_to(cand) >= 1.4:
			return cand
	return _home_pos


func _respawn_at_home() -> void:
	global_position = _find_safe_home_pos()
	_patrol_check_pos = global_position
	_patrol_leg_timer = 0.0
	_patrol_stuck_timer = 0.0
	velocity = Vector3.ZERO
	_hp = _max_hp
	_has_los = false
	_fire_timer = 0.85
	_state = BotState.PATROL
	_update_hp_bar()

	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", false)
	if _visual_root != null:
		_visual_root.visible = true
	if _team_ring != null:
		_team_ring.visible = true
	if _hp_bar_pivot != null:
		_hp_bar_pivot.visible = true


func _update_hp_bar() -> void:
	if _hp_bar_fill == null:
		return
	var ratio: float = clampf(_hp / maxf(_max_hp, 1.0), 0.0, 1.0)
	_hp_bar_fill.scale.x = maxf(ratio, 0.001)
	_hp_bar_fill.position.x = -(1.0 - ratio) * 0.55
