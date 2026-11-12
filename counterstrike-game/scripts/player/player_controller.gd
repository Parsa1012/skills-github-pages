class_name PlayerController
extends CharacterBody3D
## کنترلر سه‌بعدی بازیکن در نمای 2.5D BombSquad با مدل متحرک و سلاح‌های انرژی Kenney.

signal player_defeated(attacker_team: int)

const DASH_DURATION: float = 0.18
const DASH_SPEED: float = 14.8
const DASH_COOLDOWN: float = 2.4

@export var team_id: int = 0
@export var walk_speed: float = 3.9
@export var run_speed: float = 6.5
@export var acceleration: float = 28.0
@export var deceleration: float = 34.0
@export var turn_speed: float = 16.0
@export var max_hp: float = 100.0
@export var camera_rig_path: NodePath
@export var touch_hud_path: NodePath
@export var blasters: Array[EnergyBlasterData] = []

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _visual_root: Node3D = $VisualRoot
@onready var _kenney_soldier: Node3D = $VisualRoot/KenneySoldier
@onready var _weapon_mount: Node3D = $VisualRoot/WeaponMount
@onready var _muzzle_marker: Marker3D = $VisualRoot/WeaponMount/MuzzleMarker
@onready var _muzzle_flash: MeshInstance3D = $VisualRoot/WeaponMount/MuzzleMarker/MuzzleFlashMesh
@onready var _team_ring: MeshInstance3D = $TeamRingMesh
@onready var _buff_aura: MeshInstance3D = $BuffAuraMesh
@onready var _aim_indicator: Node3D = $AimIndicatorPivot
@onready var _aim_beam: MeshInstance3D = $AimIndicatorPivot/AimBeamMesh
@onready var _aim_tip: MeshInstance3D = $AimIndicatorPivot/AimTipMesh

var _gravity: float = 18.0
var _camera_rig: Node3D = null
var _touch_hud: Node = null
var _anim_player: AnimationPlayer = null
var _aim_beam_mat: StandardMaterial3D = null
var _muzzle_flash_mat: StandardMaterial3D = null
var _team_ring_mat: StandardMaterial3D = null
var _buff_aura_mat: StandardMaterial3D = null
var _facing_yaw: float = -PI * 0.5
var _spawn_pos: Vector3 = Vector3.ZERO

var _hp: float = 100.0
var _alive: bool = true
var _respawn_timer: float = 0.0
var _death_hide_timer: float = 0.0
var _time_since_damage: float = 10.0

var _blaster_index: int = 0
var _weapon_model_instance: Node3D = null
var _current_energy: int = 16
var _fire_cooldown: float = 0.0
var _recharging: bool = false
var _recharge_timer: float = 0.0
var _recoil_offset: float = 0.0
var _muzzle_flash_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _damage_boost_timer: float = 0.0
var _speed_boost_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _dash_emit_timer: float = 0.0
var _buff_emit_timer: float = 0.0
var _aura_pulse_time: float = 0.0
var _step_timer: float = 0.0
var _respawn_last_sec: int = -1


func _ready() -> void:
	add_to_group("player")
	_spawn_pos = global_position
	_hp = max_hp
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	if _gravity < 9.8:
		_gravity = 18.0

	_resolve_references()
	_setup_materials()
	_setup_animations()
	_ensure_default_blasters()
	_equip_blaster(GameManager.get_starting_blaster_index(), false)

	EventBus.blaster_switch_requested.connect(switch_next_blaster)
	EventBus.blaster_recharge_requested.connect(start_recharge)
	EventBus.player_dash_requested.connect(trigger_dash)
	_emit_stats()
	EventBus.player_buff_updated.emit(0.0, 0.0)
	EventBus.player_dash_updated.emit(0.0, DASH_COOLDOWN, true)


func _exit_tree() -> void:
	if EventBus.blaster_switch_requested.is_connected(switch_next_blaster):
		EventBus.blaster_switch_requested.disconnect(switch_next_blaster)
	if EventBus.blaster_recharge_requested.is_connected(start_recharge):
		EventBus.blaster_recharge_requested.disconnect(start_recharge)
	if EventBus.player_dash_requested.is_connected(trigger_dash):
		EventBus.player_dash_requested.disconnect(trigger_dash)


