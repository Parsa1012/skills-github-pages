class_name ArenaBot
extends CharacterBody3D
## هوش مصنوعی بات تاکتیکی تیمی (پشتیبانی از تیم آبی/نارنجی، تصرف مناطق، خط دید و بازگشت).

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
@export var hover_bob_enabled: bool = true

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
var _zone_seek_pause_timer: float = 0.0
var _hover_time: float = 0.0
var _los_timer: float = 0.0
var _fire_timer: float = 0.6
var _respawn_timer: float = 0.0
var _has_los: bool = false
var _target_ref: Node3D = null
var _facing_yaw: float = PI * 0.5
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _use_left_muzzle: bool = true
var _gravity: float = 18.0
var _anim_player: AnimationPlayer = null
var _hp_bar_mat: StandardMaterial3D = null
var _base_hp_col: Color = Color(0.984314, 0.45098, 0.086275, 1.0)
var _hit_flash_timer: float = 0.0
var _damage_boost_timer: float = 0.0
var _speed_boost_timer: float = 0.0
var _base_pivot_scale: Vector3 = Vector3.ONE
var _last_attacker_is_player: bool = false
var _knockback_vel: Vector3 = Vector3.ZERO
var _move_vel: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("arena_bots")
	_home_pos = global_position
	_patrol_check_pos = _home_pos
	_max_hp = profile.max_shield if profile != null else 100.0
	_hp = _max_hp
	_hover_time = randf() * TAU
	_los_timer = randf() * 0.25
	_strafe_sign = 1.0 if randf() >= 0.5 else -1.0
	_facing_yaw = -PI * 0.5 if team_id == 0 else PI * 0.5
	_setup_team_visuals()
	_setup_model_animations()
	_update_hp_bar()


func is_alive() -> bool:
	return _state != BotState.RESPAWN


func was_last_hit_by_player() -> bool:
	return _last_attacker_is_player


func apply_knockback(impulse: Vector3) -> void:
	if _state == BotState.RESPAWN:
		return
	var flat := Vector3(impulse.x, 0.0, impulse.z)
	_knockback_vel += flat
	if _knockback_vel.length() > 13.5:
		_knockback_vel = _knockback_vel.normalized() * 13.5


func _setup_team_visuals() -> void:
	var is_heavy: bool = (profile != null and profile.profile_id == &"heavy_sentinel")
	var is_scout: bool = (profile != null and profile.profile_id == &"scout_drone")

	var ring_col := Color(0.219608, 0.741176, 0.972549, 0.65) if team_id == 0 else Color(0.984314, 0.45098, 0.086275, 0.62)
	var hp_col := Color(0.219608, 0.741176, 0.972549, 1.0) if team_id == 0 else Color(0.984314, 0.45098, 0.086275, 1.0)
	if is_heavy:
		ring_col = Color(0.937255, 0.266667, 0.266667, 0.75)
		hp_col = Color(0.937255, 0.266667, 0.266667, 1.0)
	elif is_scout:
		hp_col = Color(0.984314, 0.74902, 0.141176, 1.0)
	_base_hp_col = hp_col

	if _model_pivot != null:
		var scale_mult: float = 1.28 if is_heavy else (0.86 if is_scout else 1.0)
		_base_pivot_scale = Vector3(scale_mult, scale_mult, scale_mult)
		_model_pivot.scale = _base_pivot_scale

	if _team_ring != null:
		if is_heavy:
			_team_ring.scale = Vector3(1.25, 1.0, 1.25)
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.albedo_color = ring_col
		_team_ring.material_override = rmat

	if _hp_bar_pivot != null and is_heavy:
		_hp_bar_pivot.position.y = 2.42

	if _hp_bar_fill != null:
		_hp_bar_mat = StandardMaterial3D.new()
		_hp_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hp_bar_mat.albedo_color = hp_col
		_hp_bar_fill.material_override = _hp_bar_mat


func _setup_model_animations() -> void:
	if _model_pivot == null:
		return
	_anim_player = _model_pivot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		return
	for anim_name in ["idle", "walk"]:
		if _anim_player.has_animation(anim_name):
			var anim: Animation = _anim_player.get_animation(anim_name)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
	if _anim_player.has_animation("idle"):
		_anim_player.play("idle")


