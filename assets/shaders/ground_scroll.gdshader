shader_type spatial;
render_mode unshaded, cull_disabled;

// Uniforms for stage_manager.gd compatibility.
// color_a = light land tone, color_b = dark land tone.
uniform vec4 color_a : source_color = vec4(0.76, 0.60, 0.42, 1.0);
uniform vec4 color_b : source_color = vec4(0.45, 0.35, 0.22, 1.0);
uniform float scroll_speed : hint_range(0.0, 30.0) = 18.0;
uniform float tile_scale : hint_range(1.0, 64.0) = 20.0;
uniform float scroll_offset = 0.0;

// Sky haze uniform — set by stage_manager to match sky horizon color.
uniform vec4 sky_haze_color : source_color = vec4(0.8, 0.6, 0.4, 1.0);

// Extra terrain palette entries derived from the two stage colors
// These are computed in-shader from color_a / color_b so stage_manager
// only needs to set two uniforms.

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 4-octave FBM for large terrain patches
float terrain_noise(vec2 p) {
	float v = 0.0;
	v += value_noise(p)        * 0.50;
	v += value_noise(p * 2.3)  * 0.25;
	v += value_noise(p * 5.1)  * 0.125;
	v += value_noise(p * 11.0) * 0.0625;
	return v / 0.9375; // normalize to ~0..1
}

// Fine detail noise for rocky texture variation
float detail_noise(vec2 p) {
	float v = 0.0;
	v += value_noise(p * 8.0)  * 0.5;
	v += value_noise(p * 16.0) * 0.5;
	return v;
}

void fragment() {
	vec2 uv = UV;

	// Perspective compression: tiles near camera are wide, hairline at horizon.
	// Power 3.5 gives stronger effect than the old 3.0.
	float scrolled_y = fract(uv.y - scroll_offset * 0.05);
	float perspective_y = pow(scrolled_y, 3.5);

	// Terrain UV: X scaled wider near camera by the same perspective factor.
	// We compress X less aggressively (square root) so patches stay elongated.
	float px = (uv.x - 0.5) / max(perspective_y, 0.01);
	vec2 terrain_uv = vec2(px * 0.04, perspective_y * tile_scale * 0.08);

	// Large terrain patch noise
	float large = terrain_noise(terrain_uv);

	// Fine detail at higher frequency
	float fine = detail_noise(terrain_uv * 4.0);

	// Combine: large determines region, fine adds local variation
	float n = large * 0.7 + fine * 0.3;

	// Derive 4-color palette from the two stage colors:
	//   light   = color_a (sandy)
	//   mid     = lerp(a, b, 0.4) (dusty)
	//   dark    = color_b (rocky)
	//   accent  = lerp(b, vec3(0.2,0.15,0.08), 0.5) (dark crevice)
	vec3 light   = color_a.rgb;
	vec3 mid     = mix(color_a.rgb, color_b.rgb, 0.4);
	vec3 dark    = color_b.rgb;
	vec3 accent  = mix(color_b.rgb, vec3(0.18, 0.12, 0.06), 0.55);

	// Map noise value to palette with smooth transitions
	vec3 terrain_color;
	if (n < 0.3) {
		terrain_color = mix(accent, dark, smoothstep(0.0, 0.3, n));
	} else if (n < 0.55) {
		terrain_color = mix(dark, mid, smoothstep(0.3, 0.55, n));
	} else if (n < 0.78) {
		terrain_color = mix(mid, light, smoothstep(0.55, 0.78, n));
	} else {
		// Bright sandy highlights
		terrain_color = mix(light, light * 1.18, smoothstep(0.78, 1.0, n));
	}

	// Horizon fade: top 20% of ground fades to sky haze
	float horizon_fade = smoothstep(0.80, 1.0, uv.y);
	terrain_color = mix(terrain_color, sky_haze_color.rgb, horizon_fade);

	ALBEDO = terrain_color;
}
