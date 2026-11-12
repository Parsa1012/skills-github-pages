extends SceneTree
## تست خودکار End-to-End برای بررسی باگ‌های زمان اجرا در Godot 4.3 (Headless CI).

var _failures: Array[String] = []
var _step: int = 0
var _wait_frames: int = 2
var _zone_entered_seen: bool = false

var _event_bus: Node = null
var _game_mgr: Node = null
var _save_mgr: Node = null
var _pool_mgr: Node = null


func _initialize() -> void:
	print("[QA] Starting automated runtime QA...")
	_event_bus = root.get_node_or_null("EventBus")
	_game_mgr = root.get_node_or_null("GameManager")
	_save_mgr = root.get_node_or_null("SaveManager")
	_pool_mgr = root.get_node_or_null("PoolManager")

	_assert(_event_bus != null, "EventBus autoload missing")
	_assert(_game_mgr != null, "GameManager autoload missing")
	_assert(_save_mgr != null, "SaveManager autoload missing")
	_assert(_pool_mgr != null, "PoolManager autoload missing")

	if _event_bus != null:
		_event_bus.connect("player_zone_changed", _on_zone_changed)

	var err: Error = change_scene_to_file("res://scenes/ui/main_menu.tscn")
	_assert(err == OK, "MainMenu load failed: %d" % err)
	_wait_frames = 2


func _on_zone_changed(_zone_id: String, _title: String, inside: bool) -> void:
	if inside:
		_zone_entered_seen = true


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		push_error("[QA_FAIL] " + msg)


func _process(_delta: float) -> bool:
	if _wait_frames > 0:
		_wait_frames -= 1
		return false

	match _step:
		0:
			var menu: Node = current_scene
			_assert(menu != null and menu.name == "MainMenu", "Expected MainMenu, got %s" % str(menu))
			_assert(root.theme != null, "Persian theme not applied on root viewport")
			if _game_mgr != null and _save_mgr != null:
				_game_mgr.call("set_aim_fire_mode", "fire_button")
				_assert(str(_save_mgr.get("aim_fire_mode")) == "fire_button", "Failed to toggle fire_button mode")
				_game_mgr.call("set_aim_fire_mode", "twin_stick")
				_assert(str(_save_mgr.get("aim_fire_mode")) == "twin_stick", "Failed to toggle twin_stick mode")
				_game_mgr.call("go_to_arena_sector_01")
			_step = 1
			_wait_frames = 4
		1:
			var arena: Node = current_scene
			_assert(arena != null and arena.name == "ArenaSector01", "Expected ArenaSector01")
			var player: PlayerController = arena.get_node_or_null("PlayerCharacter") as PlayerController
			_assert(player != null, "PlayerCharacter missing")
			if player == null:
				_step = 99
				return false

			_assert(player.is_alive(), "Player should start alive")
			_assert(player.blasters.size() == 2, "Expected 2 blasters, got %d" % player.blasters.size())
			_assert(player._anim_player != null, "Kenney soldier AnimationPlayer not found")
			if player._anim_player != null:
				for anim_name in ["idle", "walk", "sprint"]:
					_assert(player._anim_player.has_animation(anim_name), "Missing animation %s" % anim_name)
					var a: Animation = player._anim_player.get_animation(anim_name)
					_assert(a != null and a.loop_mode == Animation.LOOP_LINEAR, "Animation %s not set to LOOP_LINEAR" % anim_name)

			var bots: Array[Node] = get_nodes_in_group("arena_bots")
			_assert(bots.size() == 3, "Expected 3 ArenaBots, got %d" % bots.size())

			# Test weapon switch
			var initial_energy: int = player._current_energy
			_assert(initial_energy == 16, "Expected Pulse Blaster 16 energy, got %d" % initial_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 30, "Expected Rapid Repeater 30 energy, got %d" % player._current_energy)
			player.switch_next_blaster()
			_assert(player._current_energy == 16, "Expected Pulse Blaster 16 after switch back")

			# Test firing projectile
			player._try_fire(0.0)
			_assert(player._current_energy == 15, "Expected energy 15 after shot, got %d" % player._current_energy)

			# Test recharge trigger and completion over time
			player.start_recharge()
			_assert(player._recharging, "Expected recharging=true after start_recharge()")
			_step = 2
			_wait_frames = 45
		2:
			var arena: Node = current_scene
			var player: PlayerController = arena.get_node_or_null("PlayerCharacter") as PlayerController
			if player != null:
				_assert(not player._recharging and player._current_energy == 16, "Recharge did not complete cleanly (recharging=%s energy=%d)" % [str(player._recharging), player._current_energy])

			# Test bot defeat, scoring, and respawn
			var bots: Array[Node] = get_nodes_in_group("arena_bots")
			if not bots.is_empty() and bots[0] is ArenaBot:
				var bot := bots[0] as ArenaBot
				bot.take_damage(120.0, 0)
				_assert(int(arena.get("_blue_score")) == 1, "Expected blue_score == 1 after bot defeat, got %d" % int(arena.get("_blue_score")))
				_assert(bot._state == ArenaBot.BotState.RESPAWN, "Bot should enter RESPAWN state")

			# Test player damage, defeat, and respawn
			if player != null:
				player.take_damage(40.0, 1)
				_assert(is_equal_approx(player._hp, 60.0), "Expected player HP=60 after 40 dmg, got %.1f" % player._hp)
				player.take_damage(80.0, 1)
				_assert(not player.is_alive(), "Player should die after lethal damage")
				_assert(int(arena.get("_orange_score")) == 1, "Expected orange_score == 1 after player defeat, got %d" % int(arena.get("_orange_score")))

			_step = 3
			_wait_frames = 110
		3:
			var arena: Node = current_scene
			var player: PlayerController = arena.get_node_or_null("PlayerCharacter") as PlayerController
			var bots: Array[Node] = get_nodes_in_group("arena_bots")
			if player != null:
				_assert(player.is_alive() and is_equal_approx(player._hp, 100.0), "Player did not respawn cleanly")
				player.global_position = Vector3(0.0, 0.05, -7.2)
			if not bots.is_empty() and bots[0] is ArenaBot:
				var bot := bots[0] as ArenaBot
				_assert(bot._state != ArenaBot.BotState.RESPAWN and is_equal_approx(bot._hp, 100.0), "Bot did not respawn cleanly")
			_step = 4
			_wait_frames = 6
		4:
			_assert(_zone_entered_seen, "CaptureZonePad ZoneA_North did not emit player_zone_changed")
			if _game_mgr != null:
				_game_mgr.call("go_to_main_menu")
			_step = 5
			_wait_frames = 4
		5:
			var menu: Node = current_scene
			_assert(menu != null and menu.name == "MainMenu", "Failed to return to MainMenu from Arena")
			if _pool_mgr != null:
				var pools_dict: Variant = _pool_mgr.get("_pools")
				_assert(pools_dict is Dictionary and (pools_dict as Dictionary).is_empty(), "PoolManager was not cleared on arena exit")
			_step = 99
		_:
			if _failures.is_empty():
				print("[QA_PASS] All automated runtime checks passed!")
				quit(0)
			else:
				print("[QA_FAIL] Total failures: %d" % _failures.size())
				for f in _failures:
					print("  - ", f)
				quit(1)
			return true

	return false