func _physics_process(delta: float) -> void:
	if hover_bob_enabled and _model_pivot != null:
		_hover_time += delta * 3.4
		_model_pivot.position.y = 0.52 + sin(_hover_time) * 0.10

	if _state == BotState.RESPAWN:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn_at_home()
		return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		if _model_pivot != null:
			_model_pivot.scale = _base_pivot_scale * (1.10 if _hit_flash_timer > 0.0 else 1.0)
		if _hp_bar_mat != null:
			_hp_bar_mat.albedo_color = Color(1.0, 0.95, 0.8, 1.0) if _hit_flash_timer > 0.0 else _base_hp_col

	if _damage_boost_timer > 0.0:
		_damage_boost_timer = maxf(0.0, _damage_boost_timer - delta)
	if _speed_boost_timer > 0.0:
		_speed_boost_timer = maxf(0.0, _speed_boost_timer - delta)

	if _zone_seek_pause_timer > 0.0:
		_zone_seek_pause_timer = maxf(0.0, _zone_seek_pause_timer - delta)

	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = 0.24
		_target_ref = _find_best_visible_target()
		_has_los = (_target_ref != null)

	if _has_los and _target_ref != null and is_instance_valid(_target_ref):
		_state = BotState.ENGAGE
	else:
		_state = BotState.PATROL

	match _state:
		BotState.PATROL:
			_process_patrol(delta)
		BotState.ENGAGE:
			_process_engage(delta)

	var evade: Vector3 = _compute_danger_evasion()
	if evade.length_squared() > 0.01:
		_move_vel.x = move_toward(_move_vel.x, evade.x * 4.8, 22.0 * delta)
		_move_vel.y = move_toward(_move_vel.y, evade.z * 4.8, 22.0 * delta)

	_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, 16.0 * delta)
	velocity.x = _move_vel.x + _knockback_vel.x
	velocity.z = _move_vel.y + _knockback_vel.z

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

	move_and_slide()

	if _visual_root != null:
		_visual_root.rotation.y = _facing_yaw
	_update_walk_animation()


func _update_walk_animation() -> void:
	if _anim_player == null:
		return
	var horiz_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	if horiz_speed > 0.45 and _anim_player.has_animation("walk"):
		if _anim_player.current_animation != "walk":
			_anim_player.play("walk", 0.12)
		_anim_player.speed_scale = clampf(horiz_speed / 3.5, 0.7, 1.35)
	elif _anim_player.has_animation("idle"):
		if _anim_player.current_animation != "idle":
			_anim_player.play("idle", 0.14)
		_anim_player.speed_scale = 1.0


func _pick_objective_target() -> Vector3:
	if _hp < _max_hp * 0.50:
		var best_med: Node3D = null
		var best_med_dist: float = 9.0
		for p in get_tree().get_nodes_in_group("arena_pickups"):
			if p is ArenaPickup:
				var pk := p as ArenaPickup
				if pk.pickup_type == ArenaPickup.PickupType.MEDKIT and pk.is_available():
					var d: float = global_position.distance_to(pk.global_position)
					if d < best_med_dist:
						best_med_dist = d
						best_med = pk
		if best_med != null:
			return Vector3(best_med.global_position.x, global_position.y, best_med.global_position.z)

	var focus: float = profile.zone_objective_focus if profile != null else 0.0
	var mode_cfg: ArenaModeConfig = GameManager.get_active_mode_config()
	var zones_enabled: bool = (mode_cfg == null or mode_cfg.enable_capture_zones)
	if focus >= 0.6 and _zone_seek_pause_timer <= 0.0 and zones_enabled:
		var best_zone: Node3D = null
		var best_dist: float = 18.0
		for z in get_tree().get_nodes_in_group("capture_zones"):
			if z is CaptureZonePad:
				var pad := z as CaptureZonePad
				if pad.get_owner_team() != team_id:
					var d: float = global_position.distance_to(pad.global_position)
					if d < best_dist:
						best_dist = d
						best_zone = pad
		if best_zone != null:
			return Vector3(best_zone.global_position.x, global_position.y, best_zone.global_position.z)

	if team_id == 0:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0] is Node3D:
			var pnode := players[0] as Node3D
			if not pnode.has_method("is_alive") or bool(pnode.call("is_alive")):
				if global_position.distance_to(pnode.global_position) > 5.8:
					return Vector3(
						clampf(pnode.global_position.x - 1.5, -13.2, 13.2),
						global_position.y,
						clampf(pnode.global_position.z - 2.6, -9.2, 9.2)
					)

	var offset: Vector3 = patrol_offset_a if _patrol_index == 0 else patrol_offset_b
	return _home_pos + offset


