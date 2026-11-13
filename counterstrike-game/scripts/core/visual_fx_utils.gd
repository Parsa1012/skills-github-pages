class_name VisualFxUtils
extends Object
## ابزارهای مشترک بهینه‌سازی گرافیک، شیدرها، متریال‌های HDR و انیمیشن مدل‌های Kenney.


static func make_unshaded_hdr_material(base_color: Color, alpha: float = 1.0, hdr_boost: float = 1.45) -> StandardMaterial3D:
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


static func make_emissive_pbr_material(base_color: Color, emission_color: Color, emission_energy: float = 1.6, metallic: float = 0.35, roughness: float = 0.42) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.emission_enabled = true
	mat.emission = emission_color
	mat.emission_energy_multiplier = emission_energy
	return mat


static func patch_kenney_soldier_animations(anim_player: AnimationPlayer) -> void:
	if anim_player == null:
		return
	for anim_name in ["idle", "walk", "sprint"]:
		if anim_player.has_animation(anim_name):
			var anim: Animation = anim_player.get_animation(anim_name)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
	if anim_player.has_animation("die"):
		var die_anim: Animation = anim_player.get_animation("die")
		if die_anim != null:
			die_anim.loop_mode = Animation.LOOP_NONE

	# انیمیشن idle پیش‌فرض Kenney فاقد ترک‌های پا/ریشه است؛ از static کپی می‌کنیم تا پاها قفل نمانند.
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


static func configure_environment_quality(env: Environment, preset_name: String) -> void:
	if env == null:
		return
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 4.5
	match preset_name:
		"low":
			env.glow_enabled = false
			env.fog_enabled = false
		"medium":
			env.glow_enabled = true
			env.glow_intensity = 0.56
			env.glow_bloom = 0.18
			env.glow_hdr_threshold = 0.92
			env.fog_enabled = true
		_:
			env.glow_enabled = true
			env.glow_intensity = 0.72
			env.glow_bloom = 0.25
			env.glow_hdr_threshold = 0.90
			env.fog_enabled = true


static func apply_environment_quality(world_env: WorldEnvironment, preset_name: String, _is_warm_sector: bool = false) -> void:
	if world_env == null or world_env.environment == null:
		return
	configure_environment_quality(world_env.environment, preset_name)
