class_name ArenaNavigationGrid
extends Node
## Shared offline grid navigation for small arena maps; no NavigationServer baking/network access.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1)
]

const INVALID_CELL: Vector2i = Vector2i(-2147483647, -2147483647)

@export_range(0.55, 1.5, 0.05) var cell_size: float = 0.85
@export_range(1, 64, 1) var cells_per_frame: int = 16
@export var obstacle_mask: int = 1
@export var floor_y: float = 0.02
@export var debug_navigation: bool = false

var bounds_min: Vector2 = Vector2(-14.5, -10.5)
var bounds_max: Vector2 = Vector2(14.5, 10.5)
var is_built: bool = false
var build_progress: float = 0.0
var last_failure: String = ""

var _grid_size: Vector2i = Vector2i.ZERO
var _walkable: Dictionary = {}
var _path_cache: Dictionary = {}
var _cache_keys: Array[String] = []
var _capsule: CapsuleShape3D
var _build_generation: int = 0


func configure(world_min: Vector2, world_max: Vector2) -> void:
	bounds_min = world_min
	bounds_max = world_max
	_build_generation += 1
	_build_grid(_build_generation)


func find_path(start_world: Vector3, target_world: Vector3) -> PackedVector3Array:
	if not is_built:
		return PackedVector3Array()
	var start_cell: Vector2i = _nearest_walkable(
		_world_to_cell(Vector2(start_world.x, start_world.z))
	)
	var goal_cell: Vector2i = _nearest_walkable(
		_world_to_cell(Vector2(target_world.x, target_world.z))
	)
	if start_cell == INVALID_CELL or goal_cell == INVALID_CELL:
		last_failure = "no_walkable_start_or_goal"
		return PackedVector3Array()
	var cache_key: String = "%d:%d>%d:%d" % [start_cell.x, start_cell.y, goal_cell.x, goal_cell.y]
	if _path_cache.has(cache_key):
		return _path_cache[cache_key].duplicate()
	var cells: Array[Vector2i] = _a_star(start_cell, goal_cell)
	if cells.is_empty():
		last_failure = "no_route_%s_to_%s" % [str(start_cell), str(goal_cell)]
		_cache_path(cache_key, PackedVector3Array())
		return PackedVector3Array()
	var route := PackedVector3Array()
	var previous_dir := Vector2i.ZERO
	for i in range(1, cells.size()):
		var direction: Vector2i = cells[i] - cells[i - 1]
		if i == 1 or direction != previous_dir or i == cells.size() - 1:
			route.append(_cell_to_world(cells[i]))
		previous_dir = direction
	if route.is_empty() and start_cell != goal_cell:
		route.append(_cell_to_world(goal_cell))
	last_failure = ""
	_cache_path(cache_key, route)
	return route


func nearest_walkable_position(world_pos: Vector3, max_radius_cells: int = 5) -> Vector3:
	if not is_built:
		return Vector3.ZERO
	var cell: Vector2i = _nearest_walkable(
		_world_to_cell(Vector2(world_pos.x, world_pos.z)), max_radius_cells
	)
	return _cell_to_world(cell) if cell != INVALID_CELL else Vector3.ZERO


func find_recovery_position(world_pos: Vector3, preferred_direction: Vector3) -> Vector3:
	if not is_built:
		return Vector3.ZERO
	var origin_cell: Vector2i = _nearest_walkable(
		_world_to_cell(Vector2(world_pos.x, world_pos.z)), 4
	)
	if origin_cell == INVALID_CELL:
		return Vector3.ZERO
	var prefer := Vector2(preferred_direction.x, preferred_direction.z)
	if prefer.length_squared() > 0.001:
		prefer = prefer.normalized()
	var candidates: Array[Dictionary] = []
	for direction in DIRECTIONS:
		for radius in range(3, 5):
			var cell: Vector2i = origin_cell + direction * radius
			if not _walkable.has(cell):
				continue
			var separation: float = Vector2(origin_cell.x, origin_cell.y).distance_to(
				Vector2(cell.x, cell.y)
			)
			var route: Array[Vector2i] = _a_star(origin_cell, cell)
			if route.size() < 2:
				continue
			var direction_to_cell := Vector2(float(direction.x), float(direction.y)).normalized()
			var alignment: float = (
				-direction_to_cell.dot(prefer) if prefer.length_squared() > 0.001 else 0.0
			)
			candidates.append({"cell": cell, "score": separation + alignment * 0.7})
	if candidates.is_empty():
		return Vector3.ZERO
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"])
	)
	return _cell_to_world(candidates[0]["cell"])


func is_walkable(world_pos: Vector3) -> bool:
	return is_built and _walkable.has(_world_to_cell(Vector2(world_pos.x, world_pos.z)))


func get_debug_info() -> Dictionary:
	return {
		"built": is_built,
		"progress": build_progress,
		"walkable_cells": _walkable.size(),
		"grid_size": _grid_size,
		"cache_entries": _path_cache.size(),
		"last_failure": last_failure
	}