func _get_difficulty_scales() -> Dictionary:
	if team_id == 0:
		return {"speed": 1.0, "cooldown": 1.0, "error": 1.0}
	match SaveManager.bot_difficulty:
		"easy":
			return {"speed": 0.88, "cooldown": 1.38, "error": 1.45}
		"hard":
			return {"speed": 1.12, "cooldown": 0.78, "error": 0.60}
		_:
			return {"speed": 1.0, "cooldown": 1.0, "error": 1.0}


func _steer_around_obstacles(desired_dir: Vector3) -> Vector3:
	var flat := Vector3(desired_dir.x, 0.0, desired_dir.z)
	if flat.length_squared() < 0.0001:
		return desired_dir
	flat = flat.normalized()
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = global_position + Vector3(0.0, 0.55, 0.0)
	var fwd_q := PhysicsRayQueryParameters3D.create(origin, origin + flat * 1.35, 1, [get_rid()])
	fwd_q.collide_with_areas = false
	var fwd_hit: Dictionary = space_state.intersect_ray(fwd_q)
	if fwd_hit.is_empty():
		return flat

	var left_dir: Vector3 = flat.rotated(Vector3.UP, deg_to_rad(38.0))
	var right_dir: Vector3 = flat.rotated(Vector3.UP, deg_to_rad(-38.0))
	var left_q := PhysicsRayQueryParameters3D.create(origin, origin + left_dir * 1.45, 1, [get_rid()])
	var right_q := PhysicsRayQueryParameters3D.create(origin, origin + right_dir * 1.45, 1, [get_rid()])
	var left_blocked: bool = not space_state.intersect_ray(left_q).is_empty()
	var right_blocked: bool = not space_state.intersect_ray(right_q).is_empty()

	if not left_blocked and right_blocked:
		return flat.rotated(Vector3.UP, deg_to_rad(56.0)).normalized()
	if not right_blocked and left_blocked:
		return flat.rotated(Vector3.UP, deg_to_rad(-56.0)).normalized()
	return flat.rotated(Vector3.UP, deg_to_rad(56.0 * _strafe_sign)).normalized()


func _compute_danger_evasion() -> Vector3:
	var evade := Vector3.ZERO
	for b in get_tree().get_nodes_in_group("pulse_bombs"):
		if b is Node3D and is_instance_valid(b):
			var dvec := Vector3(global_position.x - (b as Node3D).global_position.x, 0.0, global_position.z - (b as Node3D).global_position.z)
			var dist: float = dvec.length()
			if dist < 4.2:
				evade += (dvec.normalized() if dist > 0.05 else Vector3.RIGHT) * (1.0 - dist / 4.2)
	for c in get_tree().get_nodes_in_group("explosive_crates"):
		if c is ExplosiveCrate and (c as ExplosiveCrate).is_intact() and float((c as ExplosiveCrate).get("_hp")) <= 22.0:
			var dvec := Vector3(global_position.x - (c as Node3D).global_position.x, 0.0, global_position.z - (c as Node3D).global_position.z)
			var dist: float = dvec.length()
			if dist < 3.5:
				evade += (dvec.normalized() if dist > 0.05 else Vector3.LEFT) * (0.85 - dist / 4.2)
	if evade.length_squared() > 0.001:
		return _steer_around_obstacles(evade.normalized())
	return Vector3.ZERO


func _compute_ally_separation() -> Vector3:
	var sep := Vector3.ZERO
	for b in get_tree().get_nodes_in_group("arena_bots"):
		if b == self or not (b is ArenaBot) or not is_instance_valid(b):
			continue
		var other := b as ArenaBot
		if other.team_id != team_id or not other.is_alive():
			continue
		var diff := Vector3(global_position.x - other.global_position.x, 0.0, global_position.z - other.global_position.z)
		var dist: float = diff.length()
		if dist > 0.01 and dist < 2.2:
			sep += diff.normalized() * ((2.2 - dist) / 2.2)
	return sep