func is_alive() -> bool:
	return _alive


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
		mat.albedo_color = Color(0.219608, 0.741176, 0.972549, 0.58)
		_aim_beam.material_override = mat
		if _aim_tip != null:
			_aim_tip.material_override = mat
		_aim_beam_mat = mat

	if _muzzle_flash != null:
		_muzzle_flash_mat = StandardMaterial3D.new()
		_muzzle_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_muzzle_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_muzzle_flash_mat.albedo_color = Color(0.219608, 0.741176, 0.972549, 0.9)
		_muzzle_flash.material_override = _muzzle_flash_mat
		_muzzle_flash.visible = false

	if _team_ring != null:
		_team_ring_mat = StandardMaterial3D.new()
		_team_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_team_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_team_ring_mat.albedo_color = Color(0.219608, 0.741176, 0.972549, 0.65)
		_team_ring.material_override = _team_ring_mat

	if _buff_aura != null:
		_buff_aura_mat = StandardMaterial3D.new()
		_buff_aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_buff_aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_buff_aura_mat.albedo_color = Color(0.984314, 0.74902, 0.141176, 0.72)
		_buff_aura.material_override = _buff_aura_mat
		_buff_aura.visible = false


func _setup_animations() -> void:
	if _kenney_soldier == null:
		return
	_anim_player = _kenney_soldier.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		return

	# Make a per-instance editable library so loop modes and rest-leg tracks apply cleanly.
	for anim_name in ["idle", "walk", "sprint"]:
		if _anim_player.has_animation(anim_name):
			var anim: Animation = _anim_player.get_animation(anim_name)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
	if _anim_player.has_animation("die"):
		var die_anim: Animation = _anim_player.get_animation("die")
		if die_anim != null:
			die_anim.loop_mode = Animation.LOOP_NONE

	# Kenney's 'idle' omits leg/root tracks, which leaves legs stuck mid-stride after walking.
	if _anim_player.has_animation("idle") and _anim_player.has_animation("static"):
		var idle_anim: Animation = _anim_player.get_animation("idle")
		var static_anim: Animation = _anim_player.get_animation("static")
		if idle_anim != null and static_anim != null:
			var existing_paths: Dictionary = {}
			for t in idle_anim.get_track_count():
				existing_paths[str(idle_anim.track_get_path(t))] = true
			for st in static_anim.get_track_count():
				var path_str: String = str(static_anim.track_get_path(st))
				if not existing_paths.has(path_str) and (
					"leg-" in path_str or path_str.ends_with(":position") or path_str.ends_with("root")
				):
					if static_anim.track_get_key_count(st) > 0:
						var new_t: int = idle_anim.add_track(static_anim.track_get_type(st))
						idle_anim.track_set_path(new_t, static_anim.track_get_path(st))
						idle_anim.track_set_interpolation_type(new_t, static_anim.track_get_interpolation_type(st))
						idle_anim.track_insert_key(new_t, 0.0, static_anim.track_get_key_value(st, 0))

	if _anim_player.has_animation("idle"):
		_anim_player.play("idle")


func _ensure_default_blasters() -> void:
	if not blasters.is_empty():
		return
	for p in [
		"res://data/blasters/pulse_blaster.tres",
		"res://data/blasters/rapid_repeater.tres",
		"res://data/blasters/plasma_scatter.tres",
		"res://data/blasters/arc_railgun.tres"
	]:
		if ResourceLoader.exists(p):
			var res: Resource = ResourceLoader.load(p)
			if res is EnergyBlasterData:
				blasters.append(res as EnergyBlasterData)


func _get_active_blaster() -> EnergyBlasterData:
	if blasters.is_empty():
		return null
	return blasters[clampi(_blaster_index, 0, blasters.size() - 1)]


func switch_next_blaster() -> void:
	if blasters.size() <= 1 or not _alive:
		return
	var next_idx: int = (_blaster_index + 1) % blasters.size()
	_equip_blaster(next_idx, true)