func _build_grid(generation: int) -> void:
	is_built = false
	build_progress = 0.0
	last_failure = "building"
	_walkable.clear()
	_path_cache.clear()
	_cache_keys.clear()
	_grid_size = Vector2i(
		maxi(1, int(floor((bounds_max.x - bounds_min.x) / cell_size))),
		maxi(1, int(floor((bounds_max.y - bounds_min.y) / cell_size)))
	)
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.40
	_capsule.height = 1.45
	var total: int = _grid_size.x * _grid_size.y
	var checked: int = 0
	await get_tree().physics_frame
	for y in _grid_size.y:
		for x in _grid_size.x:
			if generation != _build_generation or not is_inside_tree():
				return
			var cell := Vector2i(x, y)
			var point: Vector3 = _cell_to_world(cell)
			var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
			if _cell_is_clear(space, point):
				_walkable[cell] = true
			checked += 1
			build_progress = float(checked) / float(total)
			if checked % maxi(1, cells_per_frame) == 0:
				await get_tree().physics_frame
	is_built = true
	build_progress = 1.0
	last_failure = ""
	if debug_navigation:
		print("[BotNav] grid ready: %s, walkable=%d" % [str(_grid_size), _walkable.size()])


func _cell_is_clear(space: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, floor_y + 0.86, point.z))
	query.collision_mask = obstacle_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.margin = 0.02
	return space.intersect_shape(query, 1).is_empty()


func _world_to_cell(world: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(round((world.x - bounds_min.x) / cell_size - 0.5)), 0, _grid_size.x - 1),
		clampi(int(round((world.y - bounds_min.y) / cell_size - 0.5)), 0, _grid_size.y - 1)
	)


func _cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		bounds_min.x + (float(cell.x) + 0.5) * cell_size,
		floor_y,
		bounds_min.y + (float(cell.y) + 0.5) * cell_size
	)


func _nearest_walkable(from: Vector2i, max_radius: int = 7) -> Vector2i:
	if _walkable.has(from):
		return from
	for radius in range(1, max_radius + 1):
		var best := INVALID_CELL
		var best_dist_sq: int = 2147483647
		for y in range(maxi(0, from.y - radius), mini(_grid_size.y, from.y + radius + 1)):
			for x in range(maxi(0, from.x - radius), mini(_grid_size.x, from.x + radius + 1)):
				var cell := Vector2i(x, y)
				if not _walkable.has(cell):
					continue
				var dx: int = x - from.x
				var dy: int = y - from.y
				var dist_sq: int = dx * dx + dy * dy
				if dist_sq < best_dist_sq:
					best = cell
					best_dist_sq = dist_sq
		if best != INVALID_CELL:
			return best
	return INVALID_CELL


func _a_star(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var open: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {start: 0.0}
	var estimated_total: Dictionary = {start: _heuristic(start, goal)}
	var closed: Dictionary = {}
	var expansions: int = 0
	while not open.is_empty() and expansions < 1100:
		var best_idx: int = 0
		var best_cell: Vector2i = open[0]
		var best_score: float = float(estimated_total.get(best_cell, INF))
		for i in range(1, open.size()):
			var candidate: Vector2i = open[i]
			var score: float = float(estimated_total.get(candidate, INF))
			if score < best_score:
				best_idx = i
				best_cell = candidate
				best_score = score
		open.remove_at(best_idx)
		if best_cell == goal:
			return _reconstruct_path(came_from, goal)
		closed[best_cell] = true
		expansions += 1
		for direction in DIRECTIONS:
			var next: Vector2i = best_cell + direction
			if not _walkable.has(next) or closed.has(next):
				continue
			if direction.x != 0 and direction.y != 0:
				if (
					not _walkable.has(best_cell + Vector2i(direction.x, 0))
					or not _walkable.has(best_cell + Vector2i(0, direction.y))
				):
					continue
			var step_cost: float = 1.41421356 if direction.x != 0 and direction.y != 0 else 1.0
			var next_cost: float = float(cost_so_far[best_cell]) + step_cost
			if not cost_so_far.has(next) or next_cost < float(cost_so_far[next]):
				came_from[next] = best_cell
				cost_so_far[next] = next_cost
				estimated_total[next] = next_cost + _heuristic(next, goal)
				if not open.has(next):
					open.append(next)
	last_failure = "search_limit_%d" % expansions if expansions >= 1100 else "unreachable_component"
	return []


func _reconstruct_path(came_from: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var cursor: Vector2i = goal
	while came_from.has(cursor):
		cursor = came_from[cursor]
		path.push_front(cursor)
	return path


func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = absi(a.x - b.x)
	var dy: int = absi(a.y - b.y)
	return float(maxi(dx, dy)) + 0.41421356 * float(mini(dx, dy))


func _cache_path(key: String, path: PackedVector3Array) -> void:
	_path_cache[key] = path.duplicate()
	_cache_keys.append(key)
	if _cache_keys.size() > 64:
		_path_cache.erase(_cache_keys.pop_front())
