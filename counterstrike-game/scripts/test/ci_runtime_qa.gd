extends Node
## تست خودکار End-to-End برای بررسی باگ‌های زمان اجرا در Godot 4.3 (Headless CI).

var _failures: Array[String] = []
var _step: int = -1
var _wait_frames: int = 2
var _zone_entered_seen: bool = false
var _tested_orange_bot_name: String = ""
var _zone_progress_before: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_start_qa")


func _start_qa() -> void:
	print("[QA] Starting automated runtime QA (Phase 4)...")
	if get_parent() != get_tree().root:
		reparent(get_tree().root)
	get_tree().current_scene = null
	EventBus.player_zone_changed.connect(_on_zone_changed)
	var err: Error = get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	_assert(err == OK, "MainMenu load failed: %d" % err)
	_step = 0
	_wait_frames = 4


func _on_zone_changed(_zone_id: String, _title: String, inside: bool) -> void:
	if inside:
		_zone_entered_seen = true


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

			GameManager.set_selected_mode("team_score_rush")
			var rush_cfg: ArenaModeConfig = GameManager.get_active_mode_config()
			_assert(rush_cfg != null and rush_cfg.mode_id == "team_score_rush", "Expected team_score_rush mode config")
			GameManager.set_selected_mode("zone_control")
			var zone_cfg: ArenaModeConfig = GameManager.get_active_mode_config()
			_assert(zone_cfg != null and zone_cfg.mode_id == "zone_control", "Expected zone_control mode config")

			GameManager.go_to_arena_sector_01()
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
			_assert(player.blasters.size() == 3, "Expected 3 blasters, got %d" % player.blasters.size())
			_assert(player._anim_player != null, "Kenney soldier AnimationPlayer not found")
			if player._anim_player != null:
				for anim_name in ["idle", "walk", "sprint"]:
					_assert(player._anim_player.has_animation(anim_name), "Missing animation %s" % anim_name)
					var a: Animation = player._anim_player.get_animation(anim_name)
					_assert(a != null and a.loop_mode == Animation.LOOP_LINEAR, "Animation %s not set to LOOP_LINEAR" % anim_name)

			var bots: Array[Node] = tree.get_nodes_in_group("arena_bots")
			_assert(bots.size() == 4, "Expected 4 ArenaBots (1 Blue + 3 Orange), got %d" % bots.size())
			var blue_bots: int = 0
			var orange_bots: int = 0
			for b in bots:
				if b is ArenaBot:
					var ab := b as ArenaBot
					if ab.team_id == 0:
						blue_bots += 1
						_assert(ab.get_node_or_null("VisualRoot/ModelPivot/KenneyAlly") != null, "AllyBot visual missing")
					elif ab.team_id == 1:
						orange_bots += 1
			_assert(blue_bots == 1 and orange_bots == 3, "Expected 1 Blue & 3 Orange bots, got %d/%d" % [blue_bots, orange_bots])

			var initial_energy: int = player._current_energy
			_assert(initial_energy == 16, "Expected Pulse Blaster 16 energy, got %d" % initial_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 30, "Expected Rapid Repeater 30 energy, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 10, "Expected Plasma Scatter 10 energy, got %d" % player._current_energy)
			player._try_fire(0.0)
			_assert(player._current_energy == 9, "Expected Plasma Scatter 9 energy after spread fire, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 16, "Expected Pulse Blaster 16 after cycling back")

			player._try_fire(0.0)
			_assert(player._current_energy == 15, "Expected energy 15 after Pulse shot, got %d" % player._current_energy)
			player.start_recharge()
			_assert(player._recharging, "Expected recharging=true after start_recharge()")

			GameManager.set_match_paused(true)
			_assert(tree.paused, "SceneTree should be paused")
			var hud: Node = arena.get_node_or_null("TouchControlsHUD")
			if hud != null:
				var pause_ov: Control = hud.get_node_or_null("PauseOverlay") as Control
				_assert(pause_ov != null and pause_ov.visible, "PauseOverlay should be visible when paused")
			GameManager.set_match_paused(false)
			_assert(not tree.paused, "SceneTree should resume cleanly")

			_step = 2
			_wait_frames = 35
		2:
			var arena: Node = tree.current_scene
			var player: PlayerController = arena.get_node_or_null("PlayerCharacter") as PlayerController
			if player != null:
				_assert(not player._recharging and player._current_energy == 16, "Recharge did not complete cleanly (recharging=%s energy=%d)" % [str(player._recharging), player._current_energy])

			var orange_bot: ArenaBot = null
			for b in tree.get_nodes_in_group("arena_bots"):
				if b is ArenaBot and (b as ArenaBot).team_id == 1:
					orange_bot = b as ArenaBot
					break

			if orange_bot != null:
				_tested_orange_bot_name = orange_bot.name
				var prev_blue: int = int(arena.get("_blue_score"))
				orange_bot.take_damage(200.0, 0)
				_assert(int(arena.get("_blue_score")) == prev_blue + 1, "Expected blue_score +1 after Orange bot defeat")
				_assert(orange_bot._state == ArenaBot.BotState.RESPAWN, "Orange bot should enter RESPAWN state")

			if player != null:
				player.take_damage(40.0, 1)
				_assert(is_equal_approx(player._hp, 60.0), "Expected player HP=60 after 40 dmg, got %.1f" % player._hp)
				var prev_orange: int = int(arena.get("_orange_score"))
				player.take_damage(80.0, 1)
				_assert(not player.is_alive(), "Player should die after lethal damage")
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
			_assert(zone_a != null and zone_a._capture_value > _zone_progress_before + 0.1, "ZoneA_North _capture_value did not advance toward Blue (got %.2f)" % (zone_a._capture_value if zone_a != null else -99.0))

			var prev_matches: int = SaveManager.total_matches
			arena._finish_match()
			_assert(bool(arena.get("_match_over")), "Expected _match_over == true after _finish_match()")
			_assert(tree.paused, "Expected SceneTree paused on match end")
			_assert(SaveManager.total_matches == prev_matches + 1, "Career total_matches did not increment")
			var hud: Node = arena.get_node_or_null("TouchControlsHUD")
			if hud != null:
				var end_ov: Control = hud.get_node_or_null("MatchEndOverlay") as Control
				_assert(end_ov != null and end_ov.visible, "MatchEndOverlay should be visible on match end")

			GameManager.go_to_main_menu()
			_step = 5
			_wait_frames = 5
		5:
			var menu: Node = tree.current_scene
			_assert(menu != null and menu.name == "MainMenu", "Failed to return to MainMenu from Arena")
			var pools_dict: Variant = PoolManager.get("_pools")
			_assert(pools_dict is Dictionary and (pools_dict as Dictionary).is_empty(), "PoolManager was not cleared on arena exit")
			_step = 99
		_:
			if _failures.is_empty():
				print("[QA_PASS] All Phase 4 automated runtime checks passed!")
				tree.quit(0)
			else:
				print("[QA_FAIL] Total failures: %d" % _failures.size())
				for f in _failures:
					print("  - ", f)
				tree.quit(1)
			_step = -1