func _equip_blaster(idx: int, play_sfx: bool) -> void:
	if blasters.is_empty():
		return
	_blaster_index = clampi(idx, 0, blasters.size() - 1)
	var b: EnergyBlasterData = _get_active_blaster()
	if b == null:
		return

	_recharging = false
	_recharge_timer = 0.0
	_fire_cooldown = 0.0
	_current_energy = b.energy_cell_capacity

	if _weapon_model_instance != null and is_instance_valid(_weapon_model_instance):
		_weapon_model_instance.queue_free()
		_weapon_model_instance = null

	if _weapon_mount != null and not b.model_scene_path.is_empty() and ResourceLoader.exists(b.model_scene_path):
		var packed: Resource = ResourceLoader.load(b.model_scene_path)
		if packed is PackedScene:
			var inst: Node = (packed as PackedScene).instantiate()
			if inst is Node3D:
				_weapon_model_instance = inst as Node3D
				_weapon_model_instance.scale = Vector3(b.model_scale, b.model_scale, b.model_scale)
				_weapon_model_instance.rotation_degrees = Vector3(0.0, 180.0, 0.0)
				_weapon_mount.add_child(_weapon_model_instance)

	if play_sfx:
		AudioManager.play_sfx_path("res://assets/kenney/audio/weapon_change.ogg", 1.0)
	_emit_stats()


func start_recharge() -> void:
	var b: EnergyBlasterData = _get_active_blaster()
	if b == null or _recharging or not _alive:
		return
	if _current_energy >= b.energy_cell_capacity:
		return
	_recharging = true
	_recharge_timer = b.recharge_seconds
	AudioManager.play_ui_menu(0.92)
	_emit_stats()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_ev := event as InputEventKey
		if key_ev.keycode == KEY_Q:
			switch_next_blaster()
		elif key_ev.keycode == KEY_R:
			start_recharge()
		elif key_ev.keycode == KEY_SHIFT:
			trigger_dash()


func trigger_dash() -> bool:
	if not _alive or _dash_cooldown > 0.0 or _dash_timer > 0.0:
		return false
	var move_2d: Vector2 = _read_move_input()
	var cam_yaw_rad: float = _get_camera_yaw_radians()
	var move_world: Vector3 = _stick_to_world_dir(move_2d, cam_yaw_rad)
	if move_world.length_squared() > 0.02:
		_dash_dir = move_world.normalized()
	else:
		_dash_dir = Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw)).normalized()

	_dash_timer = DASH_DURATION
	_dash_cooldown = DASH_COOLDOWN
	_dash_emit_timer = 0.0
	AudioManager.play_dash_sfx()
	EventBus.camera_trauma_requested.emit(0.08)
	var proj_parent: Node = get_tree().current_scene if get_tree() != null else get_parent()
	var flash: Node = PoolManager.acquire(ImpactFlash.POOL_ID, proj_parent)
	if flash is ImpactFlash:
		(flash as ImpactFlash).trigger(global_position + Vector3(0.0, 0.55, 0.0), Color(0.219608, 0.741176, 0.972549, 1.0))
	EventBus.player_dash_updated.emit(_dash_cooldown, DASH_COOLDOWN, false)
	return true


