class_name EquipmentLoadoutPanel
extends Control
## Responsive touchscreen-first loadout picker; all content is sourced from reusable resources.

var _slot: int = ArenaEquipmentData.Slot.CORE
var _selected_id: String = ""
var _items_box: VBoxContainer
var _title: Label
var _icon: TextureRect
var _description: Label
var _stats: Label
var _select_button: Button
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	refresh()


func open() -> void:
	visible = true
	_selected_id = ""
	refresh()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_top = 0.06
	panel.anchor_right = 0.95
	panel.anchor_bottom = 0.94
	panel.custom_minimum_size = Vector2(0, 390)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var heading := Label.new()
	heading.text = "تجهیزات میدان  •  بارگذاری آفلاین"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 20)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)
	var close := Button.new()
	close.text = "بستن"
	close.custom_minimum_size = Vector2(56, 48)
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for entry in [
		["هسته", ArenaEquipmentData.Slot.CORE],
		["تحرک", ArenaEquipmentData.Slot.MOBILITY],
		["ابزار", ArenaEquipmentData.Slot.UTILITY]
	]:
		var tab := Button.new()
		tab.text = String(entry[0])
		tab.custom_minimum_size = Vector2(92, 48)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_set_slot.bind(int(entry[1])))
		tabs.add_child(tab)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	root.add_child(content)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_items_box = VBoxContainer.new()
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_items_box)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	content.add_child(details)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(76, 76)
	_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	details.add_child(_icon)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_title)
	_description = Label.new()
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_description)
	_stats = Label.new()
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_stats)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_status)
	_select_button = Button.new()
	_select_button.text = "انتخاب"
	_select_button.custom_minimum_size = Vector2(0, 52)
	_select_button.pressed.connect(_equip_selected)
	details.add_child(_select_button)


func _set_slot(slot: int) -> void:
	_slot = slot
	refresh()


func refresh() -> void:
	if _items_box == null:
		return
	for child in _items_box.get_children():
		child.queue_free()
	var items := EquipmentManager.get_all_items()
	var slot_items: Array[ArenaEquipmentData] = []
	for item in items:
		if item.slot == _slot:
			slot_items.append(item)
	if slot_items.is_empty():
		_title.text = "تجهیزی برای این بخش موجود نیست"
		return
	var current_selection := EquipmentManager.get_item(_selected_id)
	if current_selection == null or current_selection.slot != _slot:
		var equipped_in_slot := EquipmentManager.get_selected(_slot)
		_selected_id = (
			String(equipped_in_slot.equipment_id)
			if equipped_in_slot != null
			else String(slot_items[0].equipment_id)
		)
	for item in slot_items:
		var id := String(item.equipment_id)
		var unlocked := EquipmentManager.is_unlocked(id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = load(item.icon_path) as Texture2D if ResourceLoader.exists(item.icon_path) else null
		button.icon_max_width = 36
		button.expand_icon = true
		button.text = (
			("✓  " if id == _selected_id else "")
			+ item.display_name
			+ ("" if unlocked else "  🔒 %d XP" % item.unlock_xp)
		)
		button.disabled = false
		button.pressed.connect(_choose_item.bind(id))
		_items_box.add_child(button)
	_show_item(_selected_id)


func _choose_item(item_id: String) -> void:
	_selected_id = item_id
	refresh()


func _show_item(item_id: String) -> void:
	var item := EquipmentManager.get_item(item_id)
	if item == null:
		return
	_title.text = item.display_name
	_description.text = item.description
	_icon.texture = (
		load(item.icon_path) as Texture2D if ResourceLoader.exists(item.icon_path) else null
	)
	var stats: Array[String] = []
	if item.health_bonus_ratio != 0.0:
		stats.append("جان %+.0f%%" % (item.health_bonus_ratio * 100.0))
	if item.damage_reduction_ratio != 0.0:
		stats.append("مقاومت برخورد %+.0f%%" % (item.damage_reduction_ratio * 100.0))
	if item.move_speed_ratio != 0.0:
		stats.append("سرعت حرکت %+.0f%%" % (item.move_speed_ratio * 100.0))
	if item.dash_cooldown_ratio != 0.0:
		stats.append("بازیابی جهش %+.0f%%" % (-item.dash_cooldown_ratio * 100.0))
	if item.gadget_cooldown_ratio != 0.0:
		stats.append("بازیابی ابزار %+.0f%%" % (-item.gadget_cooldown_ratio * 100.0))
	_stats.text = (
		"ویژگی‌ها: %s\nرتبه تعادل: %d از ۱۰۰"
		% [
			PackedStringArray(stats).join(" • ") if not stats.is_empty() else "تزئینی",
			item.power_rating
		]
	)
	var unlocked := EquipmentManager.is_unlocked(item_id)
	var current := EquipmentManager.get_selected(_slot)
	var is_equipped := current != null and String(current.equipment_id) == item_id
	_status.text = (
		"تجهیز شده"
		if is_equipped
		else (
			"آزاد • %d XP" % SaveManager.career_xp
			if unlocked
			else "آزادسازی در %d XP • XP شما: %d" % [item.unlock_xp, SaveManager.career_xp]
		)
	)
	_select_button.disabled = not unlocked or is_equipped
	_select_button.text = "تجهیز شده" if is_equipped else ("انتخاب" if unlocked else "قفل")


func _equip_selected() -> void:
	if EquipmentManager.select_equipment(_selected_id):
		AudioManager.play_ui_click()
		refresh()
