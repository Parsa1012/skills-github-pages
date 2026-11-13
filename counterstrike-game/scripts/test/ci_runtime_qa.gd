extends Node
## تست خودکار End-to-End برای بررسی کامل فاز ۷ در Godot 4.3 (بمب پالس، جعبه‌های انفجاری، رادار، جهت آسیب، هوش مصنوعی و رفع اشکالات فازهای قبل).

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
	print("[QA] Starting automated runtime QA (Phase 7)...")
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
			GameManager.set_bot_difficulty("easy")
			_assert(SaveManager.bot_difficulty == "easy", "Bot difficulty easy failed")
			GameManager.set_bot_difficulty("balanced")
			_assert(SaveManager.bot_difficulty == "balanced", "Bot difficulty balanced failed")

			for m_id in ["team_score_rush", "zone_blitz", "zone_control"]:
				GameManager.set_selected_mode(m_id)
				var m_cfg: ArenaModeConfig = GameManager.get_active_mode_config()
				_assert(m_cfg != null and str(m_cfg.mode_id) == m_id, "Expected mode %s" % m_id)

			GameManager.set_starting_blaster("arc_railgun")
			_assert(GameManager.get_starting_blaster_index() == 3, "Expected arc_railgun index 3")
			GameManager.set_starting_blaster("pulse_blaster")
			_assert(GameManager.get_starting_blaster_index() == 0, "Expected pulse_blaster index 0")

			GameManager.set_selected_map("sector_02")
			_assert(SaveManager.selected_map_id == "sector_02", "Failed to select sector_02")
			GameManager.set_selected_map("sector_01")
			_assert(SaveManager.selected_map_id == "sector_01", "Failed to select sector_01")

			_assert(AudioManager.get("_menu_music") != null, "Menu arcade BGM did not load")
			_assert(AudioManager.get("_arena_music") != null, "Arena combat BGM did not load")
			AudioManager.play_menu_music()
			AudioManager.set_master_volume(0.85)
			_assert(is_equal_approx(SaveManager.master_volume, 0.85), "Master volume setter failed")

			for res_p in [
				"res://assets/audio/bgm_menu_arcade.wav",
				"res://assets/audio/bgm_arena_combat.wav",
				"res://assets/audio/sfx_plasma_scatter.wav",
				"res://assets/audio/sfx_arc_railgun.wav",
				"res://assets/audio/sfx_dash_whoosh.wav",
				"res://assets/audio/sfx_hitmarker.wav",
				"res://assets/audio/sfx_match_victory.wav",
				"res://assets/audio/sfx_match_defeat.wav",
				"res://assets/audio/sfx_bomb_throw.wav",
				"res://assets/audio/sfx_bomb_explode.wav",
				"res://assets/materials/arena_floor_grid.gdshader",
				"res://assets/materials/arena_floor_sector01.tres",
				"res://assets/materials/arena_floor_sector02.tres",
				"res://scenes/combat/pulse_bomb.tscn",
				"res://scenes/items/explosive_crate.tscn"
			]:
				_assert(ResourceLoader.exists(res_p), "Missing Phase 7 resource: %s" % res_p)

			GameManager.go_to_selected_arena()
			_step = 1
			_wait_frames = 5
		1:
			var arena: Node = tree.current_scene
			_assert(arena != null and arena.name == "ArenaSector01", "Expected ArenaSector01")
			var player: PlayerController = arena.get_node_or_null("PlayerCharacter") as PlayerController
			_assert(player != null, "PlayerCharacter missing")
			if player == null:
				_step = 99
				return

			_assert(player.is_alive(), "Player should start alive")
			_assert(player.blasters.size() == 4, "Expected 4 blasters, got %d" % player.blasters.size())
			_assert(player.get_node_or_null("VisualRoot/WeaponMount/MuzzleMarker/MuzzleFlashMesh") != null, "MuzzleFlashMesh missing")
			_assert(player.get_node_or_null("BuffAuraMesh") != null, "BuffAuraMesh missing")
			_assert(player._anim_player != null, "Kenney soldier AnimationPlayer not found")
			if player._anim_player != null:
				for anim_name in ["idle", "walk", "sprint"]:
					_assert(player._anim_player.has_animation(anim_name), "Missing animation %s" % anim_name)
					var a: Animation = player._anim_player.get_animation(anim_name)
					_assert(a != null and a.loop_mode == Animation.LOOP_LINEAR, "Animation %s not set to LOOP_LINEAR" % anim_name)
				_assert(player._anim_player.has_animation("die"), "Missing die animation")

			# Dash test + i-frame damage block
			_assert(player.trigger_dash(), "Player initial dash should succeed")
			_assert(player.is_dashing(), "Expected player.is_dashing() == true right after trigger_dash")
			player.take_damage(35.0, 1, Vector3(6.0, 0.0, 0.0))
			_assert(is_equal_approx(player._hp, 100.0), "Dashing player should ignore projectile/hit damage")
			_assert(not player.trigger_dash(), "Dash should respect cooldown immediately after use")
			player._dash_timer = 0.0
			player.velocity = Vector3.ZERO

			var pickups: Array[Node] = tree.get_nodes_in_group("arena_pickups")
			_assert(pickups.size() == 4, "Expected 4 ArenaPickups, got %d" % pickups.size())

			var crates: Array[Node] = tree.get_nodes_in_group("explosive_crates")
			_assert(crates.size() == 2, "Expected 2 ExplosiveCrates in Sector 01, got %d" % crates.size())

			var bots: Array[Node] = tree.get_nodes_in_group("arena_bots")
			_assert(bots.size() == 4, "Expected 4 ArenaBots (1 Blue + 3 Orange), got %d" % bots.size())

			# Verify bot zone_blitz objective awareness fix + difficulty scaling
			GameManager.set_selected_mode("zone_blitz")
			for b in bots:
				if b is ArenaBot and (b as ArenaBot).team_id == 1:
					var ab := b as ArenaBot
					if ab.profile != null and ab.profile.zone_objective_focus >= 0.6:
						ab.global_position = Vector3(0.0, 0.02, -5.0)
						var tgt: Vector3 = ab._pick_objective_target()
						_assert(tgt.distance_to(Vector3(0.0, ab.global_position.y, -7.2)) < 1.2, "Bot failed zone_blitz objective pick")
						break
			GameManager.set_selected_mode("zone_control")

			# Test PulseBomb throw + AoE damage
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

			_assert(player.trigger_bomb(), "Player initial PulseBomb should succeed")
			_assert(not player.trigger_bomb(), "PulseBomb should respect cooldown immediately after throw")

			# Cycle all 4 blasters
			_assert(player._current_energy == 16, "Expected Pulse Blaster 16 energy, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 30, "Expected Rapid Repeater 30 energy, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 10, "Expected Plasma Scatter 10 energy, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 6, "Expected Arc Railgun 6 energy, got %d" % player._current_energy)
			player._try_fire(0.0)
			_assert(player._current_energy == 5, "Expected Arc Railgun 5 energy after rail shot, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 16, "Expected Pulse Blaster 16 after cycling all 4")

			player._try_fire(0.0)
			_assert(player._current_energy == 15, "Expected energy 15 after Pulse shot, got %d" % player._current_energy)
			player.start_recharge()
			_assert(player._recharging, "Expected recharging=true after start_recharge()")

			var hud: Node = arena.get_node_or_null("TouchControlsHUD")
			_assert(hud != null, "TouchControlsHUD missing")
			if hud != null:
				_assert(hud.get_node_or_null("BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow/BtnBomb") != null, "BtnBomb missing")
				_assert(hud.get_node_or_null("BottomSafeMargin/TouchControlsRow/RightZoneOverlay/ActionPadRow/BtnDash") != null, "BtnDash missing")
				_assert(hud.get_node_or_null("BottomSafeMargin/TouchControlsRow/CenterGap/TacticalRadar") != null, "TacticalRadar missing")
				_assert(hud.get_node_or_null("HitDirectionIndicator") != null, "HitDirectionIndicator missing")
				_assert(hud.get_node_or_null("TopSafeMargin/TopHudBar/StatsBadge/StatsVBox/BarsRow/HpBar") != null, "HpBar missing")
				_assert(hud.get_node_or_null("TopSafeMargin/TopHudBar/StatsBadge/StatsVBox/BarsRow/EnergyBar") != null, "EnergyBar missing")
				_assert(hud.get_node_or_null("HitmarkerLabel") != null, "HitmarkerLabel missing")
				_assert(hud.get_node_or_null("KillFeedPanel") != null, "KillFeedPanel missing")

				GameManager.set_match_paused(true)
				_assert(tree.paused, "SceneTree should be paused")
				_assert(bool(AudioManager.get("_music_ducked")), "Arena music should duck while paused")
				var pause_ov: Control = hud.get_node_or_null("PauseOverlay") as Control
				_assert(pause_ov != null and pause_ov.visible, "PauseOverlay should be visible when paused")
				_assert(hud.get_node_or_null("PauseOverlay/PauseCard/PauseMargin/PauseVBox/PauseAudioRow/BtnPauseMusic") != null, "BtnPauseMusic missing")
				GameManager.set_match_paused(false)
				_assert(not tree.paused, "SceneTree should resume cleanly")

			_step = 2
			_wait_frames = 35
		2:
			var arena: Node = tree.current_scene
			var player: PlayerController = arena.get_node_or_null("PlayerCharacter") as PlayerController
			if player != null:
				_assert(not player._recharging and player._current_energy == 16, "Recharge did not complete cleanly (recharging=%s energy=%d)" % [str(player._recharging), player._current_energy])

			var orange_bots: Array[ArenaBot] = []
			for b in tree.get_nodes_in_group("arena_bots"):
				if b is ArenaBot and (b as ArenaBot).team_id == 1:
					orange_bots.append(b as ArenaBot)

			if orange_bots.size() >= 2:
				_tested_orange_bot_name = orange_bots[0].name
				var prev_blue: int = int(arena.get("_blue_score"))
				orange_bots[0].take_damage(200.0, 0, true)
				orange_bots[1].take_damage(200.0, 0, true)
				_assert(int(arena.get("_blue_score")) >= prev_blue + 2, "Expected blue_score +2 after 2 player kills")
				_assert(int(arena.get("_player_kill_streak")) >= 2, "Expected player_kill_streak >= 2")
				_assert(_kill_feed_seen, "Expected kill_feed_event on elimination")

			if player != null:
				player._hp = player.max_hp
				_assert(not player.apply_pickup(0, 35.0), "Full-HP player should not consume MEDKIT")
				player.take_damage(40.0, 1, Vector3(player.global_position.x + 5.0, 0.0, player.global_position.z))
				_assert(_hit_dir_seen, "Expected player_damaged_direction signal when attacker_pos given")
				_assert(is_equal_approx(player._hp, 60.0), "Expected player HP=60 after 40 dmg, got %.1f" % player._hp)
				_assert(player.apply_pickup(0, 35.0) and is_equal_approx(player._hp, 95.0), "MEDKIT should restore +35 HP to 95")
				_assert(player.apply_pickup(1, 8.0) and player._damage_boost_timer > 7.5, "OVERCHARGE pickup failed")
				_assert(player.apply_pickup(2, 7.0) and player._speed_boost_timer > 6.5, "SPEED_BOOST pickup failed")
				player._update_buff_aura(0.05)
				var aura: MeshInstance3D = player.get_node_or_null("BuffAuraMesh") as MeshInstance3D
				_assert(aura != null and aura.visible, "BuffAuraMesh should be visible when buff is active")

				var hud_chk: Node = arena.get_node_or_null("TouchControlsHUD")
				if hud_chk != null:
					var buff_badge: Control = hud_chk.get_node_or_null("TopSafeMargin/TopHudBar/BuffBadge") as Control
					_assert(buff_badge != null and buff_badge.visible, "HUD BuffBadge should be visible during pickup buff")
					var kf_panel: Control = hud_chk.get_node_or_null("KillFeedPanel") as Control
					_assert(kf_panel != null and kf_panel.visible, "KillFeedPanel should be visible after eliminations")

				var prev_orange: int = int(arena.get("_orange_score"))
				player.take_damage(120.0, 1, Vector3(0.0, 0.0, 6.0))
				_assert(not player.is_alive(), "Player should die after lethal damage")
				_assert(int(arena.get("_player_kill_streak")) == 0, "Kill streak should reset on player defeat")
				_assert(int(arena.get("_orange_score")) == prev_orange + 1, "Expected orange_score +1 after player defeat")

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
			_assert(zone_a != null and zone_a._capture_value > _zone_progress_before + 0.1, "ZoneA_North _capture_value did not advance toward Blue")

			var prev_matches: int = SaveManager.total_matches
			var prev_xp: int = SaveManager.career_xp
			arena._finish_match()
			_assert(bool(arena.get("_match_over")), "Expected _match_over == true after _finish_match()")
			_assert(tree.paused, "Expected SceneTree paused on match end")
			_assert(SaveManager.total_matches == prev_matches + 1, "Career total_matches did not increment")
			_assert(SaveManager.career_xp > prev_xp, "Career XP did not increase on match finish")
			var hud: Node = arena.get_node_or_null("TouchControlsHUD")
			if hud != null:
				var end_ov: Control = hud.get_node_or_null("MatchEndOverlay") as Control
				_assert(end_ov != null and end_ov.visible, "MatchEndOverlay should be visible on match end")

			# Load Sector 02 in team_score_rush to verify hidden zone flag collision disable fix
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
				_assert(tree.get_nodes_in_group("arena_pickups").size() == 4, "ArenaSector02 expected 4 pickups")
				_assert(tree.get_nodes_in_group("arena_bots").size() == 4, "ArenaSector02 expected 4 bots")
				_assert(tree.get_nodes_in_group("capture_zones").size() == 2, "ArenaSector02 expected 2 capture zones")
				_assert(tree.get_nodes_in_group("explosive_crates").size() == 2, "ArenaSector02 expected 2 ExplosiveCrates")
				var z2a: Node = arena2.get_node_or_null("ZoneA_North")
				if z2a != null:
					var pole_col: CollisionShape3D = z2a.get_node_or_null("ZoneFlagBody/CollisionShape3D") as CollisionShape3D
					_assert(pole_col != null and pole_col.disabled, "Hidden zone flagpole collider should be disabled in team_score_rush")
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
			_step = 99
		_:
			if _failures.is_empty():
				print("[QA_PASS] All Phase 7 automated runtime checks passed across Sector 01 & Sector 02!")
				tree.quit(0)
			else:
				print("[QA_FAIL] Total failures: %d" % _failures.size())
				for f in _failures:
					print("  - ", f)
				tree.quit(1)
			_step = -1
