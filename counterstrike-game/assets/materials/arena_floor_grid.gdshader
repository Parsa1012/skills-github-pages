shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.075, 0.11, 0.175, 1.0);
uniform vec4 alt_tile_color : source_color = vec4(0.098, 0.142, 0.22, 1.0);
uniform vec4 grid_line_color : source_color = vec4(0.18, 0.44, 0.68, 1.0);
uniform vec4 center_line_color : source_color = vec4(0.22, 0.74, 0.97, 1.0);
uniform vec4 blue_zone_tint : source_color = vec4(0.12, 0.48, 0.85, 1.0);
uniform vec4 orange_zone_tint : source_color = vec4(0.88, 0.36, 0.10, 1.0);
uniform float tile_size = 2.0;
uniform float arena_half_x = 16.0;
uniform float arena_half_z = 12.0;
uniform float show_center_line = 1.0;

varying vec3 v_world_pos;

float tile_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 tile_coord = floor(v_world_pos.xz / tile_size);
	vec2 local_uv = fract(v_world_pos.xz / tile_size);
	float checker = mod(tile_coord.x + tile_coord.y, 2.0);
	float rnd = tile_hash(tile_coord);

	// پایه صفحات زرهی با تنوع میکروسکوپی بین کاشی‌ها
	vec3 col = mix(base_color.rgb, alt_tile_color.rgb, checker);
	col *= 0.93 + 0.13 * rnd;

	// لبه برش‌خورده و شیار کاشی (Bevel + Seam)
	vec2 edge_dist = min(local_uv, 1.0 - local_uv);
	float min_edge = min(edge_dist.x, edge_dist.y);
	float seam_mask = 1.0 - smoothstep(0.012, 0.032, min_edge);
	float bevel_hl = smoothstep(0.032, 0.055, min_edge) * (1.0 - smoothstep(0.055, 0.095, min_edge));

	// ریزشبکه ۴تایی داخل هر کاشی
	vec2 sub_uv = fract(v_world_pos.xz / (tile_size * 0.5));
	vec2 sub_edge = min(sub_uv, 1.0 - sub_uv);
	float sub_line = 1.0 - smoothstep(0.008, 0.022, min(sub_edge.x, sub_edge.y));

	// نشانگر تقاطع گوشه‌ها (Crosshair Ticks)
	float corner_x = 1.0 - smoothstep(0.015, 0.032, edge_dist.x);
	float corner_y = 1.0 - smoothstep(0.015, 0.032, edge_dist.y);
	float corner_arm_x = 1.0 - smoothstep(0.08, 0.13, edge_dist.y);
	float corner_arm_y = 1.0 - smoothstep(0.08, 0.13, edge_dist.x);
	float cross_tick = max(corner_x * corner_arm_x, corner_y * corner_arm_y);

	col = mix(col, col * 0.45, seam_mask * 0.72);
	col = mix(col, grid_line_color.rgb * 1.15, bevel_hl * 0.24 + sub_line * 0.10);
	col = mix(col, grid_line_color.rgb * 1.45, cross_tick * 0.35);

	// ته‌رنگ ملایم قلمرو تیم آبی و نارنجی
	float blue_mask = smoothstep(-5.5, -13.5, v_world_pos.x);
	float orange_mask = smoothstep(5.5, 13.5, v_world_pos.x);
	col = mix(col, blue_zone_tint.rgb * 0.28, blue_mask * 0.42);
	col = mix(col, orange_zone_tint.rgb * 0.28, orange_mask * 0.42);

	// خط نوری مرکزی + حاشیه تیره پیرامون دیوارها
	float center_core = (1.0 - smoothstep(0.04, 0.11, abs(v_world_pos.x))) * show_center_line;
	float center_halo = (1.0 - smoothstep(0.10, 0.42, abs(v_world_pos.x))) * show_center_line;
	col = mix(col, center_line_color.rgb, center_core * 0.52 + center_halo * 0.12);

	float edge_x = abs(v_world_pos.x) / max(arena_half_x, 1.0);
	float edge_z = abs(v_world_pos.z) / max(arena_half_z, 1.0);
	float perimeter_vig = smoothstep(0.76, 1.02, max(edge_x, edge_z));
	col *= mix(1.0, 0.56, perimeter_vig);

	ALBEDO = col;
	METALLIC = clamp(mix(0.26, 0.56, bevel_hl) - seam_mask * 0.18, 0.05, 0.7);
	ROUGHNESS = clamp(0.62 - bevel_hl * 0.34 + seam_mask * 0.28, 0.24, 0.92);
	EMISSION = center_line_color.rgb * (center_core * 0.85 + center_halo * 0.12)
		+ grid_line_color.rgb * (cross_tick * 0.16);
}
