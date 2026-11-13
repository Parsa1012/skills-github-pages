class_name LobbyStage3D
extends Node3D
## صحنه ۳بعدی زنده لابی منوی اصلی (قهرمان چرخان با سلاح فعال، حلقه هولوگرام، کف‌پوش شیدری و نورپردازی ACES).

@onready var _world_env: WorldEnvironment = $WorldEnvironment
@onready var _key_light: DirectionalLight3D = $KeyLight
@onready var _rim_light: DirectionalLight3D = $RimLight
@onready var _camera: Camera3D = $LobbyCamera
@onready var _hero_turntable: Node3D = $HeroTurntable
@onready var _soldier_root: Node3D = $HeroTurntable/HeroPivot/KenneySoldier
@onready var _weapon_mount: Node3D = $HeroTurntable/HeroPivot/WeaponMount
@onready var _muzzle_core: MeshInstance3D = $HeroTurntable/HeroPivot/WeaponMount/MuzzleCore
@onready var _pedestal_ring: MeshInstance3D = $HeroTurntable/PedestalRing
@onready var _holo_ring: MeshInstance3D = get_node_or_null("HeroTurntable/HoloRing") as MeshInstance3D
@onready var _floor_mesh: MeshInstance3D = $LobbyFloor
@onready var _hover_drone: Node3D = $BackdropProps/HoverDronePivot
@onready var _trophy_prop: Node3D = $BackdropProps/TrophyPlinth/KenneyTrophy

var _anim_player: AnimationPlayer = null
var _weapon_instance: Node3D = null
var _weapon_pop_tween: Tween = null
var _cam_tween: Tween = null
var _theme_tween: Tween = null

var _ring_mat: StandardMaterial3D = null
var _holo_mat: StandardMaterial3D = null
var _muzzle_mat: StandardMaterial3D = null
var _floor_shader_mat: ShaderMaterial = null

var _spin_velocity: float = 0.0
var _idle_time: float = 0.0
var _current_weapon_id: String = ""
var _current_map_id: String = ""
var _base_cam_pos: Vector3 = Vector3(0.0, 1.82, 5.25)


func _ready() -> void:
	_setup_materials()
	_setup_soldier_animation()
	_apply_quality_lighting(SaveManager.quality_preset)
	EventBus.quality_preset_changed.connect(_apply_quality_lighting)
	if _camera != null:
		_base_cam_pos = _camera.position


func _exit_tree() -> void:
	if EventBus.quality_preset_changed.is_connected(_apply_quality_lighting):
		EventBus.quality_preset_changed.disconnect(_apply_quality_lighting)


