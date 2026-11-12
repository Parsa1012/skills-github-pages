class_name EnergyBlasterData
extends Resource
## تعریف سلاح انرژی آرکید خیالی با اتصال مستقیم به مدل سه‌بعدی و افکت صوتی Kenney.

enum BlasterCategory {
	PULSE_SIDEARM,
	RAPID_SCATTER,
	ARC_CARBINE,
	SHOCK_DASH_BLADE
}

@export var blaster_id: StringName = &"pulse_carbine"
@export var display_name: String = "پالس بلاستر"
@export var category: BlasterCategory = BlasterCategory.ARC_CARBINE
@export_range(5.0, 80.0, 1.0) var energy_damage: float = 25.0
@export_range(0.05, 1.5, 0.01) var pulse_cooldown: float = 0.22
@export_range(10.0, 80.0, 1.0) var projectile_speed: float = 26.0
@export_range(4, 120, 1) var energy_cell_capacity: int = 16
@export_range(0.4, 3.0, 0.05) var recharge_seconds: float = 1.1
@export_range(0.0, 15.0, 0.25) var spread_still_deg: float = 1.0
@export_range(0.0, 25.0, 0.25) var spread_moving_deg: float = 3.5
@export_range(1, 5, 1) var pellets_per_shot: int = 1
@export var projectile_color: Color = Color(0.22, 0.78, 1.0, 1.0)
@export var model_scene_path: String = "res://assets/kenney/fps/blaster.glb"
@export var model_scale: float = 0.46
@export var shoot_sfx_path: String = "res://assets/kenney/audio/blaster.ogg"
@export var arena_credit_cost: int = 0
