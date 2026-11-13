shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.56, 0.59, 0.62, 1.0);
uniform vec4 alt_tile_color : source_color = vec4(0.48, 0.51, 0.55, 1.0);
uniform vec4 grid_line_color : source_color = vec4(0.32, 0.36, 0.40, 1.0);
uniform vec4 center_line_color : source_color = vec4(0.86, 0.72, 0.24, 1.0);
uniform vec4 blue_zone_tint : source_color = vec4(0.14, 0.46, 0.80, 1.0);
uniform vec4 orange_zone_tint : source_color = vec4(0.84, 0.38, 0.14, 1.0);
uniform float tile_size = 4.0;
uniform float arena_half_x = 16.0;
uniform float arena_half_z = 12.0;
uniform float show_center_line = 1.0;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// نمونه‌برداری سریع بافت آسفالت واقعی برای حفظ ۶۰ فریم پایدار روی موبایل
	vec3 tex_col = texture(asphalt_tex, v_world_pos.xz / tile_size).rgb;
	vec3 col = tex_col * base_color.rgb * 1.45;

	// ته‌رنگ ملایم قلمرو تیم آبی و نارنجی روی زمین بتنی
	float blue_mask = smoothstep(-6.0, -14.0, v_world_pos.x);
	float orange_mask = smoothstep(6.0, 14.0, v_world_pos.x);
	col = mix(col, col * 0.75 + blue_zone_tint.rgb * 0.22, blue_mask * 0.55);
	col = mix(col, col * 0.75 + orange_zone_tint.rgb * 0.22, orange_mask * 0.55);

	// خط‌کشی تاکتیکی زرد/سفید وسط میدان نبرد
	float center_stripe = (1.0 - smoothstep(0.06, 0.13, abs(v_world_pos.x))) * show_center_line;
	col = mix(col, center_line_color.rgb, center_stripe * 0.55);

	// سایه‌روشن طبیعی کنار دیوارهای بتنی پیرامون نقشه
	float edge_x = abs(v_world_pos.x) / max(arena_half_x, 1.0);
	float edge_z = abs(v_world_pos.z) / max(arena_half_z, 1.0);
	float perimeter_vig = smoothstep(0.78, 1.02, max(edge_x, edge_z));
	col *= mix(1.0, 0.62, perimeter_vig);

	ALBEDO = col;
	ROUGHNESS = 0.92;
}
