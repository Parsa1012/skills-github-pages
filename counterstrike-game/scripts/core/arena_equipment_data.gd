class_name ArenaEquipmentData
extends Resource
## Reusable, offline data resource for fictional arcade loadout pieces.

enum Slot { CORE, MOBILITY, UTILITY }

@export var equipment_id: StringName = &"field_vest"
@export var display_name: String = "Field Vest"
@export_multiline var description: String = "A balanced, fictional arena support module."
@export var slot: Slot = Slot.CORE
@export var icon_path: String = "res://assets/ui/equipment/field_vest.svg"
@export_range(0, 5000, 50) var unlock_xp: int = 0
@export_range(-0.15, 0.15, 0.01) var health_bonus_ratio: float = 0.0
@export_range(-0.10, 0.10, 0.01) var damage_reduction_ratio: float = 0.0
@export_range(-0.08, 0.08, 0.01) var move_speed_ratio: float = 0.0
@export_range(-0.15, 0.15, 0.01) var dash_cooldown_ratio: float = 0.0
@export_range(-0.15, 0.15, 0.01) var gadget_cooldown_ratio: float = 0.0
@export_range(0, 100, 1) var power_rating: int = 50