func _process_patrol(delta: float) -> void:
	var target: Vector3 = _pick_objective_target()
	var to_target := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)

	_patrol_leg_timer += delta
	_patrol_stuck_timer += delta
	if _patrol_stuck_timer >= 1.25:
		_patrol_stuck_timer = 0.0
		if global_position.distance_to(_patrol_check_pos) < 0.25:
			_patrol_index = 1 - _patrol_index
			_patrol_leg_timer = 0.0
			_zone_seek_pause_timer = 3.5
		_patrol_check_pos = global_position

	if to_target.length() < 0.75:
		_move_vel.x = move_toward(_move_vel.x, 0.0, 14.0 * delta)
		_move_vel.y = move_toward(_move_vel.y, 0.0, 14.0 * delta)
		if _patrol_leg_timer >= 1.2:
			_patrol_index = 1 - _patrol_index
			_patrol_leg_timer = 0.0
		return

	if _patrol_leg_timer >= 5.5:
		_patrol_index = 1 - _patrol_index
		_patrol_leg_timer = 0.0

	var diff_scales: Dictionary = _get_difficulty_scales()
	var raw_dir: Vector3 = to_target.normalized() + _compute_ally_separation() * 0.65
	var dir: Vector3 = _steer_around_obstacles(raw_dir.normalized() if raw_dir.length_squared() > 0.001 else to_target.normalized())
	var spd: float = (profile.move_speed if profile != null else 3.4) * 0.80 * float(diff_scales["speed"]) * (1.28 if _speed_boost_timer > 0.0 else 1.0)
	_move_vel.x = move_toward(_move_vel.x, dir.x * spd, 14.0 * delta)
	_move_vel.y = move_toward(_move_vel.y, dir.z * spd, 14.0 * delta)
	_facing_yaw = lerp_angle(_facing_yaw, atan2(-dir.x, -dir.z), clampf(8.0 * delta, 0.0, 1.0))


func _process_engage(delta: float) -> void:
	if _target_ref == null or not is_instance_valid(_target_ref):
		return
	if _target_ref.has_method("is_alive") and not bool(_target_ref.call("is_alive")):
		_has_los = false
		_target_ref = null
		return
	if _target_ref.has_method("is_intact") and not bool(_target_ref.call("is_intact")):
		_has_los = false
		_target_ref = null
		return

	var to_target := Vector3(_target_ref.global_position.x - global_position.x, 0.0, _target_ref.global_position.z - global_position.z)
	var dist: float = to_target.length()
	if dist < 0.01:
		return
	var dir_to_target: Vector3 = to_target / dist
	_facing_yaw = lerp_angle(_facing_yaw, atan2(-dir_to_target.x, -dir_to_target.z), clampf(12.0 * delta, 0.0, 1.0))

	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.1, 2.2)
		_strafe_sign *= -1.0

	var strafe_vec := Vector3(-dir_to_target.z, 0.0, dir_to_target.x) * _strafe_sign
	var radial_factor: float = 0.0
	if dist > 9.8:
		radial_factor = 0.65
	elif dist < 5.4:
		radial_factor = -0.75

	var diff_scales: Dictionary = _get_difficulty_scales()
	var move_dir: Vector3 = strafe_vec * 0.75 + dir_to_target * radial_factor + _compute_ally_separation() * 0.6
	if move_dir.length_squared() > 0.001:
		move_dir = _steer_around_obstacles(move_dir.normalized())
	var spd: float = (profile.move_speed if profile != null else 3.4) * float(diff_scales["speed"]) * (1.28 if _speed_boost_timer > 0.0 else 1.0)
	_move_vel.x = move_toward(_move_vel.x, move_dir.x * spd, 16.0 * delta)
	_move_vel.y = move_toward(_move_vel.y, move_dir.z * spd, 16.0 * delta)

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		var is_scout: bool = (profile != null and profile.profile_id == &"scout_drone")
		var is_heavy: bool = (profile != null and profile.profile_id == &"heavy_sentinel")
		_fire_timer = fire_cooldown * float(diff_scales["cooldown"]) * (0.72 if is_scout else (1.28 if is_heavy else 1.0))
		_fire_energy_bolt(dir_to_target)


