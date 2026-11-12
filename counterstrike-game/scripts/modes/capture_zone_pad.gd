class_name CaptureZonePad
extends Area3D
## منطقه قابل تسخیر زمین نبرد (فاز ۲: تشخیص ورود/خروج بازیکن و تغییر نور حلقه).

@export var zone_id: String = "zone_a"
@export var zone_title_fa: String = "منطقه الف (شمال)"
@export var idle_color: Color = Color(0.219608, 0.741176, 0.972549, 0.35)
@export var active_color: Color = Color(0.219608, 0.901961, 0.65098, 0.78)

@onready var _pad_mesh: MeshInstance3D = $PadRingMesh

var _mat: StandardMaterial3D = null
var _player_inside: bool = false


func _ready() -> void:
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


func _on_body_entered(body: Node3D) -> void:
	if body != null and body.is_in_group("player"):
		_player_inside = true
		if _mat != null:
			_mat.albedo_color = active_color
		AudioManager.play_ui_menu(1.18)
		EventBus.player_zone_changed.emit(zone_id, zone_title_fa, true)


func _on_body_exited(body: Node3D) -> void:
	if body != null and body.is_in_group("player"):
		_player_inside = false
		if _mat != null:
			_mat.albedo_color = idle_color
		EventBus.player_zone_changed.emit(zone_id, zone_title_fa, false)
