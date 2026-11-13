class_name TacticalRadar
extends Control
## رادار تاکتیکی زنده ۲بعدی در بخش پایینی صفحه (موقعیت بازیکن، هم‌تیمی، دشمنان، مناطق و آیتم‌ها).

var _redraw_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_redraw_timer += delta
	if _redraw_timer >= 0.075:
		_redraw_timer = 0.0
		queue_redraw()


func _world_to_radar(world_pos: Vector3, arena_half: Vector2, pad: float) -> Vector2:
	var usable_w: float = maxf(16.0, size.x - pad * 2.0)
	var usable_h: float = maxf(16.0, size.y - pad * 2.0)
	var nx: float = clampf((world_pos.x + arena_half.x) / (arena_half.x * 2.0), 0.0, 1.0)
	var nz: float = clampf((world_pos.z + arena_half.y) / (arena_half.y * 2.0), 0.0, 1.0)
	return Vector2(pad + nx * usable_w, pad + nz * usable_h)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.054902, 0.082353, 0.141176, 0.76), true)
	draw_rect(rect, Color(0.219608, 0.741176, 0.972549, 0.52), false, 1.5)

	var pad: float = 7.0
	var inner := Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0))
	draw_line(Vector2(inner.position.x + inner.size.x * 0.5, inner.position.y), Vector2(inner.position.x + inner.size.x * 0.5, inner.end.y), Color(1.0, 1.0, 1.0, 0.09), 1.0)
	draw_line(Vector2(inner.position.x, inner.position.y + inner.size.y * 0.5), Vector2(inner.end.x, inner.position.y + inner.size.y * 0.5), Color(1.0, 1.0, 1.0, 0.09), 1.0)

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var arena_half := Vector2(17.0, 12.0) if SaveManager.selected_map_id == "sector_02" else Vector2(16.0, 12.0)

	# 1. Capture Zones
	for z in tree.get_nodes_in_group("capture_zones"):
		if z is CaptureZonePad and (z as Node3D).visible:
			var pad_node := z as CaptureZonePad
			var rp: Vector2 = _world_to_radar(pad_node.global_position, arena_half, pad)
			var owner_t: int = pad_node.get_owner_team()
			var col := Color(0.58, 0.64, 0.72, 0.45)
			if owner_t == 0:
				col = Color(0.219608, 0.741176, 0.972549, 0.55)
			elif owner_t == 1:
				col = Color(0.984314, 0.45098, 0.086275, 0.55)
			draw_circle(rp, 9.0, Color(col.r, col.g, col.b, 0.25))
			draw_arc(rp, 9.0, 0.0, TAU, 18, col, 1.5, true)

	# 2. Explosive Crates
	for c in tree.get_nodes_in_group("explosive_crates"):
		if c is ExplosiveCrate and (c as ExplosiveCrate).is_intact():
			var cp: Vector2 = _world_to_radar((c as Node3D).global_position, arena_half, pad)
			draw_rect(Rect2(cp - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(0.984314, 0.45098, 0.086275, 0.85), true)

	# 3. Available Pickups
	for p in tree.get_nodes_in_group("arena_pickups"):
		if p is ArenaPickup and (p as ArenaPickup).is_available():
			var pk := p as ArenaPickup
			var pp: Vector2 = _world_to_radar(pk.global_position, arena_half, pad)
			var pcol := Color(0.062745, 0.72549, 0.505882, 0.9)
			if pk.pickup_type == ArenaPickup.PickupType.OVERCHARGE:
				pcol = Color(0.984314, 0.74902, 0.141176, 0.9)
			elif pk.pickup_type == ArenaPickup.PickupType.SPEED_BOOST:
				pcol = Color(0.752941, 0.517647, 0.988235, 0.9)
			draw_circle(pp, 2.3, pcol)

	# 4. Bots
	for b in tree.get_nodes_in_group("arena_bots"):
		if b is ArenaBot and (b as ArenaBot).is_alive():
			var ab := b as ArenaBot
			var bp: Vector2 = _world_to_radar(ab.global_position, arena_half, pad)
			var is_heavy: bool = (ab.profile != null and ab.profile.profile_id == &"heavy_sentinel")
			var bcol := Color(0.219608, 0.741176, 0.972549, 1.0) if ab.team_id == 0 else (Color(0.937255, 0.266667, 0.266667, 1.0) if is_heavy else Color(0.984314, 0.45098, 0.086275, 1.0))
			draw_circle(bp, 4.4 if is_heavy else 3.4, bcol)

	# 5. Player directional marker
	for pl in tree.get_nodes_in_group("player"):
		if pl is PlayerController and (pl as PlayerController).is_alive():
			var pc := pl as PlayerController
			var plp: Vector2 = _world_to_radar(pc.global_position, arena_half, pad)
			var yaw: float = pc.get_facing_yaw()
			var fwd := Vector2(-sin(yaw), -cos(yaw))
			var right := Vector2(-fwd.y, fwd.x)
			var tip: Vector2 = plp + fwd * 6.0
			var lpt: Vector2 = plp - fwd * 3.8 - right * 3.8
			var rpt: Vector2 = plp - fwd * 3.8 + right * 3.8
			draw_colored_polygon(PackedVector2Array([tip, rpt, lpt]), Color(0.972549, 0.988235, 1.0, 1.0))
			draw_arc(plp, 6.5, 0.0, TAU, 16, Color(0.219608, 0.741176, 0.972549, 0.7), 1.2, true)
