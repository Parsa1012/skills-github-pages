extends Node
## تست خودکار End-to-End برای بررسی کامل نسخه ۰.۱۲ «کانتر آرنا» در Godot 4.3.

var _failures: Array[String] = []
var _step: int = -1
var _wait_frames: int = 2
var _zone_entered_seen: bool = false
var _tested_orange_bot_name: String = ""
var _zone_progress_before: float = 0.0
var _kill_feed_seen: bool = false
var _hit_dir_seen: bool = false
var _crate_exploded_seen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_start_qa")


func _start_qa() -> void:
	print("[QA] Starting automated runtime QA (Phase 12 - Counter Arena)...")
	if get_parent() != get_tree().root:
		reparent(get_tree().root)
	get_tree().current_scene = null
	EventBus.player_zone_changed.connect(_on_zone_changed)
	EventBus.kill_feed_event.connect(_on_kill_feed)
	EventBus.player_damaged_direction.connect(_on_hit_dir)
	EventBus.crate_exploded.connect(_on_crate_exploded)
	var err: Error = get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	_assert(err == OK, "MainMenu load failed: %d" % err)
	_step = 0
	_wait_frames = 4


func _on_zone_changed(_zone_id: String, _title: String, inside: bool) -> void:
	if inside:
		_zone_entered_seen = true


func _on_kill_feed(_killer: String, _victim: String, _team: int) -> void:
	_kill_feed_seen = true


func _on_hit_dir(_angle_rad: float) -> void:
	_hit_dir_seen = true


func _on_crate_exploded(_world_pos: Vector3) -> void:
	_crate_exploded_seen = true


