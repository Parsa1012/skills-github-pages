class_name ArenaEnvironmentalFx
extends Node
## Tiny reusable ambient-light drift; no particles, shaders, shadow updates, or per-frame allocations.

@export var environment_path: NodePath = NodePath("../WorldEnvironment")
@export_range(0.0, 0.06, 0.005) var energy_variation: float = 0.02
@export_range(5.0, 30.0, 1.0) var cycle_seconds: float = 16.0

var _world_environment: WorldEnvironment
var _base_energy: float = 0.0
var _phase: float = 0.0
var _sample_clock: float = 0.0


func _ready() -> void:
	_world_environment = get_node_or_null(environment_path) as WorldEnvironment
	if _world_environment != null and _world_environment.environment != null:
		_base_energy = _world_environment.environment.ambient_light_energy
	_phase = randf_range(0.0, TAU)
	if not EventBus.quality_preset_changed.is_connected(_on_quality_changed):
		EventBus.quality_preset_changed.connect(_on_quality_changed)
	_on_quality_changed(SaveManager.quality_preset)


func _exit_tree() -> void:
	if EventBus.quality_preset_changed.is_connected(_on_quality_changed):
		EventBus.quality_preset_changed.disconnect(_on_quality_changed)
	if is_instance_valid(_world_environment) and _world_environment.environment != null:
		_world_environment.environment.ambient_light_energy = _base_energy


func _on_quality_changed(preset: String) -> void:
	set_process(is_instance_valid(_world_environment) and _world_environment.environment != null and preset != "low")
	if preset == "low" and is_instance_valid(_world_environment) and _world_environment.environment != null:
		_world_environment.environment.ambient_light_energy = _base_energy


func _process(delta: float) -> void:
	_sample_clock += delta
	if _sample_clock < 0.12:
		return
	_sample_clock = 0.0
	if not is_instance_valid(_world_environment) or _world_environment.environment == null:
		set_process(false)
		return
	var wave: float = sin(_phase + Time.get_ticks_msec() / 1000.0 * TAU / cycle_seconds)
	_world_environment.environment.ambient_light_energy = _base_energy * (1.0 + energy_variation * wave)
