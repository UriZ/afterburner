shader_type spatial;
render_mode unshaded, cull_disabled;

// Uniforms for stage_manager.gd compatibility.
// color_a = light land tone, color_b = dark land tone.
uniform vec4 color_a : source_color = vec4(0.76, 0.60, 0.42, 1.0);
uniform vec4 color_b : source_color = vec4(0.45, 0.35, 0.22, 1.0);
uniform float scroll_speed : hint_range(0.0, 30.0) = 18.0;
uniform float tile_scale : hint_range(1.0, 64.0) = 20.0;
uniform float scroll_offset = 0.0;

// Sky color for horizon fade (matches sky horizon)
const vec3 SKY_HAZE = vec3(0.22, 0.52, 0.95);

void fragment() {
	vec2 uv = UV;

	// True scrolling: shift UV.y by scroll_offset so bands move toward the viewer.
	float scrolled_y = fract(uv.y - scroll_offset * 0.05);

	// Perspective compression: exponent 3.0 gives wide near bands, hairline at horizon.
	float perspective_y = pow(scrolled_y, 3.0);

	// Row index from perspective-compressed Y
	float row = floor(perspective_y * tile_scale);

	// Column index from X, scaled to tile_scale for square-ish cells
	float col = floor(uv.x * tile_scale);

	// Checkerboard: alternate cells based on row + column parity
	float checker = mod(row + col, 2.0);

	// Two-color checkerboard with strong contrast
	vec3 cell_color = mix(color_b.rgb, color_a.rgb, checker);

	// Horizon fade: top 20% of ground (UV.y close to 1.0 = far/horizon) fades to sky haze
	float horizon_fade = smoothstep(0.80, 1.0, uv.y);
	cell_color = mix(cell_color, SKY_HAZE, horizon_fade);

	ALBEDO = cell_color;
}
