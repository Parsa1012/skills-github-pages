class_name EnergyBlasterData
extends Resource
## Fictional arcade energy-projectile launcher definition (implemented in Phase 3).

enum BlasterCategory {
	PULSE_SIDEARM,
	RAPID_SCATTER,
	ARC_CARBINE,
	SHOCK_DASH_BLADE
}

@export var blaster_id: StringName = &"pulse_carbine"
@export var display_name: String = "Pulse Carbine"
@export var category: BlasterCategory = BlasterCategory.ARC_CARBINE
@export_range(5.0, 80.0, 1.0) var energy_damage: float = 22.0
@export_range(0.05, 1.5, 0.01) var pulse_cooldown: float = 0.14
@export_range(10.0, 80.0, 1.0) var projectile_speed: float = 38.0
@export_range(4, 120, 1) var energy_cell_capacity: int = 24
@export_range(0.4, 3.0, 0.05) var recharge_seconds: float = 1.25
@export_range(0.0, 15.0, 0.25) var spread_still_deg: float = 1.0
@export_range(0.0, 25.0, 0.25) var spread_moving_deg: float = 4.5
@export var projectile_color: Color = Color(0.22, 0.78, 1.0, 1.0)
@export var arena_credit_cost: int = 1200
