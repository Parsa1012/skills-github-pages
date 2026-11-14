class_name ArenaCollisionDebugOverlay
extends Node3D
## Debug-only runtime wireframe for active collision shapes (F3 or touchscreen toggle).

var enabled: bool = false
var _refresh_timer: float = 0.0


func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	set_process(value)
	_refresh_timer = 0.0
	if value:
		_rebuild()
	else:
		_clear()


func _process(delta: float) -> void:
	if not enabled:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.30:
		_refresh_timer = 0.0
		_rebuild()


func _clear() -> void:
	for child in get_children():
		child.queue_free()


func _rebuild() -> void:
	_clear()
	if get_tree() == null or get_tree().current_scene == null:
		return
	var shapes: Array[Node] = []
	_collect_shapes(get_tree().current_scene, shapes)
	for node in shapes:
		var shape_node := node as CollisionShape3D
		if shape_node == null or shape_node.disabled or shape_node.shape == null:
			continue
		var mesh := _make_wire_mesh(shape_node)
		if mesh != null:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)


func _collect_shapes(node: Node, result: Array[Node]) -> void:
	if node is CollisionShape3D:
		result.append(node)
	for child in node.get_children():
		_collect_shapes(child, result)


func _make_wire_mesh(shape_node: CollisionShape3D) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var color := Color(0.20, 0.80, 1.0, 0.95)
	var body := shape_node.get_parent() as CollisionObject3D
	if body != null and (body.collision_layer & 1) != 0:
		color = Color(1.0, 0.55, 0.16, 0.95)
	mesh.surface_set_color(color)
	var transform := shape_node.global_transform
	if shape_node.shape is BoxShape3D:
		_draw_box(mesh, transform, (shape_node.shape as BoxShape3D).size * 0.5)
	elif shape_node.shape is CapsuleShape3D:
		_draw_capsule(mesh, transform, shape_node.shape as CapsuleShape3D)
	elif shape_node.shape is SphereShape3D:
		_draw_sphere(mesh, transform, (shape_node.shape as SphereShape3D).radius)
	elif shape_node.shape is CylinderShape3D:
		_draw_cylinder(mesh, transform, shape_node.shape as CylinderShape3D)
	else:
		mesh.surface_end()
		return null
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	mesh.surface_set_material(0, material)
	return mesh


func _line(mesh: ImmediateMesh, transform: Transform3D, a: Vector3, b: Vector3) -> void:
	mesh.surface_add_vertex(transform * a)
	mesh.surface_add_vertex(transform * b)


func _draw_box(mesh: ImmediateMesh, transform: Transform3D, half: Vector3) -> void:
	var c: Array[Vector3] = []
	for z in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for x in [-1.0, 1.0]:
				c.append(Vector3(x * half.x, y * half.y, z * half.z))
	for i in c.size():
		for j in range(i + 1, c.size()):
			var delta := c[i] - c[j]
			if (
				absf(delta.x) + absf(delta.y) + absf(delta.z) > 0.001
				and (
					(
						int(absf(delta.x) > 0.001)
						+ int(absf(delta.y) > 0.001)
						+ int(absf(delta.z) > 0.001)
					)
					== 1
				)
			):
				_line(mesh, transform, c[i], c[j])


func _draw_sphere(mesh: ImmediateMesh, transform: Transform3D, radius: float) -> void:
	for axis in range(3):
		for i in 24:
			var a := TAU * float(i) / 24.0
			var b := TAU * float(i + 1) / 24.0
			var p := Vector3(cos(a) * radius, sin(a) * radius, 0.0)
			var q := Vector3(cos(b) * radius, sin(b) * radius, 0.0)
			if axis == 1:
				p = Vector3(p.x, 0.0, p.y)
				q = Vector3(q.x, 0.0, q.y)
			elif axis == 2:
				p = Vector3(0.0, p.x, p.y)
				q = Vector3(0.0, q.x, q.y)
			_line(mesh, transform, p, q)


func _draw_cylinder(mesh: ImmediateMesh, transform: Transform3D, shape: CylinderShape3D) -> void:
	for i in 24:
		var a := TAU * float(i) / 24.0
		var b := TAU * float(i + 1) / 24.0
		for y in [-shape.height * 0.5, shape.height * 0.5]:
			_line(
				mesh,
				transform,
				Vector3(cos(a) * shape.radius, y, sin(a) * shape.radius),
				Vector3(cos(b) * shape.radius, y, sin(b) * shape.radius)
			)
		if i % 6 == 0:
			_line(
				mesh,
				transform,
				Vector3(cos(a) * shape.radius, -shape.height * 0.5, sin(a) * shape.radius),
				Vector3(cos(a) * shape.radius, shape.height * 0.5, sin(a) * shape.radius)
			)


func _draw_capsule(mesh: ImmediateMesh, transform: Transform3D, shape: CapsuleShape3D) -> void:
	var radius := shape.radius
	var half_core := maxf(0.0, shape.height * 0.5 - radius)
	for i in 24:
		var a := TAU * float(i) / 24.0
		var b := TAU * float(i + 1) / 24.0
		for y in [-half_core, half_core]:
			_line(
				mesh,
				transform,
				Vector3(cos(a) * radius, y, sin(a) * radius),
				Vector3(cos(b) * radius, y, sin(b) * radius)
			)
		if i % 6 == 0:
			_line(
				mesh,
				transform,
				Vector3(cos(a) * radius, -half_core, sin(a) * radius),
				Vector3(cos(a) * radius, half_core, sin(a) * radius)
			)
