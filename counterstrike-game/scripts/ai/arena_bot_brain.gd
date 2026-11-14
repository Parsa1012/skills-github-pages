class_name ArenaBotBrain
extends RefCounted
## Modular finite-state decision core. Movement and combat stay in ArenaBot.

enum State { PATROL, INVESTIGATE, ENGAGE, DEFEND, WAIT, RECOVER, RESPAWN }

const STATE_LABELS: Dictionary = {
	State.PATROL: "PATROL",
	State.INVESTIGATE: "INVESTIGATE",
	State.ENGAGE: "ENGAGE",
	State.DEFEND: "DEFEND",
	State.WAIT: "WAIT",
	State.RECOVER: "RECOVER",
	State.RESPAWN: "RESPAWN"
}

var state: State = State.PATROL
var _candidate_target: Node3D = null
var _reaction_left: float = 0.0
var _has_candidate: bool = false


func update(
	visible_target: Node3D,
	has_nearby_danger: bool,
	has_investigation: bool,
	is_stuck: bool,
	should_wait: bool,
	delta: float,
	reaction_delay: float
) -> State:
	var confirmed_target: Node3D = _update_target_confirmation(
		visible_target, delta, reaction_delay
	)
	var next_state: State = State.PATROL
	if is_stuck:
		next_state = State.RECOVER
	elif has_nearby_danger:
		next_state = State.DEFEND
	elif confirmed_target != null:
		next_state = State.ENGAGE
	elif has_investigation:
		next_state = State.INVESTIGATE
	elif should_wait:
		next_state = State.WAIT
	state = next_state
	return state


func get_confirmed_target() -> Node3D:
	if state == State.ENGAGE and _has_candidate and is_instance_valid(_candidate_target):
		return _candidate_target
	return null


func reset() -> void:
	state = State.PATROL
	_candidate_target = null
	_reaction_left = 0.0
	_has_candidate = false


func state_name() -> String:
	return str(STATE_LABELS.get(state, "UNKNOWN"))


func _update_target_confirmation(
	visible_target: Node3D, delta: float, reaction_delay: float
) -> Node3D:
	if visible_target == null or not is_instance_valid(visible_target):
		_candidate_target = null
		_reaction_left = 0.0
		_has_candidate = false
		return null
	if not _has_candidate or _candidate_target != visible_target:
		_candidate_target = visible_target
		_reaction_left = maxf(0.0, reaction_delay)
		_has_candidate = true
	_reaction_left = maxf(0.0, _reaction_left - delta)
	return _candidate_target if _reaction_left <= 0.0 else null