func _physics_process(delta: float) -> void:
	if not _alive:
		if _death_hide_timer > 0.0:
			_death_hide_timer -= delta
			if _death_hide_timer <= 0.0 and _visual_root != null:
				_visual_root.visible = false
		_respawn_timer -= delta
		var sec_left: int = maxi(1, int(ceil(_respawn_timer)))
		if sec_left != _respawn_last_sec and _respawn_timer > 0.0:
			_respawn_last_sec = sec_left
			EventBus.player_respawn_countdown.emit(_respawn_timer, true)
		if _respawn_timer <= 0.0:
			_respawn()
		return

	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer -= delta
		if _muzzle_flash_timer <= 0.0 and _muzzle_flash != null:
			_muzzle_flash.visible = false

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _team_ring_mat != null:
			_team_ring_mat.albedo_color = Color(0.984314, 0.25, 0.25, 0.9) if _hit_flash_timer > 0.0 else Color(0.219608, 0.741176, 0.972549, 0.65)

	var had_buff: bool = (_damage_boost_timer > 0.0 or _speed_boost_timer > 0.0)
	if _damage_boost_timer > 0.0:
		_damage_boost_timer = maxf(0.0, _damage_boost_timer - delta)
	if _speed_boost_timer > 0.0:
		_speed_boost_timer = maxf(0.0, _speed_boost_timer - delta)
	if had_buff:
		_buff_emit_timer += delta
		if _buff_emit_timer >= 0.45 or (_damage_boost_timer <= 0.0 and _speed_boost_timer <= 0.0):
			_buff_emit_timer = 0.0
			EventBus.player_buff_updated.emit(_damage_boost_timer, _speed_boost_timer)

	if _dash_cooldown > 0.0:
		_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
		_dash_emit_timer += delta
		if _dash_cooldown <= 0.0:
			_dash_emit_timer = 0.0
			EventBus.player_dash_updated.emit(0.0, DASH_COOLDOWN, true)
		elif _dash_emit_timer >= 0.16:
			_dash_emit_timer = 0.0
			EventBus.player_dash_updated.emit(_dash_cooldown, DASH_COOLDOWN, false)

	if _dash_timer > 0.0:
		_dash_timer = maxf(0.0, _dash_timer - delta)

	_update_buff_aura(delta)

	_time_since_damage += delta
	if _time_since_damage >= 4.0 and _hp < max_hp:
		var prev_hp: int = int(ceil(_hp))
		_hp = minf(max_hp, _hp + 16.0 * delta)
		if int(ceil(_hp)) != prev_hp:
			_emit_stats()

	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(0.0, _fire_cooldown - delta)

	if _recharging:
		_recharge_timer -= delta
		if _recharge_timer <= 0.0:
			_recharging = false
			var b: EnergyBlasterData = _get_active_blaster()
			if b != null:
				_current_energy = b.energy_cell_capacity
			AudioManager.play_recharge_done_sfx()
			_emit_stats()

	var move_2d: Vector2 = _read_move_input()
	var aim_2d: Vector2 = _read_aim_input()
	var fire_active: bool = _read_fire_input()

	var cam_yaw_rad: float = _get_camera_yaw_radians()
	var move_world: Vector3 = _stick_to_world_dir(move_2d, cam_yaw_rad)
	var aim_world: Vector3 = _stick_to_world_dir(aim_2d, cam_yaw_rad)

	if _dash_timer > 0.0:
		velocity.x = _dash_dir.x * DASH_SPEED
		velocity.z = _dash_dir.z * DASH_SPEED
	else:
		var speed_mult: float = 1.30 if _speed_boost_timer > 0.0 else 1.0
		var move_mag: float = clampf(move_2d.length(), 0.0, 1.0)
		var target_speed: float = 0.0
		if move_mag > 0.01:
			target_speed = lerpf(walk_speed, run_speed, clampf((move_mag - 0.15) / 0.85, 0.0, 1.0)) * speed_mult

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

	var actual_horiz_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	_update_facing_and_aim(move_world, aim_world, move_2d.length(), aim_2d.length(), fire_active, delta)
	_update_soldier_animation(actual_horiz_speed, delta)
	_update_footsteps(actual_horiz_speed, delta)

	if fire_active and not _recharging and _fire_cooldown <= 0.0:
		_try_fire(actual_horiz_speed)


func _update_footsteps(horiz_speed: float, delta: float) -> void:
	if not is_on_floor() or horiz_speed < 1.8:
		_step_timer = 0.08
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.28 if horiz_speed > 4.6 else 0.38
		AudioManager.play_sfx_path("res://assets/kenney/audio/walking.ogg", randf_range(0.92, 1.08), -12.0)


