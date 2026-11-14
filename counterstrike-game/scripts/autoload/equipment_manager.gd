extends Node
## Offline loadout catalog, unlocks, and selected-slot persistence.

const DATA_DIR := "res://data/equipment"
const DEFAULTS := {"CORE": "field_vest", "MOBILITY": "dash_spring", "UTILITY": "pulse_beacon"}

var catalog: Dictionary = {}


func _ready() -> void:
	_load_catalog()
	_reconcile_loadout()


func _load_catalog() -> void:
	catalog.clear()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("Equipment data directory is missing: %s" % DATA_DIR)
		return
	dir.list_dir_begin()
	var filename := dir.get_next()
	while not filename.is_empty():
		if filename.ends_with(".tres"):
			var resource := load(DATA_DIR.path_join(filename)) as ArenaEquipmentData
			if resource != null and not String(resource.equipment_id).is_empty():
				catalog[String(resource.equipment_id)] = resource
		filename = dir.get_next()
	dir.list_dir_end()


func _reconcile_loadout() -> void:
	for slot_name in DEFAULTS:
		var id := String(SaveManager.equipped_gear.get(slot_name, DEFAULTS[slot_name]))
		if (
			not catalog.has(id)
			or get_item(id).slot != _slot_from_name(slot_name)
			or not is_unlocked(id)
		):
			id = String(DEFAULTS[slot_name])
		SaveManager.equipped_gear[slot_name] = id
	SaveManager.save_settings()


func _slot_from_name(slot_name: String) -> int:
	match slot_name:
		"MOBILITY":
			return ArenaEquipmentData.Slot.MOBILITY
		"UTILITY":
			return ArenaEquipmentData.Slot.UTILITY
		_:
			return ArenaEquipmentData.Slot.CORE


func get_all_items() -> Array[ArenaEquipmentData]:
	var items: Array[ArenaEquipmentData] = []
	for value in catalog.values():
		items.append(value as ArenaEquipmentData)
	items.sort_custom(
		func(a: ArenaEquipmentData, b: ArenaEquipmentData) -> bool:
			if a.slot != b.slot:
				return a.slot < b.slot
			return a.unlock_xp < b.unlock_xp
	)
	return items


func get_item(equipment_id: String) -> ArenaEquipmentData:
	return catalog.get(equipment_id, null) as ArenaEquipmentData


func get_slot_name(slot: int) -> String:
	match slot:
		ArenaEquipmentData.Slot.MOBILITY:
			return "MOBILITY"
		ArenaEquipmentData.Slot.UTILITY:
			return "UTILITY"
		_:
			return "CORE"


func is_unlocked(equipment_id: String) -> bool:
	var item := get_item(equipment_id)
	return item != null and SaveManager.career_xp >= item.unlock_xp


func select_equipment(equipment_id: String) -> bool:
	var item := get_item(equipment_id)
	if item == null or not is_unlocked(equipment_id):
		return false
	var slot_name := get_slot_name(item.slot)
	SaveManager.equipped_gear[slot_name] = equipment_id
	SaveManager.save_settings()
	EventBus.equipment_loadout_changed.emit(slot_name, equipment_id)
	return true


func get_selected(slot: int) -> ArenaEquipmentData:
	var item_id := String(SaveManager.equipped_gear.get(get_slot_name(slot), ""))
	return get_item(item_id)


func get_player_modifiers() -> Dictionary:
	var result := {
		"health_bonus_ratio": 0.0,
		"damage_reduction_ratio": 0.0,
		"move_speed_ratio": 0.0,
		"dash_cooldown_ratio": 0.0,
		"gadget_cooldown_ratio": 0.0
	}
	for slot_name in DEFAULTS:
		var item := get_item(String(SaveManager.equipped_gear.get(slot_name, DEFAULTS[slot_name])))
		if item == null or not is_unlocked(String(item.equipment_id)):
			continue
		result["health_bonus_ratio"] += item.health_bonus_ratio
		result["damage_reduction_ratio"] += item.damage_reduction_ratio
		result["move_speed_ratio"] += item.move_speed_ratio
		result["dash_cooldown_ratio"] += item.dash_cooldown_ratio
		result["gadget_cooldown_ratio"] += item.gadget_cooldown_ratio
	# Stacked passive bonuses are deliberately capped for fairness.
	result["health_bonus_ratio"] = clampf(result["health_bonus_ratio"], -0.15, 0.15)
	result["damage_reduction_ratio"] = clampf(result["damage_reduction_ratio"], 0.0, 0.10)
	result["move_speed_ratio"] = clampf(result["move_speed_ratio"], -0.08, 0.08)
	result["dash_cooldown_ratio"] = clampf(result["dash_cooldown_ratio"], -0.10, 0.10)
	result["gadget_cooldown_ratio"] = clampf(result["gadget_cooldown_ratio"], -0.12, 0.12)
	return result
