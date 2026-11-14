class_name EnergyBlasterData
extends Resource
## تعریف سلاح نظامی تاکتیکی با مدل سه‌بعدی واقعی، آیکون اختصاصی و صدای شلیک.

enum BlasterCategory {
	PULSE_SIDEARM,
	RAPID_SCATTER,
	ARC_CARBINE,
	SHOCK_DASH_BLADE
}

@export var blaster_id: StringName = &"pulse_blaster"
@export var display_name: String = "کاربین M4 تاکتیکی"
@export var category: BlasterCategory = BlasterCategory.ARC_CARBINE
@export_range(5.0, 80.0, 1.0) var energy_damage: float = 28.0
@export_range(0.05, 1.5, 0.01) var pulse_cooldown: float = 0.22
@export_range(10.0, 80.0, 1.0) var projectile_speed: float = 30.0
@export_range(4, 120, 1) var energy_cell_capacity: int = 24
@export_range(0.4, 3.0, 0.05) var recharge_seconds: float = 1.05
@export_range(0.0, 15.0, 0.25) var spread_still_deg: float = 0.7
@export_range(0.0, 25.0, 0.25) var spread_moving_deg: float = 2.8
@export_range(1, 5, 1) var pellets_per_shot: int = 1
@export var projectile_color: Color = Color(1.0, 0.78, 0.30, 1.0)
@export var model_scene_path: String = "res://assets/kenney/weapon/machinegun.glb"
@export var model_scale: float = 1.32
@export var shoot_sfx_path: String = "res://assets/audio/sfx_gun_m4.wav"
@export var icon_path: String = "res://assets/ui/icon_weapon_m4.png"
@export var bolt_scale: Vector3 = Vector3(0.85, 0.85, 1.25)
@export_range(0, 3, 1) var pierce_count: int = 0
@export var arena_credit_cost: int = 0