func _try_fire(horiz_speed: float) -> void:
	var b: EnergyBlasterData = _get_active_blaster()
	if b == null:
		return
	if _current_energy <= 0:
		start_recharge()
		return

	_current_energy -= 1
	var cd_mult: float = 0.78 if _damage_boost_timer > 0.0 else 1.0
	var dmg_mult: float = 1.35 if _damage_boost_timer > 0.0 else 1.0
	_fire_cooldown = b.pulse_cooldown * cd_mult
	_recoil_offset = 0.09
	_muzzle_flash_timer = 0.055
	if _muzzle_flash != null:
		_muzzle_flash.visible = true
		if _muzzle_flash_mat != null:
			_muzzle_flash_mat.albedo_color = Color(b.projectile_color.r, b.projectile_color.g, b.projectile_color.b, 0.92)
	if b.pellets_per_shot > 1:
		EventBus.camera_trauma_requested.emit(0.11)

	var forward_dir := Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw)).normalized()
	var chest_origin := global_position + Vector3(0.0, 0.74, 0.0)
	var muzzle_pos: Vector3 = _muzzle_marker.global_position if _muzzle_marker != null else chest_origin + forward_dir * 0.68
	var barrel_check_end := Vector3(muzzle_pos.x, chest_origin.y, muzzle_pos.z)

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var pre_query := PhysicsRayQueryParameters3D.create(chest_origin, barrel_check_end, 1 | 2, [get_rid()])
	pre_query.collide_with_areas = false
	pre_query.collide_with_bodies = true
	pre_query.hit_from_inside = true
	var pre_hit: Dictionary = space_state.intersect_ray(pre_query)

	var spread_deg: float = b.spread_moving_deg if horiz_speed > 0.6 else b.spread_still_deg
	var proj_parent: Node = get_tree().current_scene if get_tree() != null else get_parent()

	if not pre_hit.is_empty():
		var hit_pos: Vector3 = pre_hit.get("position", barrel_check_end)
		var collider: Object = pre_hit.get("collider", null)
		if collider != null and collider.has_method("take_damage"):
			var target_team: Variant = collider.get("team_id")
			if target_team == null or int(target_team) != team_id:
				var total_dmg: float = b.energy_damage * dmg_mult * float(b.pellets_per_shot)
				if collider is ArenaBot:
					collider.call("take_damage", total_dmg, team_id, true)
				else:
					collider.call("take_damage", total_dmg, team_id)
				var killed: bool = collider.has_method("is_alive") and not bool(collider.call("is_alive"))
				AudioManager.play_hitmarker_sfx(killed)
				EventBus.enemy_hit_confirmed.emit(total_dmg, killed)
		var flash: Node = PoolManager.acquire(ImpactFlash.POOL_ID, proj_parent)
		if flash is ImpactFlash:
			(flash as ImpactFlash).trigger(hit_pos, b.projectile_color)
	else:
		var spawn_pos := Vector3(muzzle_pos.x, chest_origin.y, muzzle_pos.z)
		var count: int = maxi(1, b.pellets_per_shot)
		for p_idx in count:
			var base_deg: float = 0.0
			if count > 1:
				base_deg = lerpf(-spread_deg, spread_deg, float(p_idx) / float(count - 1))
			else:
				base_deg = randf_range(-spread_deg, spread_deg)
			var angle_rad: float = deg_to_rad(base_deg + (randf_range(-0.8, 0.8) if count > 1 else 0.0))
			var bolt_dir: Vector3 = forward_dir.rotated(Vector3.UP, angle_rad)
			var proj: Node = PoolManager.acquire(EnergyProjectile.POOL_ID, proj_parent)
			if proj is EnergyProjectile:
				(proj as EnergyProjectile).launch(
					spawn_pos,
					bolt_dir,
					b.projectile_speed,
					b.energy_damage * dmg_mult,
					team_id,
					self,
					b.projectile_color,
					b.bolt_scale,
					b.pierce_count,
					true
				)

	AudioManager.play_sfx_path(b.shoot_sfx_path, randf_range(0.95, 1.05))
	if _current_energy <= 0:
		start_recharge()
	else:
		_emit_stats()


