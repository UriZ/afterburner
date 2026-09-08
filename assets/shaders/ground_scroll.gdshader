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
	// 18 units/sec * 0.05 = 0.90 UV units/sec => ~1.1s full cycle.
	float scrolled_y = fract(uv.y - scroll_offset * 0.05);

	// Perspective compression: exponent 3.0 gives wide near bands, hairline at horizon.
	float perspective_y = pow(scrolled_y, 3.0);
	float band_value = fract(perspective_y * 20.0);

	// Stage-driven land colors derived from color_a / color_b uniforms
	vec3 land_dark   = color_b.rgb * 0.7;
	vec3 land_base   = color_b.rgb;
	vec3 land_mid    = mix(color_b.rgb, color_a.rgb, 0.5);
	vec3 land_light  = color_a.rgb;
	vec3 land_bright = min(color_a.rgb * 1.4, vec3(1.0));

	vec3 band_color;
	if (band_value < 0.20) {
		band_color = land_dark;
	} else if (band_value < 0.40) {
		band_color = land_base;
	} else if (band_value < 0.60) {
		band_color = land_mid;
	} else if (band_value < 0.80) {
		band_color = land_light;
	} else {
		band_color = land_bright;
	}

	// Horizon fade: top 20% of ground (UV.y close to 1.0 = far/horizon) fades to sky haze
	float horizon_fade = smoothstep(0.80, 1.0, uv.y);
	band_color = mix(band_color, SKY_HAZE, horizon_fade);

	ALBEDO = band_color;
}
