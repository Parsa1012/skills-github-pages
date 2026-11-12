class_name CaptureZonePad
extends Area3D
## منطقه قابل تسخیر زمین نبرد (فاز ۴: تسخیر تیمی، حالت درگیری، امتیازدهی دوره‌ای و بازخورد بصری).

signal zone_ownership_changed(zone: CaptureZonePad, new_owner_team: int)

@export var zone_id: String = "zone_a"
@export var zone_title_fa: String = "منطقه الف (شمال)"
@export var capture_seconds: float = 4.0
@export var idle_color: Color = Color(0.580392, 0.639216, 0.721569, 0.42)
@export var blue_color: Color = Color(0.219608, 0.741176, 0.972549, 0.85)
@export var orange_color: Color = Color(0.984314, 0.45098, 0.086275, 0.85)
@export var contested_color: Color = Color(0.984314, 0.74902, 0.141176, 0.85)

@onready var _pad_mesh: MeshInstance3D = $PadRingMesh

var owner_team: int = -1 # -1 = خنثی، 0 = آبی، 1 = نارنجی
var _capture_value: float = 0.0 # -1.0 (نارنجی) ... 0.0 (خنثی) ... +1.0 (آبی)
var _mat: StandardMaterial3D = null
var _units_inside: Array[Node3D] = []
var _player_inside: bool = false
var _last_emitted_progress: float = -1.0
var _pulse_time: float = 0.0


func _ready() -> void:
	add_to_group("capture_zones")
	collision_layer = 8
	collision_mask = 2
	if _pad_mesh != null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = idle_color
		_pad_mesh.material_override = _mat

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_owner_team() -> int:
	return owner_team


func _physics_process(delta: float) -> void:
	var blue_alive: int = 0
	var orange_alive: int = 0
	var player_alive_inside: bool = false

	for i in range(_units_inside.size() - 1, -1, -1):
		var unit: Node3D = _units_inside[i]
		if unit == null or not is_instance_valid(unit):
			_units_inside.remove_at(i)
			continue
		var alive: bool = true
		if unit.has_method("is_alive"):
			alive = bool(unit.call("is_alive"))
		if not alive:
			continue
		var tid: Variant = unit.get("team_id")
		if tid == null:
			continue
		if int(tid) == 0:
			blue_alive += 1
		elif int(tid) == 1:
			orange_alive += 1
		if unit.is_in_group("player"):
			player_alive_inside = true

	if _player_inside and not player_alive_inside:
		_player_inside = false
		EventBus.player_zone_changed.emit(zone_id, zone_title_fa, false)
	elif not _player_inside and player_alive_inside:
		_player_inside = true
		EventBus.player_zone_changed.emit(zone_id, zone_title_fa, true)

	var step: float = delta / maxf(capture_seconds, 0.5)
	var contested: bool = (blue_alive > 0 and orange_alive > 0)

	if not contested:
		if blue_alive > 0 and _capture_value < 1.0:
			_capture_value = minf(1.0, _capture_value + step)
			if owner_team == 1 and _capture_value >= 0.0:
				owner_team = -1
				zone_ownership_changed.emit(self, -1)
			if _capture_value >= 1.0 and owner_team != 0:
				owner_team = 0
				zone_ownership_changed.emit(self, 0)
				EventBus.zone_captured.emit(zone_id, 0)
				EventBus.hud_toast_requested.emit("%s به تصرف تیم آبی درآمد!" % zone_title_fa, blue_color)
				AudioManager.play_zone_capture_sfx(1.06)
		elif orange_alive > 0 and _capture_value > -1.0:
			_capture_value = maxf(-1.0, _capture_value - step)
			if owner_team == 0 and _capture_value <= 0.0:
				owner_team = -1
				zone_ownership_changed.emit(self, -1)
			if _capture_value <= -1.0 and owner_team != 1:
				owner_team = 1
				zone_ownership_changed.emit(self, 1)
				EventBus.zone_captured.emit(zone_id, 1)
				EventBus.hud_toast_requested.emit("%s به تصرف تیم نارنجی درآمد!" % zone_title_fa, orange_color)
				AudioManager.play_zone_capture_sfx(0.84)
		elif blue_alive == 0 and orange_alive == 0 and owner_team == -1 and absf(_capture_value) > 0.001:
			_capture_value = move_toward(_capture_value, 0.0, step * 0.35)

	_update_visual_color(contested, delta)

	var abs_prog: float = absf(_capture_value)
	if absf(abs_prog - _last_emitted_progress) >= 0.05:
		_last_emitted_progress = abs_prog
		var dom_team: int = 0 if _capture_value >= 0.0 else 1
		EventBus.zone_capture_progress.emit(zone_id, dom_team, abs_prog)


func _update_visual_color(contested: bool, delta: float) -> void:
	if _mat == null:
		return
	if contested:
		_pulse_time += delta * 8.0
		var a: float = 0.55 + 0.30 * sin(_pulse_time)
		_mat.albedo_color = Color(contested_color.r, contested_color.g, contested_color.b, a)
		if _pad_mesh != null:
			var sc: float = 1.0 + 0.045 * sin(_pulse_time)
			_pad_mesh.scale = Vector3(sc, 1.0, sc)
		return

	if _pad_mesh != null:
		if owner_team >= 0:
			_pulse_time += delta * 3.0
			var sc_own: float = 1.0 + 0.02 * sin(_pulse_time)
			_pad_mesh.scale = Vector3(sc_own, 1.0, sc_own)
		else:
			_pad_mesh.scale = Vector3.ONE

	if _capture_value >= 0.0:
		_mat.albedo_color = idle_color.lerp(blue_color, _capture_value)
	else:
		_mat.albedo_color = idle_color.lerp(orange_color, -_capture_value)


func _on_body_entered(body: Node3D) -> void:
	if body == null:
		return
	if body.get("team_id") == null:
		return
	if not _units_inside.has(body):
		_units_inside.append(body)
	if body.is_in_group("player"):
		var alive: bool = not body.has_method("is_alive") or bool(body.call("is_alive"))
		if alive and not _player_inside:
			_player_inside = true
			AudioManager.play_ui_menu(1.18)
			EventBus.player_zone_changed.emit(zone_id, zone_title_fa, true)


func _on_body_exited(body: Node3D) -> void:
	if body == null:
		return
	_units_inside.erase(body)
	if body.is_in_group("player") and _player_inside:
		_player_inside = false
		EventBus.player_zone_changed.emit(zone_id, zone_title_fa, false)
