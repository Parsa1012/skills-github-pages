class_name VisualFxUtils
extends Object
## ابزارهای بهینه‌سازی گرافیک ۶۰ فریم، متریال‌های PBR و تجهیز سربازان نظامی واقعی با کلاه‌خود و جلیقه ضدگلوله.


static func make_unshaded_hdr_material(base_color: Color, alpha: float = 1.0, hdr_boost: float = 1.35) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(
		base_color.r * hdr_boost,
		base_color.g * hdr_boost,
		base_color.b * hdr_boost,
		alpha
	)
	return mat


static func make_emissive_pbr_material(base_color: Color, emission_color: Color, emission_energy: float = 1.45, metallic: float = 0.35, roughness: float = 0.45) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.albedo_color = base_color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.emission_enabled = true
	mat.emission = emission_color
	mat.emission_energy_multiplier = emission_energy
	return mat


static func make_matte_military_material(albedo: Color, metallic: float = 0.12, roughness: float = 0.72) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.albedo_color = albedo
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


static func patch_kenney_soldier_animations(anim_player: AnimationPlayer) -> void:
	if anim_player == null:
		return

	# در مدل‌های کاراکتر Kenney، دست راست در حالت holding-right رو به جلو قرار می‌گیرد.
	var hold_rot: Variant = null
	var has_hold: bool = false
	if anim_player.has_animation("holding-right"):
		var hold_anim: Animation = anim_player.get_animation("holding-right")
		if hold_anim != null:
			for t in hold_anim.get_track_count():
				var p_str: String = str(hold_anim.track_get_path(t))
				if "arm-right" in p_str and p_str.ends_with(":rotation") and hold_anim.track_get_key_count(t) > 0:
					hold_rot = hold_anim.track_get_key_value(t, 0)
					has_hold = true
					break

	for anim_name in ["idle", "walk", "sprint"]:
		if anim_player.has_animation(anim_name):
			var anim: Animation = anim_player.get_animation(anim_name)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
				if has_hold:
					for t in anim.get_track_count():
						var tp: String = str(anim.track_get_path(t))
						if "arm-right" in tp and tp.ends_with(":rotation"):
							while anim.track_get_key_count(t) > 0:
								anim.track_remove_key(t, 0)
							anim.track_insert_key(t, 0.0, hold_rot)

	if anim_player.has_animation("die"):
		var die_anim: Animation = anim_player.get_animation("die")
		if die_anim != null:
			die_anim.loop_mode = Animation.LOOP_NONE

	# انیمیشن idle پیش‌فرض گاهی فاقد ترک‌های پا/ریشه است؛ از static کپی می‌کنیم تا پاها قفل نمانند.
	if anim_player.has_animation("idle") and anim_player.has_animation("static"):
		var idle_anim: Animation = anim_player.get_animation("idle")
		var static_anim: Animation = anim_player.get_animation("static")
		if idle_anim != null and static_anim != null:
			var existing_paths: Dictionary = {}
			for t in idle_anim.get_track_count():
				existing_paths[str(idle_anim.track_get_path(t))] = true
			for st in static_anim.get_track_count():
				var path_str: String = str(static_anim.track_get_path(st))
				if not existing_paths.has(path_str) and (
					"leg-" in path_str or path_str.ends_with(":position") or path_str.ends_with("root")
				):
					if static_anim.track_get_key_count(st) > 0:
						var new_t: int = idle_anim.add_track(static_anim.track_get_type(st))
						idle_anim.track_set_path(new_t, static_anim.track_get_path(st))
						idle_anim.track_set_interpolation_type(new_t, static_anim.track_get_interpolation_type(st))
						idle_anim.track_insert_key(new_t, 0.0, static_anim.track_get_key_value(st, 0))


