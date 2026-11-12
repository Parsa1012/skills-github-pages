shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.095, 0.135, 0.205, 1.0);
uniform vec4 alt_tile_color : source_color = vec4(0.118, 0.165, 0.245, 1.0);
uniform vec4 grid_line_color : source_color = vec4(0.22, 0.45, 0.65, 1.0);
uniform vec4 center_line_color : source_color = vec4(0.22, 0.74, 0.97, 1.0);
uniform float tile_size = 2.0;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 tile_coord = floor(v_world_pos.xz / tile_size);
	float checker = mod(tile_coord.x + tile_coord.y, 2.0);
	vec3 col = mix(base_color.rgb, alt_tile_color.rgb, checker);

	vec2 f = abs(fract(v_world_pos.xz / tile_size + 0.5) - 0.5);
	float line_mask = 1.0 - smoothstep(0.015, 0.045, min(f.x, f.y));
	col = mix(col, grid_line_color.rgb, line_mask * 0.35);

	float center_mask = 1.0 - smoothstep(0.06, 0.16, abs(v_world_pos.x));
	col = mix(col, center_line_color.rgb, center_mask * 0.30);

	ALBEDO = col;
	ROUGHNESS = 0.88;
	METALLIC = 0.08;
}