func _setup_materials() -> void:
	if _pedestal_ring != null:
		_ring_mat = VisualFxUtils.make_unshaded_hdr_material(Color(0.219608, 0.741176, 0.972549, 1.0), 0.90, 1.55)
		_pedestal_ring.material_override = _ring_mat

	if _holo_ring != null:
		_holo_mat = VisualFxUtils.make_unshaded_hdr_material(Color(0.219608, 0.741176, 0.972549, 1.0), 0.55, 1.65)
		_holo_ring.material_override = _holo_mat

	if _muzzle_core != null:
		_muzzle_mat = VisualFxUtils.make_unshaded_hdr_material(Color(0.219608, 0.741176, 0.972549, 1.0), 1.0, 1.95)
		_muzzle_core.material_override = _muzzle_mat

	if _floor_mesh != null and _floor_mesh.material_override is ShaderMaterial:
		_floor_shader_mat = (_floor_mesh.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		_floor_mesh.material_override = _floor_shader_mat


func _setup_soldier_animation() -> void:
	if _soldier_root == null:
		return
	_anim_player = _soldier_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player != null:
		VisualFxUtils.patch_kenney_soldier_animations(_anim_player)
		if _anim_player.has_animation("idle"):
			_anim_player.play("idle")


func _apply_quality_lighting(preset_name: String) -> void:
	VisualFxUtils.apply_environment_quality(
		_world_env,
		preset_name,
		_current_map_id == "sector_02"
	)
	if _key_light != null:
		_key_light.shadow_enabled = (preset_name != "low")
		_key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if preset_name == "high" else DirectionalLight3D.SHADOW_ORTHOGONAL


func _process(delta: float) -> void:
	_idle_time += delta

	if _hero_turntable != null:
		if absf(_spin_velocity) > 0.002:
			_hero_turntable.rotation.y += _spin_velocity * delta
			_spin_velocity = lerpf(_spin_velocity, 0.0, clampf(5.5 * delta, 0.0, 1.0))
		else:
			_hero_turntable.rotation.y += 0.24 * delta

	if _holo_ring != null:
		_holo_ring.rotation.y -= 0.85 * delta
		_holo_ring.position.y = 0.42 + sin(_idle_time * 2.4) * 0.05

	if _hover_drone != null:
		_hover_drone.position.y = 1.68 + sin(_idle_time * 2.1) * 0.14
		_hover_drone.rotation.y = -0.55 + sin(_idle_time * 0.8) * 0.18

	if _trophy_prop != null:
		_trophy_prop.rotation.y += 0.72 * delta

	if _muzzle_core != null:
		var pulse: float = 0.88 + 0.22 * sin(_idle_time * 5.2)
		_muzzle_core.scale = Vector3(pulse, pulse, pulse)


func spin_by_drag(delta_x_px: float) -> void:
	if _hero_turntable == null:
		return
	_hero_turntable.rotation.y += delta_x_px * 0.0095
	_spin_velocity = clampf(delta_x_px * 0.16, -9.0, 9.0)


func focus_for_tab(tab_idx: int) -> void:
	if _camera == null or not is_inside_tree():
		return
	var target_pos := Vector3(0.0, 1.82, 5.25)
	var target_fov: float = 38.0
	match tab_idx:
		0: # زرادخانه: نمای نزدیک‌تر به سلاح و قهرمان
			target_pos = Vector3(0.0, 1.72, 4.75)
			target_fov = 36.0
		1: # نقشه و قوانین: زاویه بازتر برای دیدن محیط
			target_pos = Vector3(0.0, 2.02, 5.85)
			target_fov = 41.0
		_: # تنظیمات و کارنامه
			target_pos = Vector3(0.0, 1.88, 5.45)
			target_fov = 38.5
	_base_cam_pos = target_pos
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(_camera, "position", target_pos, 0.45)
	_cam_tween.tween_property(_camera, "fov", target_fov, 0.45)


func set_weapon(blaster: EnergyBlasterData, accent_color: Color) -> void:
	if blaster == null:
		return
	var bid: String = str(blaster.blaster_id)
	var changed: bool = (bid != _current_weapon_id)
	_current_weapon_id = bid

	if _ring_mat != null:
		_ring_mat.albedo_color = Color(accent_color.r * 1.55, accent_color.g * 1.55, accent_color.b * 1.55, 0.90)
	if _holo_mat != null:
		_holo_mat.albedo_color = Color(accent_color.r * 1.65, accent_color.g * 1.65, accent_color.b * 1.65, 0.52)
	if _muzzle_mat != null:
		_muzzle_mat.albedo_color = Color(accent_color.r * 1.95, accent_color.g * 1.95, accent_color.b * 1.95, 1.0)

	if not changed and _weapon_instance != null:
		return

	if _weapon_instance != null and is_instance_valid(_weapon_instance):
		_weapon_instance.queue_free()
		_weapon_instance = null

	if _weapon_mount != null and not blaster.model_scene_path.is_empty() and ResourceLoader.exists(blaster.model_scene_path):
		var packed: Resource = ResourceLoader.load(blaster.model_scene_path)
		if packed is PackedScene:
			var inst: Node = (packed as PackedScene).instantiate()
			if inst is Node3D:
				_weapon_instance = inst as Node3D
				var s: float = blaster.model_scale * 1.18
				_weapon_instance.scale = Vector3(s, s, s)
				_weapon_instance.rotation_degrees = Vector3(0.0, 180.0, 0.0)
				_weapon_mount.add_child(_weapon_instance)

	if changed and is_inside_tree():
		_spin_velocity += 2.8
		if _weapon_mount != null:
			if _weapon_pop_tween != null and _weapon_pop_tween.is_valid():
				_weapon_pop_tween.kill()
			_weapon_mount.scale = Vector3(0.62, 0.62, 0.62)
			_weapon_pop_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_weapon_pop_tween.tween_property(_weapon_mount, "scale", Vector3.ONE, 0.32)


func set_map_theme(map_id: String) -> void:
	if map_id == _current_map_id:
		return
	_current_map_id = map_id

	var is_sector02: bool = (map_id == "sector_02")
	var bg_col := Color(0.105882, 0.058824, 0.043137, 1.0) if is_sector02 else Color(0.035294, 0.054902, 0.113725, 1.0)
	var rim_col := Color(0.984314, 0.501961, 0.168627, 1.0) if is_sector02 else Color(0.219608, 0.741176, 0.972549, 1.0)
	var key_col := Color(1.0, 0.909804, 0.823529, 1.0) if is_sector02 else Color(0.94, 0.97, 1.0, 1.0)
	var tile_a := Color(0.105882, 0.070588, 0.058824, 1.0) if is_sector02 else Color(0.054902, 0.082353, 0.141176, 1.0)
	var tile_b := Color(0.141176, 0.094118, 0.07451, 1.0) if is_sector02 else Color(0.07451, 0.113725, 0.188235, 1.0)
	var grid_col := Color(0.75, 0.38, 0.18, 1.0) if is_sector02 else Color(0.180392, 0.443137, 0.721569, 1.0)
	var zone_col := Color(0.75, 0.32, 0.12, 1.0) if is_sector02 else Color(0.12, 0.44, 0.80, 1.0)

	if not is_inside_tree():
		if _world_env != null and _world_env.environment != null:
			_world_env.environment.background_color = bg_col
			_world_env.environment.fog_light_color = bg_col
		if _rim_light != null:
			_rim_light.light_color = rim_col
		if _key_light != null:
			_key_light.light_color = key_col
		if _floor_shader_mat != null:
			_floor_shader_mat.set_shader_parameter("base_color", tile_a)
			_floor_shader_mat.set_shader_parameter("alt_tile_color", tile_b)
			_floor_shader_mat.set_shader_parameter("grid_line_color", grid_col)
			_floor_shader_mat.set_shader_parameter("center_line_color", rim_col)
			_floor_shader_mat.set_shader_parameter("blue_zone_tint", zone_col)
			_floor_shader_mat.set_shader_parameter("orange_zone_tint", zone_col)
		return

	if _theme_tween != null and _theme_tween.is_valid():
		_theme_tween.kill()
	_theme_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _world_env != null and _world_env.environment != null:
		_theme_tween.tween_property(_world_env.environment, "background_color", bg_col, 0.45)
		_theme_tween.tween_property(_world_env.environment, "fog_light_color", bg_col, 0.45)
	if _rim_light != null:
		_theme_tween.tween_property(_rim_light, "light_color", rim_col, 0.45)
	if _key_light != null:
		_theme_tween.tween_property(_key_light, "light_color", key_col, 0.45)
	if _floor_shader_mat != null:
		_theme_tween.tween_property(_floor_shader_mat, "shader_parameter/base_color", tile_a, 0.45)
		_theme_tween.tween_property(_floor_shader_mat, "shader_parameter/alt_tile_color", tile_b, 0.45)
		_theme_tween.tween_property(_floor_shader_mat, "shader_parameter/grid_line_color", grid_col, 0.45)
		_theme_tween.tween_property(_floor_shader_mat, "shader_parameter/center_line_color", rim_col, 0.45)
		_theme_tween.tween_property(_floor_shader_mat, "shader_parameter/blue_zone_tint", zone_col, 0.45)
		_theme_tween.tween_property(_floor_shader_mat, "shader_parameter/orange_zone_tint", zone_col, 0.45)