func apply_pickup(pickup_type: int, value: float) -> bool:
	if not _alive:
		return false
	match pickup_type:
		0: # MEDKIT
			if _hp >= max_hp - 0.5:
				return false
			_hp = minf(max_hp, _hp + value)
			_emit_stats()
			return true
		1: # OVERCHARGE
			var b: EnergyBlasterData = _get_active_blaster()
			if b != null:
				_current_energy = b.energy_cell_capacity
			_recharging = false
			_recharge_timer = 0.0
			_damage_boost_timer = maxf(_damage_boost_timer, value)
			_buff_emit_timer = 0.0
			_emit_stats()
			EventBus.player_buff_updated.emit(_damage_boost_timer, _speed_boost_timer)
			return true
		2: # SPEED_BOOST
			_speed_boost_timer = maxf(_speed_boost_timer, value)
			_buff_emit_timer = 0.0
			EventBus.player_buff_updated.emit(_damage_boost_timer, _speed_boost_timer)
			return true
	return false


func _update_buff_aura(delta: float) -> void:
	if _buff_aura == null or _buff_aura_mat == null:
		return
	var show_aura: bool = (_damage_boost_timer > 0.0 or _speed_boost_timer > 0.0 or _dash_timer > 0.0)
	_buff_aura.visible = show_aura
	if not show_aura:
		return
	_aura_pulse_time += delta * 9.0
	var s: float = 1.0 + 0.07 * sin(_aura_pulse_time)
	_buff_aura.scale = Vector3(s, 1.0, s)
	if _dash_timer > 0.0:
		_buff_aura_mat.albedo_color = Color(0.219608, 0.741176, 0.972549, 0.85)
	elif _damage_boost_timer > 0.0:
		_buff_aura_mat.albedo_color = Color(0.984314, 0.74902, 0.141176, 0.75)
	else:
		_buff_aura_mat.albedo_color = Color(0.658824, 0.333333, 0.968627, 0.75)


func take_damage(amount: float, attacker_team: int) -> void:
	if not _alive or attacker_team == team_id or _dash_timer > 0.05:
		return
	_time_since_damage = 0.0
	_hit_flash_timer = 0.14
	_hp = maxf(_hp - amount, 0.0)
	AudioManager.play_player_hit_sfx()
	EventBus.camera_trauma_requested.emit(0.24)
	EventBus.player_damaged_feedback.emit(_hp / maxf(max_hp, 1.0))
	_emit_stats()
	if _hp <= 0.0:
		_enter_respawn(attacker_team)


func _enter_respawn(attacker_team: int) -> void:
	_alive = false
	_respawn_timer = 2.5
	_death_hide_timer = 0.58
	_respawn_last_sec = 3
	_damage_boost_timer = 0.0
	_speed_boost_timer = 0.0
	_dash_timer = 0.0
	_muzzle_flash_timer = 0.0
	if _muzzle_flash != null:
		_muzzle_flash.visible = false
	if _buff_aura != null:
		_buff_aura.visible = false
	velocity = Vector3.ZERO
	AudioManager.play_sfx_path("res://assets/kenney/audio/enemy_destroy.ogg", 0.85)
	var proj_parent: Node = get_tree().current_scene if get_tree() != null else get_parent()
	var flash: Node = PoolManager.acquire(ImpactFlash.POOL_ID, proj_parent)
	if flash is ImpactFlash:
		(flash as ImpactFlash).trigger(global_position + Vector3(0.0, 0.85, 0.0), Color(0.219608, 0.741176, 0.972549, 1.0))
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	if _anim_player != null and _anim_player.has_animation("die"):
		_anim_player.speed_scale = 1.4
		_anim_player.play("die", 0.05)
	elif _visual_root != null:
		_visual_root.visible = false
	if _team_ring != null:
		_team_ring.visible = false
	if _aim_indicator != null:
		_aim_indicator.visible = false
	EventBus.player_buff_updated.emit(0.0, 0.0)
	EventBus.player_respawn_countdown.emit(_respawn_timer, true)
	player_defeated.emit(attacker_team)
	_emit_stats()


