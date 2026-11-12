extends Node
## Lightweight Node object pool to prevent GC/allocation spikes on Samsung Galaxy A32.

var _pools: Dictionary = {}
var _scenes: Dictionary = {}


func register_pool(pool_id: StringName, scene: PackedScene, prewarm_count: int = 0) -> void:
	if scene == null:
		return
	_scenes[pool_id] = scene
	if not _pools.has(pool_id):
		_pools[pool_id] = []

	var bucket: Array = _pools[pool_id]
	for _i in prewarm_count:
		var instance: Node = scene.instantiate()
		_deactivate_node(instance)
		add_child(instance)
		bucket.append(instance)


func acquire(pool_id: StringName, parent_override: Node = null) -> Node:
	if not _scenes.has(pool_id):
		return null

	var bucket: Array = _pools.get(pool_id, [])
	var node: Node = null
	while not bucket.is_empty():
		var candidate: Variant = bucket.pop_back()
		if is_instance_valid(candidate):
			node = candidate as Node
			break

	if node == null:
		var scene: PackedScene = _scenes[pool_id]
		node = scene.instantiate()
	else:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)

	var target_parent: Node = parent_override if parent_override != null else get_tree().current_scene
	if target_parent != null:
		target_parent.add_child(node)

	_activate_node(node)
	return node


func release(pool_id: StringName, node: Node) -> void:
	if not is_instance_valid(node):
		return
	if not _pools.has(pool_id):
		_pools[pool_id] = []

	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_deactivate_node(node)
	add_child(node)

	var bucket: Array = _pools[pool_id]
	bucket.append(node)


func clear_all_pools() -> void:
	for pool_id in _pools.keys():
		var bucket: Array = _pools[pool_id]
		for item in bucket:
			if is_instance_valid(item):
				item.queue_free()
	_pools.clear()
	_scenes.clear()


func _deactivate_node(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	elif node is CanvasItem:
		(node as CanvasItem).visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED


func _activate_node(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is Node3D:
		(node as Node3D).visible = true
	elif node is CanvasItem:
		(node as CanvasItem).visible = true
