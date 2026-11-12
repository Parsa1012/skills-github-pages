extends Node3D
## کنترلر میدان نبرد آرکید (مدل‌های Kenney، استخر گلوله انرژی، بات‌های هوش مصنوعی و امتیازدهی).

const PROJECTILE_SCENE_PATH: String = "res://scenes/combat/energy_projectile.tscn"
const IMPACT_FLASH_SCENE_PATH: String = "res://scenes/combat/impact_flash.tscn"

@onready var _sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var _camera_rig: ArenaCameraRig = $ArenaCameraRig
@onready var _player: PlayerController = $PlayerCharacter

var _blue_score: int = 0
var _orange_score: int = 0


func _ready() -> void:
	GameManager.current_state = GameManager.AppState.ARENA_PLAY
	_prewarm_combat_pools()
	_apply_quality_lighting(SaveManager.quality_preset)
	EventBus.quality_preset_changed.connect(_apply_quality_lighting)

	if _camera_rig != null and _player != null:
		_camera_rig.set_target(_player)
	if _player != null:
		_player.player_defeated.connect(_on_player_defeated)

	for bot in get_tree().get_nodes_in_group("arena_bots"):
		if bot is ArenaBot:
			(bot as ArenaBot).bot_defeated.connect(_on_bot_defeated)

	EventBus.score_updated.emit(_blue_score, _orange_score)


func _exit_tree() -> void:
	if EventBus.quality_preset_changed.is_connected(_apply_quality_lighting):
		EventBus.quality_preset_changed.disconnect(_apply_quality_lighting)
	PoolManager.clear_all_pools()


func _prewarm_combat_pools() -> void:
	if ResourceLoader.exists(PROJECTILE_SCENE_PATH):
		var proj_scene: Resource = ResourceLoader.load(PROJECTILE_SCENE_PATH)
		if proj_scene is PackedScene:
			PoolManager.register_pool(EnergyProjectile.POOL_ID, proj_scene as PackedScene, 32)
	if ResourceLoader.exists(IMPACT_FLASH_SCENE_PATH):
		var flash_scene: Resource = ResourceLoader.load(IMPACT_FLASH_SCENE_PATH)
		if flash_scene is PackedScene:
			PoolManager.register_pool(ImpactFlash.POOL_ID, flash_scene as PackedScene, 16)


func _on_bot_defeated(_bot: ArenaBot, attacker_team: int) -> void:
	if attacker_team == 0:
		_blue_score += 1
	else:
		_orange_score += 1
	EventBus.score_updated.emit(_blue_score, _orange_score)


func _on_player_defeated(_attacker_team: int) -> void:
	_orange_score += 1
	EventBus.score_updated.emit(_blue_score, _orange_score)


func _apply_quality_lighting(preset_name: String) -> void:
	if _sun_light == null:
		return
	match preset_name:
		"low":
			_sun_light.shadow_enabled = false
		"medium":
			_sun_light.shadow_enabled = true
			_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		"high":
			_sun_light.shadow_enabled = true
			_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