func _make_touch(control: Control, touch_id: int, local_position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = touch_id
	event.pressed = pressed
	event.position = control.get_global_transform_with_canvas() * local_position
	return event


func _run_movement_camera_qa(player: PlayerController, hud: Node, arena: Node) -> void:
	var tree := get_tree()
	var movement_stick := hud.get_node_or_null("BottomSafeMargin/TouchControlsRow/LeftMoveStick") as VirtualJoystick
	var aim_stick := hud.get_node_or_null("BottomSafeMargin/TouchControlsRow/RightZoneOverlay/RightAimStick") as VirtualJoystick
	var action_grid := hud.get_node_or_null("BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow") as GridContainer
	var camera_rig := arena.get_node_or_null("ArenaCameraRig") as ArenaCameraRig
	var game_camera := camera_rig.get_node_or_null("CameraYawPivot/CameraPitchPivot/Camera3D") as Camera3D if camera_rig != null else null
	_assert(movement_stick != null and aim_stick != null, "Movement/aim joysticks missing")
	_assert(action_grid != null and action_grid.columns == 4, "Action controls grid missing/default layout is incorrect")
	_assert(game_camera != null and game_camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Gameplay camera is not orthographic")

	var original_viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var safe_pad := {"left": 16.0, "right": 16.0, "top": 12.0, "bottom": 12.0}
	for viewport_size in [Vector2(720.0, 1280.0), Vector2(800.0, 600.0), Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		hud.call("_apply_responsive_touch_layout", viewport_size, safe_pad)
		if action_grid != null:
			_assert(action_grid.columns == (2 if viewport_size.x < 900.0 else 4), "Touch action layout failed responsive width %s" % str(viewport_size))
			for action in action_grid.get_children():
				_assert((action as Control).custom_minimum_size.y >= 48.0, "Responsive touch target fell below 48px")
	hud.call("_apply_responsive_touch_layout", original_viewport_size, safe_pad)
	await tree.process_frame

	if camera_rig != null:
		for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0), Vector2(720.0, 1280.0), Vector2(800.0, 600.0)]:
			camera_rig.configure_for_viewport(viewport_size)
			var extents: Vector2 = camera_rig.get_camera_ground_extents()
			var half_bounds: Vector2 = (camera_rig.bounds_max - camera_rig.bounds_min) * 0.5
			_assert(camera_rig.get_orthographic_size() > 0.0, "Orthographic size invalid at viewport %s" % str(viewport_size))
			_assert(extents.x <= half_bounds.x + 0.1 and extents.y <= half_bounds.y + 0.1, "Camera view escapes map bounds at viewport %s" % str(viewport_size))
			var edge_focus: Vector3 = camera_rig._clamp_focus(Vector3(100.0, 1.0, -100.0))
			_assert(edge_focus.x <= camera_rig.bounds_max.x - extents.x + 0.1 and edge_focus.z >= camera_rig.bounds_min.y + extents.y - 0.1, "Camera did not clamp to map bounds")
			if get_viewport() != null:
				camera_rig.configure_for_viewport(get_viewport().get_visible_rect().size)

	if movement_stick != null and aim_stick != null:
		var left_local: Vector2 = movement_stick.size * 0.5
		var right_local: Vector2 = aim_stick.size * 0.5
		movement_stick._input(_make_touch(movement_stick, 1, left_local, true))
		aim_stick._input(_make_touch(aim_stick, 2, right_local, true))
		var drag := InputEventScreenDrag.new()
		drag.index = 1
		drag.position = movement_stick.get_global_transform_with_canvas() * (left_local + Vector2(36.0, 0.0))
		movement_stick._input(drag)
		_assert(movement_stick.is_active and movement_stick.output_vector.x > 0.2, "Touch joystick did not respond to drag input")
		_assert(aim_stick.is_active, "A second finger could not independently engage the aim joystick")
		movement_stick._input(_make_touch(movement_stick, 1, left_local, false))
		_assert(aim_stick.is_active, "Releasing the movement finger incorrectly released the aim finger")
		aim_stick._input(_make_touch(aim_stick, 2, right_local, false))
		var action_button := action_grid.get_child(0) as Control if action_grid != null else null
		if action_button != null:
			var action_center: Vector2 = action_button.get_global_rect().get_center()
			var action_touch := InputEventScreenTouch.new()
			action_touch.index = 3
			action_touch.pressed = true
			action_touch.position = action_center
			aim_stick._input(action_touch)
			_assert(not aim_stick.is_active, "Aim joystick captured a touch belonging to an action button")
			aim_stick._input(_make_touch(aim_stick, 3, right_local, false))

	var bots: Array[Node] = tree.get_nodes_in_group("arena_bots")
	var bot_physics_states: Array[bool] = []
	for bot in bots:
		bot_physics_states.append(bot.is_physics_processing())
		bot.set_physics_process(false)
	var original_position: Vector3 = player.global_position
	var movement_origin := Vector3(0.0, 0.02, 5.2)
	var directions: Array[Vector2] = [
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2(1.0, 1.0).normalized(), Vector2(-1.0, 1.0).normalized(),
		Vector2(1.0, -1.0).normalized(), Vector2(-1.0, -1.0).normalized()
	]
	for direction in directions:
		player.global_position = movement_origin
		player.velocity = Vector3.ZERO
		player._move_vel = Vector3.ZERO
		player._knockback_vel = Vector3.ZERO
		movement_stick.output_vector = direction
		await tree.physics_frame
		var start_xz := Vector2(player.global_position.x, player.global_position.z)
		for _frame in 12:
			await tree.physics_frame
		var displacement := Vector2(player.global_position.x, player.global_position.z) - start_xz
		var expected := Vector2(direction.x, direction.y)
		_assert(displacement.dot(expected) > 0.25, "Player failed movement direction %s (moved %s)" % [str(direction), str(displacement)])
		_assert(displacement.length() < 3.5, "Diagonal/cardinal movement exceeded expected speed cap")
	movement_stick.output_vector = Vector2(0.65, 0.0)
	for _frame in 20:
		await tree.physics_frame
	_assert(player._anim_player != null and player._anim_player.current_animation in ["run", "sprint"], "Running animation state did not activate")
	movement_stick.output_vector = Vector2.ZERO
	for _frame in 20:
		await tree.physics_frame
	_assert(player._anim_player != null and player._anim_player.current_animation == "idle", "Idle animation state did not restore after releasing movement")

	var wall_tests: Array[Dictionary] = [
		{"origin": Vector3(-13.2, 0.02, 0.0), "input": Vector2.LEFT, "axis": 0, "min": -14.95, "max": -13.2},
		{"origin": Vector3(13.2, 0.02, 0.0), "input": Vector2.RIGHT, "axis": 0, "min": 13.2, "max": 14.95},
		{"origin": Vector3(0.0, 0.02, -9.0), "input": Vector2.UP, "axis": 1, "min": -10.95, "max": -9.0},
		{"origin": Vector3(0.0, 0.02, 9.0), "input": Vector2.DOWN, "axis": 1, "min": 9.0, "max": 10.95}
	]
	for test_case in wall_tests:
		player.global_position = test_case["origin"]
		player.velocity = Vector3.ZERO
		player._move_vel = Vector3.ZERO
		player._knockback_vel = Vector3.ZERO
		movement_stick.output_vector = test_case["input"]
		for _frame in 30:
			await tree.physics_frame
		var final_axis: float = player.global_position.x if int(test_case["axis"]) == 0 else player.global_position.z
		_assert(final_axis >= float(test_case["min"]) and final_axis <= float(test_case["max"]), "Perimeter wall collision failed at %s (final %.2f)" % [str(test_case["origin"]), final_axis])

	player.global_position = Vector3(3.0, 0.02, 3.8)
	player.velocity = Vector3.ZERO
	player._move_vel = Vector3.ZERO
	player._knockback_vel = Vector3.ZERO
	movement_stick.output_vector = Vector2.RIGHT
	for _frame in 45:
		await tree.physics_frame
	_assert(player.global_position.x < 6.0 and player.global_position.x > 4.0, "Player did not collide with the EastS concrete barricade (x=%.2f)" % player.global_position.x)

	movement_stick.output_vector = Vector2.ZERO
	player.global_position = original_position
	player.velocity = Vector3.ZERO
	player._move_vel = Vector3.ZERO
	player._knockback_vel = Vector3.ZERO
	for i in mini(bots.size(), bot_physics_states.size()):
		bots[i].set_physics_process(bot_physics_states[i])
	_step = 2
	_wait_frames = 35


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		push_error("[QA_FAIL] " + msg)


func _process(_delta: float) -> void:
	if _step < 0:
		return
	if _wait_frames > 0:
		_wait_frames -= 1
		return

	var tree: SceneTree = get_tree()
	match _step:
		0:
			var menu: Node = tree.current_scene
			_assert(menu != null and menu.name == "MainMenu", "Expected MainMenu, got %s" % str(menu))
			_assert(tree.root.theme != null, "Persian theme not applied on root viewport")
			_assert(menu.get_node_or_null("WarBackdrop") is TextureRect, "WarBackdrop missing in MainMenu")
			_assert(menu.get_node_or_null("LobbyViewportContainer") == null, "Heavy 3D SubViewport should be removed from MainMenu")
			_assert(menu.find_child("BtnLargeText", true, false) is Button, "Accessible large-text control missing")
			var arsenal_tab: Button = menu.find_child("BtnTabArsenal", true, false) as Button
			var map_tab: Button = menu.find_child("BtnTabArena", true, false) as Button
			_assert(arsenal_tab != null and arsenal_tab.icon != null and map_tab != null and map_tab.icon != null, "Weapon/map section icons missing")
			var alpha_map: Button = menu.find_child("BtnMapSector01", true, false) as Button
			var bravo_map: Button = menu.find_child("BtnMapSector02", true, false) as Button
			_assert(alpha_map != null and alpha_map.icon != null and bravo_map != null and bravo_map.icon != null, "Arena selection map icons missing")
			var logo_rect: TextureRect = menu.find_child("LogoRect", true, false) as TextureRect
			_assert(logo_rect != null and logo_rect.texture != null, "Game logo missing in MainMenu")

			for tab_idx in range(5):
				menu.call("_show_tab", tab_idx, false)
				var pages: Variant = menu.get("_pages")
				_assert(pages is Array and (pages[tab_idx] as Control).visible, "MainMenu tab %d failed to activate" % tab_idx)
			menu.call("_show_tab", 0, false)

			menu.call("_on_select_weapon", "rapid_repeater")
			_assert(SaveManager.starting_blaster_id == "rapid_repeater", "Arsenal select rapid_repeater failed")
			menu.call("_on_select_weapon", "pulse_blaster")
			_assert(SaveManager.starting_blaster_id == "pulse_blaster", "Arsenal select pulse_blaster failed")

			menu.call("_on_select_map", "sector_02")
			_assert(SaveManager.selected_map_id == "sector_02", "Failed to select sector_02")
			menu.call("_on_select_map", "sector_01")
			_assert(SaveManager.selected_map_id == "sector_01", "Failed to select sector_01")

			# Test Phase 12 settings & defaults (60 FPS default)
			_assert(SaveManager.target_fps == 60, "Expected default target_fps == 60, got %d" % SaveManager.target_fps)
			GameManager.set_target_fps(45)
			_assert(SaveManager.target_fps == 45, "Failed to set target_fps == 45")
			GameManager.set_target_fps(60)
			GameManager.set_show_fps(true)
			_assert(SaveManager.show_fps, "Failed to toggle show_fps")
			GameManager.set_shadows_enabled(false)
			_assert(not SaveManager.shadows_enabled, "Failed to toggle shadows_enabled")
			GameManager.set_camera_shake_enabled(false)
			_assert(not SaveManager.camera_shake_enabled, "Failed to toggle camera_shake_enabled")
			GameManager.set_haptics_enabled(false)
			_assert(not SaveManager.haptics_enabled, "Failed to toggle haptics_enabled")
			var cta_for_accessibility: Button = menu.find_child("BtnEnterArena", true, false) as Button
			var normal_cta_font: int = cta_for_accessibility.get_theme_font_size("font_size") if cta_for_accessibility != null else 0
			GameManager.set_large_text_enabled(true)
			menu.call("_refresh_ui")
			_assert(SaveManager.large_text_enabled, "Failed to enable accessible large text")
			_assert(cta_for_accessibility != null and cta_for_accessibility.get_theme_font_size("font_size") > normal_cta_font, "Accessible text size did not scale menu typography")

			var prev_xp_keep: int = SaveManager.career_xp
			GameManager.reset_settings_to_defaults()
			menu.call("_refresh_ui")
			_assert(SaveManager.target_fps == 60 and SaveManager.shadows_enabled and SaveManager.camera_shake_enabled and not SaveManager.large_text_enabled and SaveManager.career_xp == prev_xp_keep, "Reset settings failed or altered accessibility/career settings")
			GameManager.set_show_fps(true)

			GameManager.set_aim_fire_mode("fire_button")
			_assert(SaveManager.aim_fire_mode == "fire_button", "Failed to toggle fire_button mode")
			GameManager.set_aim_fire_mode("twin_stick")
			_assert(SaveManager.aim_fire_mode == "twin_stick", "Failed to toggle twin_stick mode")

			GameManager.set_joystick_sensitivity(1.25)
			_assert(is_equal_approx(SaveManager.joystick_sensitivity, 1.25), "Failed to set sensitivity 1.25")
			GameManager.set_joystick_sensitivity(1.0)

			GameManager.set_camera_preset("tactical")
			_assert(SaveManager.camera_preset == "tactical", "Camera preset tactical failed")
			GameManager.set_camera_preset("classic")

			GameManager.set_bot_difficulty("hard")
			_assert(SaveManager.bot_difficulty == "hard", "Bot difficulty hard failed")
			GameManager.set_bot_difficulty("balanced")

			for m_id in ["team_score_rush", "zone_blitz", "zone_control"]:
				GameManager.set_selected_mode(m_id)
				var m_cfg: ArenaModeConfig = GameManager.get_active_mode_config()
				_assert(m_cfg != null and str(m_cfg.mode_id) == m_id, "Expected mode %s" % m_id)

			for removed_res in [
				"res://scenes/ui/lobby_stage_3d.tscn",
				"res://scripts/ui/lobby_stage_3d.gd",
				"res://assets/kenney/mini_arena/character-soldier.glb",
				"res://assets/kenney/fps/blaster.glb"
			]:
				_assert(not ResourceLoader.exists(removed_res), "Legacy unused file should be removed: %s" % removed_res)

			for res_p in [
				"res://assets/ui/menu_war_backdrop.jpg",
				"res://assets/ui/game_logo.png",
				"res://assets/ui/launcher_icon.png",
				"res://assets/ui/launcher_adaptive_foreground.png",
				"res://assets/ui/launcher_adaptive_background.png",
				"res://assets/ui/map_sector_alpha.png",
				"res://assets/ui/map_sector_bravo.png",
				"res://assets/ui/icon_nav_arsenal.png",
				"res://assets/ui/icon_nav_arena.png",
				"res://assets/ui/icon_weapon_m4.png",
				"res://assets/ui/icon_weapon_uzi.png",
				"res://assets/ui/icon_weapon_shotgun.png",
				"res://assets/ui/icon_weapon_sniper.png",
				"res://assets/audio/bgm_menu_arcade.wav",
				"res://assets/audio/bgm_arena_combat.wav",
				"res://assets/audio/sfx_gun_m4.wav",
				"res://assets/audio/sfx_gun_uzi.wav",
				"res://assets/audio/sfx_gun_shotgun.wav",
				"res://assets/audio/sfx_gun_sniper.wav",
				"res://assets/materials/battlefield_asphalt.png",
				"res://assets/materials/arena_floor_grid.gdshader",
				"res://assets/materials/arena_floor_sector01.tres",
				"res://assets/materials/arena_floor_sector02.tres",
				"res://assets/kenney/blocky_characters/character-j.glb",
				"res://assets/kenney/blocky_characters/Textures/skin_player_swat.png",
				"res://assets/kenney/blocky_characters/Textures/skin_ally_commando.png",
				"res://assets/kenney/blocky_characters/Textures/skin_enemy_merc.png",
				"res://assets/kenney/blocky_characters/Textures/skin_enemy_heavy.png",
				"res://assets/kenney/weapon/machinegun.glb",
				"res://assets/kenney/weapon/uziLongSilencer.glb",
				"res://assets/kenney/weapon/shotgun.glb",
				"res://assets/kenney/weapon/sniper.glb",
				"res://assets/kenney/weapon/grenade.glb",
				"res://assets/kenney/survival/barrel.glb",
				"res://assets/kenney/survival/box.glb",
				"res://assets/kenney/retro_urban/detail-barrier-strong-type-a.glb",
				"res://scenes/combat/pulse_bomb.tscn",
				"res://scenes/items/explosive_crate.tscn",
				"res://scripts/core/visual_fx_utils.gd"
			]:
				_assert(ResourceLoader.exists(res_p), "Missing Phase 12 resource: %s" % res_p)

			GameManager.set_large_text_enabled(true)
			GameManager.go_to_selected_arena()
			_step = 1
			_wait_frames = 5
		1:
			var arena: Node = tree.current_scene
			_assert(arena != null and arena.name == "ArenaSector01", "Expected ArenaSector01")
			var arena_env: WorldEnvironment = arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
			_assert(arena_env != null and arena_env.environment != null and arena_env.environment.tonemap_mode == Environment.TONE_MAPPER_ACES, "ArenaSector01 should enable ACES tonemapping")
			arena.call("_apply_quality_lighting", "medium")
			_assert(arena_env != null and not arena_env.environment.glow_enabled, "Medium preset should disable expensive bloom on mobile for 60 FPS")
			arena.call("_apply_quality_lighting", "low")
			var sun_l: DirectionalLight3D = arena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
			_assert(sun_l != null and not sun_l.shadow_enabled, "Low quality preset did not disable sun shadows")
			arena.call("_apply_quality_lighting", SaveManager.quality_preset)

			var player: PlayerController = arena.get_node_or_null("PlayerCharacter") as PlayerController
			_assert(player != null, "PlayerCharacter missing")
			if player == null:
				_step = 99
				return

			_assert(player.is_alive(), "Player should start alive")
			_assert(player.blasters.size() == 4, "Expected 4 weapons, got %d" % player.blasters.size())
			_assert(player.get_node_or_null("VisualRoot/KenneySoldier/MilitaryGearMarker") != null, "Player military gear marker missing")
			_assert(player.find_child("KevlarHelmetDome", true, false) != null, "Player 3D KevlarHelmetDome missing")
			_assert(player.find_child("PlateCarrierVest", true, false) != null, "Player 3D PlateCarrierVest missing")
			_assert(player._anim_player != null, "Kenney soldier AnimationPlayer not found")
			if player._anim_player != null:
				for anim_name in ["idle", "walk", "sprint"]:
					_assert(player._anim_player.has_animation(anim_name), "Missing animation %s" % anim_name)
					var a: Animation = player._anim_player.get_animation(anim_name)
					_assert(a != null and a.loop_mode == Animation.LOOP_LINEAR, "Animation %s not set to LOOP_LINEAR" % anim_name)

			_assert(player.trigger_dash(), "Player initial dash should succeed")
			_assert(player.is_dashing(), "Expected player.is_dashing() == true right after trigger_dash")
			player.take_damage(35.0, 1, Vector3(6.0, 0.0, 0.0))
			_assert(is_equal_approx(player._hp, 100.0), "Dashing player should ignore projectile/hit damage")
			player._dash_timer = 0.0
			player._move_vel = Vector3.ZERO
			player._knockback_vel = Vector3.ZERO
			player.velocity = Vector3.ZERO

			var crates: Array[Node] = tree.get_nodes_in_group("explosive_crates")
			_assert(crates.size() == 2, "Expected 2 ExplosiveCrates in Sector 01, got %d" % crates.size())
			var bots: Array[Node] = tree.get_nodes_in_group("arena_bots")
			_assert(bots.size() == 4, "Expected 4 ArenaBots (1 Blue + 3 Orange), got %d" % bots.size())
			for b in bots:
				if b is ArenaBot:
					_assert((b as Node).find_child("SoldierRifle", true, false) != null, "Bot %s missing 3D SoldierRifle" % (b as Node).name)

			var orange_target: ArenaBot = null
			for b in bots:
				if b is ArenaBot and (b as ArenaBot).team_id == 1 and (b as ArenaBot).is_alive():
					orange_target = b as ArenaBot
					break
			if orange_target != null and crates.size() > 0:
				var crate := crates[0] as ExplosiveCrate
				orange_target.global_position = crate.global_position + Vector3(1.5, 0.0, 0.0)
				var hp_before_crate: float = orange_target._hp
				crate.take_damage(60.0, 0, true)
				_assert(_crate_exploded_seen and not crate.is_intact(), "ExplosiveCrate did not detonate on lethal damage")
				_assert(orange_target._hp < hp_before_crate, "ExplosiveCrate blast did not damage nearby Orange bot")

			_assert(player.trigger_bomb(), "Player initial Grenade should succeed")
			var active_bombs: Array[Node] = tree.get_nodes_in_group("pulse_bombs")
			_assert(active_bombs.size() >= 1, "Active Grenade should register in pulse_bombs group")
			if active_bombs.size() >= 1:
				_assert(active_bombs[0].get_node_or_null("GrenadeModel") != null, "GrenadeModel missing on PulseBomb")

			# Cycle all 4 military weapons (M4: 24, UZI: 34, M870: 10, AWP: 6)
			_assert(player._current_energy == 24, "Expected M4 24 ammo, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 34, "Expected UZI 34 ammo, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 10, "Expected Shotgun M870 10 ammo, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 6, "Expected Sniper AWP 6 ammo, got %d" % player._current_energy)
			player._try_fire(0.0)
			_assert(player._current_energy == 5, "Expected Sniper AWP 5 ammo after shot, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 24, "Expected M4 24 after cycling all 4")

			player._try_fire(0.0)
			_assert(player._current_energy == 23, "Expected ammo 23 after M4 shot, got %d" % player._current_energy)
			player.start_recharge()
			_assert(player._recharging, "Expected recharging=true after start_recharge()")

			var hud: Node = arena.get_node_or_null("TouchControlsHUD")
			_assert(hud != null, "TouchControlsHUD missing")
			if hud != null:
				var fps_badge: Control = hud.get_node_or_null("TopSafeMargin/TopHudBar/FpsBadge") as Control
				_assert(fps_badge != null and fps_badge.visible, "HUD FpsBadge missing or hidden when show_fps==true")
				var hud_score: Label = hud.get_node_or_null("TopSafeMargin/TopHudBar/ScoreBadge/ScoreLabel") as Label
				_assert(hud_score != null and hud_score.get_theme_font_size("font_size") >= 17, "Large-text accessibility was not applied in gameplay HUD")
				_assert(hud.get_node_or_null("TopSafeMargin/TopHudBar/StatsBadge/StatsHBox/WeaponIconRect") is TextureRect, "HUD WeaponIconRect missing")
				var pause_button: Button = hud.get_node_or_null("TopSafeMargin/TopHudBar/BtnPause") as Button
				_assert(pause_button != null and pause_button.focus_mode == Control.FOCUS_ALL, "Pause button is not keyboard/focus accessible")
				_assert(hud.get_node_or_null("PauseOverlay/PauseCard/PauseMargin/PauseVBox/BtnPauseFps") != null, "HUD BtnPauseFps missing")
				_assert(hud.get_node_or_null("BottomSafeMargin/TouchControlsRow/CenterGap/TacticalRadar") != null, "TacticalRadar missing")
				var action_row: GridContainer = hud.get_node_or_null("BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow") as GridContainer
				if action_row != null:
					var required_width: float = 0.0
					for action in action_row.get_children():
						if action is Control:
							var touch_control := action as Control
							required_width += touch_control.custom_minimum_size.x
							_assert(touch_control.custom_minimum_size.y >= 48.0, "Touch action target below 48 px: %s" % touch_control.name)
					_assert(action_row.size.x + 0.5 >= required_width, "Touch action buttons overflow their row (%0.1f > %0.1f)" % [required_width, action_row.size.x])

				GameManager.set_match_paused(true)
				_assert(tree.paused, "SceneTree should be paused")
				GameManager.set_match_paused(false)
				_assert(not tree.paused, "SceneTree should resume cleanly")

			_step = 97
			call_deferred("_run_movement_camera_qa", player, hud, arena)
		97:
			pass
		2:
			var arena: Node = tree.current_scene
			var player: PlayerController = arena.get_node_or_null("PlayerCharacter") as PlayerController
			if player != null:
				_assert(not player._recharging and player._current_energy == 24, "Reload did not complete cleanly (recharging=%s energy=%d)" % [str(player._recharging), player._current_energy])

			var orange_bots: Array[ArenaBot] = []
			for b in tree.get_nodes_in_group("arena_bots"):
				if b is ArenaBot and (b as ArenaBot).team_id == 1:
					orange_bots.append(b as ArenaBot)

			if orange_bots.size() >= 2:
				_tested_orange_bot_name = orange_bots[0].name
				var prev_blue: int = int(arena.get("_blue_score"))
				orange_bots[0].take_damage(220.0, 0, true)
				orange_bots[1].take_damage(220.0, 0, true)
				_assert(int(arena.get("_blue_score")) >= prev_blue + 2, "Expected blue_score +2 after 2 player kills")
				_assert(int(arena.get("_player_kill_streak")) >= 2, "Expected player_kill_streak >= 2")
				_assert(_kill_feed_seen, "Expected kill_feed_event on elimination")

			if player != null:
				player._hp = player.max_hp
				player.take_damage(40.0, 1, Vector3(player.global_position.x + 5.0, 0.0, player.global_position.z))
				_assert(_hit_dir_seen, "Expected player_damaged_direction signal")
				_assert(is_equal_approx(player._hp, 60.0), "Expected player HP=60 after 40 dmg, got %.1f" % player._hp)
				_assert(player.apply_pickup(0, 35.0) and is_equal_approx(player._hp, 95.0), "MEDKIT should restore +35 HP to 95")
				player.take_damage(120.0, 1, Vector3(0.0, 0.0, 6.0))
				_assert(not player.is_alive(), "Player should die after lethal damage")

			_step = 3
			_wait_frames = 96
		3:
			var arena: Node = tree.current_scene
			var player: PlayerController = arena.get_node_or_null("PlayerCharacter") as PlayerController
			for b in tree.get_nodes_in_group("arena_bots"):
				if b is ArenaBot:
					var ab := b as ArenaBot
					if ab.name == _tested_orange_bot_name:
						_assert(ab._state != ArenaBot.BotState.RESPAWN and ab.is_alive(), "Tested Orange bot did not respawn cleanly")
					if ab.team_id == 1 and ab.is_alive():
						ab.global_position = Vector3(11.0, 0.02, 7.0)

			var zone_a: CaptureZonePad = arena.get_node_or_null("ZoneA_North") as CaptureZonePad
			if zone_a != null:
				zone_a._capture_value = 0.0
				_zone_progress_before = 0.0

			if player != null:
				_assert(player.is_alive() and is_equal_approx(player._hp, 100.0), "Player did not respawn cleanly")
				player.global_position = Vector3(0.0, 0.05, -7.2)

			_step = 4
			_wait_frames = 20
		4:
			var arena: Node = tree.current_scene
			_assert(_zone_entered_seen, "CaptureZonePad ZoneA_North did not emit player_zone_changed")
			var zone_a: CaptureZonePad = arena.get_node_or_null("ZoneA_North") as CaptureZonePad
			_assert(zone_a != null and zone_a._capture_value > _zone_progress_before + 0.1, "ZoneA_North _capture_value did not advance")

			arena._finish_match()
			_assert(bool(arena.get("_match_over")), "Expected _match_over == true after _finish_match()")

			GameManager.set_selected_mode("team_score_rush")
			GameManager.set_selected_map("sector_02")
			GameManager.go_to_selected_arena()
			_step = 5
			_wait_frames = 5
		5:
			var arena2: Node = tree.current_scene
			_assert(arena2 != null and arena2.name == "ArenaSector02", "Expected ArenaSector02, got %s" % str(arena2))
			if arena2 != null:
				var player2: PlayerController = arena2.get_node_or_null("PlayerCharacter") as PlayerController
				_assert(player2 != null and player2.is_alive(), "ArenaSector02 PlayerCharacter missing or dead")
				_assert(tree.get_nodes_in_group("arena_bots").size() == 4, "ArenaSector02 expected 4 bots")
				_assert(tree.get_nodes_in_group("explosive_crates").size() == 2, "ArenaSector02 expected 2 ExplosiveCrates")
				if player2 != null:
					_assert(player2.trigger_dash(), "ArenaSector02 player dash failed")
					_assert(player2.trigger_bomb(), "ArenaSector02 player bomb failed")

			GameManager.set_selected_mode("zone_control")
			GameManager.set_selected_map("sector_01")
			GameManager.go_to_main_menu()
			_step = 6
			_wait_frames = 5
		6:
			var menu: Node = tree.current_scene
			_assert(menu != null and menu.name == "MainMenu", "Failed to return to MainMenu from ArenaSector02")
			var pools_dict: Variant = PoolManager.get("_pools")
			_assert(pools_dict is Dictionary and (pools_dict as Dictionary).is_empty(), "PoolManager was not cleared on arena exit")
			GameManager.reset_settings_to_defaults()
			menu.call("_refresh_ui")
			_assert(not SaveManager.large_text_enabled, "Accessibility setting did not reset after gameplay QA")
			_step = 99
		_:
			if _failures.is_empty():
				print("[QA_PASS] All Phase 12 automated runtime checks passed cleanly across War Menu, Military Soldiers, 60 FPS Optimization, Sector 01 & Sector 02!")
				tree.quit(0)
			else:
				print("[QA_FAIL] Total failures: %d" % _failures.size())
				for f in _failures:
					print("  - ", f)
				tree.quit(1)
			_step = -1