func _find_best_visible_target() -> Node3D:
	var sight_range: float = profile.sight_range if profile != null else 15.5
	var origin: Vector3 = global_position + Vector3(0.0, 0.92, 0.0)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var enemies: Array[Node3D] = []
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D and is_instance_valid(p) and (not p.has_method("is_alive") or bool(p.call("is_alive"))):
			if int(p.get("team_id")) != team_id:
				enemies.append(p as Node3D)
	for b in get_tree().get_nodes_in_group("arena_bots"):
		if b != self and b is Node3D and is_instance_valid(b) and (not b.has_method("is_alive") or bool(b.call("is_alive"))):
			if int(b.get("team_id")) != team_id:
				enemies.append(b as Node3D)

	var best_node: Node3D = null
	var best_dist: float = sight_range

	# Opportunistically snipe an ExplosiveCrate if an enemy is standing in blast radius
	for c in get_tree().get_nodes_in_group("explosive_crates"):
		if c is ExplosiveCrate and (c as ExplosiveCrate).is_intact():
			var crate := c as ExplosiveCrate
			var d_crate: float = global_position.distance_to(crate.global_position)
			if d_crate > sight_range:
				continue
			var enemy_near: bool = false
			for en in enemies:
				if en.global_position.distance_to(crate.global_position) <= 3.3:
					enemy_near = true
					break
			if enemy_near:
				var cq := PhysicsRayQueryParameters3D.create(origin, crate.global_position + Vector3(0.0, 0.6, 0.0), 1 | 2, [get_rid()])
				cq.collide_with_areas = false
				var chit: Dictionary = space_state.intersect_ray(cq)
				if not chit.is_empty() and chit.get("collider", null) == crate:
					return crate

	for cand_node in enemies:
		var target_pos: Vector3 = cand_node.global_position + Vector3(0.0, 0.92, 0.0)
		var dist: float = origin.distance_to(target_pos)
		if dist > best_dist:
			continue

		var query := PhysicsRayQueryParameters3D.create(origin, target_pos, 1 | 2, [get_rid()])
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty() and hit.get("collider") == cand_node:
			best_dist = dist
			best_node = cand_node

	return best_node


func _fire_energy_bolt(aim_dir: Vector3) -> void:
	var muzzle: Marker3D = _muzzle_left if _use_left_muzzle else _muzzle_right
	_use_left_muzzle = not _use_left_muzzle
	var torso_origin := global_position + Vector3(0.0, 0.92, 0.0)
	var spawn_pos: Vector3 = muzzle.global_position if muzzle != null else torso_origin + aim_dir * 0.65

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var pre_query := PhysicsRayQueryParameters3D.create(torso_origin, spawn_pos, 1 | 2, [get_rid()])
	pre_query.collide_with_areas = false
	pre_query.collide_with_bodies = true
	pre_query.hit_from_inside = true
	var pre_hit: Dictionary = space_state.intersect_ray(pre_query)

	var proj_parent: Node = get_tree().current_scene if get_tree() != null else get_parent()
	var is_heavy: bool = (profile != null and profile.profile_id == &"heavy_sentinel")
	var bolt_col := Color(0.219608, 0.741176, 0.972549, 1.0) if team_id == 0 else (Color(0.937255, 0.266667, 0.266667, 1.0) if is_heavy else Color(0.984314, 0.45098, 0.086275, 1.0))

	var dmg: float = projectile_damage * (1.30 if _damage_boost_timer > 0.0 else 1.0)
	if not pre_hit.is_empty():
		var hit_pos: Vector3 = pre_hit.get("position", spawn_pos)
		var collider: Object = pre_hit.get("collider", null)
		if collider != null and collider.has_method("take_damage"):
			var target_team: Variant = collider.get("team_id")
			if target_team == null or int(target_team) != team_id:
				var hit_dmg: float = dmg * (2.0 if is_heavy else 1.0)
				if collider is PlayerController:
					collider.call("take_damage", hit_dmg, team_id, torso_origin)
					(collider as PlayerController).apply_knockback(aim_dir * 3.0)
				elif collider is ExplosiveCrate or collider is ArenaBot:
					collider.call("take_damage", hit_dmg, team_id, false)
					if collider is ArenaBot:
						(collider as ArenaBot).apply_knockback(aim_dir * 3.0)
				else:
					collider.call("take_damage", hit_dmg, team_id)
		var flash: Node = PoolManager.acquire(ImpactFlash.POOL_ID, proj_parent)
		if flash is ImpactFlash:
			(flash as ImpactFlash).trigger(hit_pos, bolt_col)
	else:
		var diff_scales: Dictionary = _get_difficulty_scales()
		var precision: float = profile.aim_precision if profile != null else 0.72
		var max_err_rad: float = deg_to_rad((1.0 - precision) * 14.0) * float(diff_scales["error"])
		var offsets_deg: Array[float] = [0.0]
		if is_heavy:
			offsets_deg = [-4.5, 4.5]
		var bolt_scale: Vector3 = Vector3(1.25, 1.25, 1.1) if is_heavy else Vector3.ONE
		for off_deg in offsets_deg:
			var shoot_dir: Vector3 = aim_dir.rotated(Vector3.UP, deg_to_rad(off_deg) + randf_range(-max_err_rad, max_err_rad))
			var proj: Node = PoolManager.acquire(EnergyProjectile.POOL_ID, proj_parent)
			if proj is EnergyProjectile:
				(proj as EnergyProjectile).launch(
					spawn_pos,
					shoot_dir,
					projectile_speed,
					dmg,
					team_id,
					self,
					bolt_col,
					bolt_scale
				)
	var sfx: String = "res://assets/kenney/audio/blaster.ogg" if team_id == 0 else "res://assets/kenney/audio/enemy_attack.ogg"
	var pitch: float = randf_range(0.76, 0.84) if is_heavy else randf_range(0.94, 1.06)
	AudioManager.play_sfx_path(sfx, pitch, -3.0)


