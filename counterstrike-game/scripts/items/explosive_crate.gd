class_name ExplosiveCrate
extends StaticBody3D
## جعبه انرژی قابل انفجار در میدان نبرد با آسیب منطقه‌ای، واکنش زنجیره‌ای و بازسازی خودکار.

@export var max_hp: float = 45.0
@export var blast_radius: float = 3.85
@export var blast_damage: float = 55.0
@export var respawn_seconds: float = 18.0

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _visual_root: Node3D = $VisualRoot
@onready var _band_mesh: MeshInstance3D = $VisualRoot/WarningBandMesh

var team_id: int = -1 # خنثی — قابل هدف‌گیری توسط هر دو تیم
var _hp: float = 45.0
var _intact: bool = true
var _respawn_timer: float = 0.0
var _pulse_time: float = 0.0
var _hit_flash_timer: float = 0.0
var _band_mat: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("explosive_crates")
	collision_layer = 1 | 2
	collision_mask = 0
	_hp = max_hp
	if _band_mesh != null:
		_band_mat = StandardMaterial3D.new()
		_band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_band_mat.albedo_color = Color(0.984314, 0.45098, 0.086275, 1.0)
		_band_mesh.material_override = _band_mat


func is_intact() -> bool:
	return _intact


func is_alive() -> bool:
	return _intact


func _process(delta: float) -> void:
	if not _intact:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn_crate()
		return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)

	var low_hp: bool = (_hp <= max_hp * 0.55)
	_pulse_time += delta * (12.0 if low_hp else 4.0)
	if _band_mat != null:
		if _hit_flash_timer > 0.0:
			_band_mat.albedo_color = Color(1.0, 0.96, 0.72, 1.0)
		else:
			var t: float = 0.5 + 0.5 * sin(_pulse_time)
			var c_idle := Color(0.984314, 0.45098, 0.086275, 1.0)
			var c_hot := Color(0.937255, 0.266667, 0.266667, 1.0)
			_band_mat.albedo_color = c_idle.lerp(c_hot, t if low_hp else t * 0.35)


func take_damage(amount: float, attacker_team: int = 0, from_player: bool = false) -> void:
	if not _intact:
		return
	_hit_flash_timer = 0.08
	_hp = maxf(_hp - amount, 0.0)
	if _hp <= 0.0:
		_detonate(attacker_team, from_player)


func _detonate(attacker_team: int, from_player: bool) -> void:
	if not _intact:
		return
	_intact = false
	_respawn_timer = respawn_seconds
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	if _visual_root != null:
		_visual_root.visible = false

	var origin: Vector3 = global_position
	AudioManager.play_bomb_explode_sfx()
	EventBus.camera_trauma_requested.emit(0.32)
	EventBus.crate_exploded.emit(origin)

	var target_parent: Node = get_tree().current_scene if get_tree() != null else get_parent()
	var flash: Node = PoolManager.acquire(ImpactFlash.POOL_ID, target_parent)
	if flash is ImpactFlash:
		(flash as ImpactFlash).trigger(origin + Vector3(0.0, 0.65, 0.0), Color(0.984314, 0.45098, 0.086275, 1.0), 3.7, 0.25)

	var any_enemy_hit: bool = false
	var any_kill: bool = false
	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("arena_bots"))
	candidates.append_array(get_tree().get_nodes_in_group("player"))
	candidates.append_array(get_tree().get_nodes_in_group("explosive_crates"))

	for node in candidates:
		if node == self or node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		var target := node as Node3D
		if target.has_method("is_alive") and not bool(target.call("is_alive")):
			continue
		var dist: float = Vector2(target.global_position.x - origin.x, target.global_position.z - origin.z).length()
		if dist > blast_radius:
			continue

		var falloff: float = lerpf(1.0, 0.45, clampf(dist / blast_radius, 0.0, 1.0))
		if target is ExplosiveCrate:
			(target as ExplosiveCrate).take_damage(blast_damage, attacker_team, from_player)
			continue

		var tid: Variant = target.get("team_id")
		var same_team: bool = (tid != null and int(tid) == attacker_team)
		var dmg: float = blast_damage * falloff * (0.45 if same_team else 1.0)
		var credit_team: int = (1 - int(tid)) if (same_team and tid != null) else attacker_team

		if target is ArenaBot:
			(target as ArenaBot).take_damage(dmg, credit_team, from_player and not same_team)
		elif target is PlayerController:
			(target as PlayerController).take_damage(dmg, credit_team, origin)

		if not same_team:
			any_enemy_hit = true
			if target.has_method("is_alive") and not bool(target.call("is_alive")):
				any_kill = true

	if from_player and any_enemy_hit:
		AudioManager.play_hitmarker_sfx(any_kill)
		EventBus.enemy_hit_confirmed.emit(blast_damage, any_kill)


func _respawn_crate() -> void:
	_hp = max_hp
	_intact = true
	_hit_flash_timer = 0.0
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", false)
	if _visual_root != null:
		_visual_root.visible = true