func _find_safe_respawn_pos() -> Vector3:
	var candidates: Array[Vector3] = [
		_spawn_pos,
		_spawn_pos + Vector3(0.0, 0.0, -2.2),
		_spawn_pos + Vector3(0.0, 0.0, 2.2),
		_spawn_pos + Vector3(1.8, 0.0, 0.0)
	]
	var bots: Array[Node] = get_tree().get_nodes_in_group("arena_bots")
	for cand in candidates:
		var blocked: bool = false
		for bot in bots:
			if bot is Node3D and (bot as Node3D).visible:
				if (bot as Node3D).global_position.distance_to(cand) < 1.35:
					blocked = true
					break
		if not blocked:
			return cand
	return _spawn_pos


func _respawn() -> void:
	global_position = _find_safe_respawn_pos()
	velocity = Vector3.ZERO
	_hp = max_hp
	_alive = true
	_recharging = false
	_dash_timer = 0.0
	_dash_cooldown = 0.0
	_time_since_damage = 10.0
	_death_hide_timer = 0.0
	EventBus.player_dash_updated.emit(0.0, DASH_COOLDOWN, true)
	var b: EnergyBlasterData = _get_active_blaster()
	if b != null:
		_current_energy = b.energy_cell_capacity
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", false)
	if _visual_root != null:
		_visual_root.visible = true
	if _anim_player != null and _anim_player.has_animation("idle"):
		_anim_player.speed_scale = 1.0
		_anim_player.play("idle")
	if _team_ring != null:
		_team_ring.visible = true
	if _aim_indicator != null:
		_aim_indicator.visible = true
	AudioManager.play_sfx_path("res://assets/kenney/audio/land.ogg", 1.0, -6.0)
	EventBus.player_respawn_countdown.emit(0.0, false)
	_emit_stats()


func _emit_stats() -> void:
	var b: EnergyBlasterData = _get_active_blaster()
	var b_name: String = b.display_name if b != null else "پالس بلاستر"
	var b_cap: int = b.energy_cell_capacity if b != null else 16
	EventBus.player_stats_updated.emit(int(ceil(_hp)), int(max_hp), _current_energy, b_cap, b_name, _recharging)


func _read_move_input() -> Vector2:
	var vec: Vector2 = Vector2.ZERO
	if _touch_hud != null and _touch_hud.has_method("get_move_vector"):
		vec = _touch_hud.call("get_move_vector")
		if vec.length_squared() > 0.001:
			vec *= SaveManager.joystick_sensitivity
			if vec.length() > 1.0:
				vec = vec.normalized()
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
		_facing_yaw = lerp_angle(_facing_yaw, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

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
		var b: EnergyBlasterData = _get_active_blaster()
		var base_col: Color = b.projectile_color if b != null else Color(0.219608, 0.741176, 0.972549, 1.0)
		var alpha: float = 0.85 if fire_active else 0.56
		_aim_beam_mat.albedo_color = Color(base_col.r, base_col.g, base_col.b, alpha)


func _update_soldier_animation(horiz_speed: float, delta: float) -> void:
	if _weapon_mount != null:
		_recoil_offset = move_toward(_recoil_offset, 0.0, 1.1 * delta)
		_weapon_mount.position.z = -0.24 + _recoil_offset

	if _anim_player == null:
		return

	if horiz_speed > 4.4 and _anim_player.has_animation("sprint"):
		if _anim_player.current_animation != "sprint":
			_anim_player.play("sprint", 0.12)
		_anim_player.speed_scale = clampf(horiz_speed / run_speed, 0.8, 1.35)
	elif horiz_speed > 0.35 and _anim_player.has_animation("walk"):
		if _anim_player.current_animation != "walk":
			_anim_player.play("walk", 0.12)
		_anim_player.speed_scale = clampf(horiz_speed / walk_speed, 0.65, 1.3)
	elif _anim_player.has_animation("idle"):
		if _anim_player.current_animation != "idle":
			_anim_player.play("idle", 0.15)
		_anim_player.speed_scale = 1.0