static func _apply_skin_pbr_recursive(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var mat := StandardMaterial3D.new()
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
			mat.roughness = 0.78
			mat.metallic = 0.06
			if tex != null:
				mat.albedo_texture = tex
			mi.material_override = mat
	for ch in node.get_children():
		_apply_skin_pbr_recursive(ch, tex)


static func _add_box_gear(parent: Node3D, gear_name: String, box_size: Vector3, pos: Vector3, mat: Material, cast_shadows: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = gear_name
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func equip_military_soldier(
	soldier_root: Node3D,
	skin_path: String,
	team_id: int,
	is_heavy: bool = false,
	weapon_scene_path: String = "",
	weapon_scale: float = 1.25
) -> void:
	if soldier_root == null:
		return

	# ۱. جایگزینی متریال Unlit با متریال سایه‌پذیر PBR + لباس استتار تاکتیکی
	var tex: Texture2D = null
	if not skin_path.is_empty() and ResourceLoader.exists(skin_path):
		var loaded: Resource = ResourceLoader.load(skin_path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	_apply_skin_pbr_recursive(soldier_root, tex)

	if soldier_root.get_node_or_null("MilitaryGearMarker") != null:
		return
	var marker := Node3D.new()
	marker.name = "MilitaryGearMarker"
	soldier_root.add_child(marker)

	var helmet_col: Color = Color(0.14, 0.21, 0.30, 1.0) if team_id == 0 else (Color(0.16, 0.17, 0.20, 1.0) if is_heavy else Color(0.32, 0.29, 0.22, 1.0))
	var vest_col: Color = Color(0.11, 0.15, 0.21, 1.0) if team_id == 0 else (Color(0.14, 0.14, 0.17, 1.0) if is_heavy else Color(0.24, 0.21, 0.17, 1.0))
	var trim_col: Color = Color(0.219608, 0.741176, 0.972549, 1.0) if team_id == 0 else (Color(0.937255, 0.266667, 0.266667, 1.0) if is_heavy else Color(0.984314, 0.45098, 0.086275, 1.0))

	var helmet_mat := make_matte_military_material(helmet_col, 0.18, 0.62)
	var vest_mat := make_matte_military_material(vest_col, 0.14, 0.76)
	var pouch_mat := make_matte_military_material(vest_col.darkened(0.22), 0.10, 0.80)
	var goggle_mat := make_emissive_pbr_material(Color(0.06, 0.09, 0.13, 1.0), trim_col, 1.15, 0.65, 0.18)
	var strap_mat := make_matte_military_material(trim_col, 0.15, 0.65)

	# ۲. کلاه‌خود نظامی کولار + عینک تاکتیکی روی استخوان head (مقیاس داخلی head برابر 0.1 است)
	var head_node: Node3D = soldier_root.find_child("head", true, false) as Node3D
	if head_node != null:
		_add_box_gear(head_node, "KevlarHelmetDome", Vector3(9.2, 4.1, 9.4), Vector3(0.0, 6.45, -0.15), helmet_mat, false)
		_add_box_gear(head_node, "KevlarHelmetBrim", Vector3(9.4, 1.1, 2.0), Vector3(0.0, 5.15, 4.15), helmet_mat, false)
		_add_box_gear(head_node, "HelmetRailLeft", Vector3(0.9, 2.8, 4.6), Vector3(4.55, 4.7, -0.3), vest_mat, false)
		_add_box_gear(head_node, "HelmetRailRight", Vector3(0.9, 2.8, 4.6), Vector3(-4.55, 4.7, -0.3), vest_mat, false)
		_add_box_gear(head_node, "NvgMount", Vector3(1.9, 1.7, 1.0), Vector3(0.0, 6.1, 4.75), pouch_mat, false)
		_add_box_gear(head_node, "TacticalGoggles", Vector3(8.5, 1.75, 0.9), Vector3(0.0, 4.05, 4.28), goggle_mat, false)
		if is_heavy:
			_add_box_gear(head_node, "HeavyFaceShield", Vector3(8.9, 2.4, 0.8), Vector3(0.0, 1.9, 4.25), helmet_mat, false)

	# ۳. جلیقه ضدگلوله + جیب خشاب + کوله‌پشتی تاکتیکی روی استخوان torso
	var torso_node: Node3D = soldier_root.find_child("torso", true, false) as Node3D
	if torso_node != null:
		_add_box_gear(torso_node, "PlateCarrierVest", Vector3(0.90, 0.64, 0.70), Vector3(0.0, 0.82, 0.0), vest_mat, false)
		_add_box_gear(torso_node, "MagPouchesFront", Vector3(0.68, 0.26, 0.14), Vector3(0.0, 0.68, 0.37), pouch_mat, false)
		_add_box_gear(torso_node, "TeamPatchFront", Vector3(0.24, 0.10, 0.06), Vector3(0.20, 0.98, 0.36), strap_mat, false)
		_add_box_gear(torso_node, "TacticalBackpack", Vector3(0.62, 0.56, 0.25), Vector3(0.0, 0.80, -0.40), pouch_mat, false)

		if not weapon_scene_path.is_empty() and ResourceLoader.exists(weapon_scene_path):
			var w_packed: Resource = ResourceLoader.load(weapon_scene_path)
			if w_packed is PackedScene:
				var w_inst: Node = (w_packed as PackedScene).instantiate()
				if w_inst is Node3D:
					var w3d := w_inst as Node3D
					w3d.name = "SoldierRifle"
					w3d.position = Vector3(-0.58, 1.05, 0.72)
					w3d.scale = Vector3(weapon_scale, weapon_scale, weapon_scale)
					torso_node.add_child(w3d)

	# ۴. زره محافظ شانه روی دست‌های چپ و راست
	var arm_l: Node3D = soldier_root.find_child("arm-left", true, false) as Node3D
	if arm_l != null:
		_add_box_gear(arm_l, "ShoulderPadL", Vector3(0.46, 0.30, 0.48), Vector3(0.21, -0.10, 0.0), helmet_mat, false)
	var arm_r: Node3D = soldier_root.find_child("arm-right", true, false) as Node3D
	if arm_r != null:
		_add_box_gear(arm_r, "ShoulderPadR", Vector3(0.46, 0.30, 0.48), Vector3(-0.21, -0.10, 0.0), helmet_mat, false)


static func configure_environment_quality(env: Environment, preset_name: String) -> void:
	if env == null:
		return
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.08
	env.tonemap_white = 4.5
	match preset_name:
		"low":
			# بیشترین سرعت روی گوشی‌های میان‌رده و اقتصادی (حذف کامل پس‌پردازش بلوم و مه)
			env.glow_enabled = false
			env.fog_enabled = false
		"medium":
			# بهینه‌سازی ویژه گلکسی A32: ۶۰ فریم پایدار بدون بلوم تمام‌صفحه سنگین در GL Compatibility
			env.glow_enabled = false
			env.fog_enabled = false
		_:
			env.glow_enabled = true
			env.glow_intensity = 0.56
			env.glow_bloom = 0.16
			env.glow_hdr_threshold = 0.94
			env.fog_enabled = true


static func apply_environment_quality(world_env: WorldEnvironment, preset_name: String, _is_warm_sector: bool = false) -> void:
	if world_env == null or world_env.environment == null:
		return
	configure_environment_quality(world_env.environment, preset_name)
