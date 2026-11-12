extends Node3D
## کنترلر صحنه آزمایشی فاز ۲ (زمین نبرد، نورپردازی متناسب با کیفیت، و دوربین BombSquad).

@onready var _sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var _camera_rig: ArenaCameraRig = $ArenaCameraRig
@onready var _player: PlayerController = $PlayerCharacter


func _ready() -> void:
	GameManager.current_state = GameManager.AppState.ARENA_PLAY
	_apply_quality_lighting(SaveManager.quality_preset)
	EventBus.quality_preset_changed.connect(_apply_quality_lighting)
	if _camera_rig != null and _player != null:
		_camera_rig.set_target(_player)


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