func apply_pickup(pickup_type: int, value: float) -> bool:
	if _state == BotState.RESPAWN:
		return false
	match pickup_type:
		0: # MEDKIT
			if _hp >= _max_hp - 0.5:
				return false
			_hp = minf(_max_hp, _hp + value)
			_update_hp_bar()
			return true
		1: # OVERCHARGE
			_damage_boost_timer = maxf(_damage_boost_timer, value)
			return true
		2: # SPEED_BOOST
			_speed_boost_timer = maxf(_speed_boost_timer, value)
			return true
	return false


func take_damage(amount: float, attacker_team: int, from_player: bool = false) -> void:
	if _state == BotState.RESPAWN or attacker_team == team_id:
		return

	_last_attacker_is_player = from_player
	_hit_flash_timer = 0.09
	_hp = maxf(_hp - amount, 0.0)
	_update_hp_bar()
	if _hp <= 0.0:
		_enter_respawn(attacker_team)
	else:
		AudioManager.play_sfx_path("res://assets/kenney/audio/enemy_hurt.ogg", randf_range(0.95, 1.08), -2.0)


func _enter_respawn(attacker_team: int) -> void:
	_state = BotState.RESPAWN
	_respawn_timer = 3.0
	_hit_flash_timer = 0.0
	_damage_boost_timer = 0.0
	_speed_boost_timer = 0.0
	if _model_pivot != null:
		_model_pivot.scale = _base_pivot_scale
	if _hp_bar_mat != null:
		_hp_bar_mat.albedo_color = _base_hp_col
	velocity = Vector3.ZERO
	_knockback_vel = Vector3.ZERO
	_move_vel = Vector2.ZERO
	AudioManager.play_sfx_path("res://assets/kenney/audio/enemy_destroy.ogg", randf_range(0.94, 1.04))

	var proj_parent: Node = get_tree().current_scene if get_tree() != null else get_parent()
	var flash_col := Color(0.219608, 0.741176, 0.972549, 1.0) if team_id == 0 else Color(0.984314, 0.572549, 0.235294, 1.0)
	var flash: Node = PoolManager.acquire(ImpactFlash.POOL_ID, proj_parent)
	if flash is ImpactFlash:
		(flash as ImpactFlash).trigger(global_position + Vector3(0.0, 0.9, 0.0), flash_col)

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
	var units: Array[Node] = []
	units.append_array(get_tree().get_nodes_in_group("player"))
	units.append_array(get_tree().get_nodes_in_group("arena_bots"))

	for off in offsets:
		var cand := Vector3(
			clampf(_home_pos.x + off.x, -13.6, 13.6),
			_home_pos.y,
			clampf(_home_pos.z + off.z, -9.6, 9.6)
		)
		var blocked: bool = false
		for u in units:
			if u != self and u is Node3D and is_instance_valid(u) and (u as Node3D).visible:
				if (u as Node3D).global_position.distance_to(cand) < 1.35:
					blocked = true
					break
		if not blocked:
			return cand
	return _home_pos


func _respawn_at_home() -> void:
	global_position = _find_safe_home_pos()
	_patrol_check_pos = global_position
	_patrol_leg_timer = 0.0
	_patrol_stuck_timer = 0.0
	_zone_seek_pause_timer = 0.0
	velocity = Vector3.ZERO
	_move_vel = Vector2.ZERO
	_knockback_vel = Vector3.ZERO
	_hp = _max_hp
	_has_los = false
	_target_ref = null
	_fire_timer = 0.85
	_last_attacker_is_player = false
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
