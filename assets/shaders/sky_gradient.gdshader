shader_type sky;

// Uniforms kept for stage_manager.gd compatibility.
uniform vec4 color_top : source_color = vec4(0.02, 0.04, 0.25, 1.0);
uniform vec4 color_horizon : source_color = vec4(0.20, 0.40, 0.78, 1.0);

// Sky gradient stops (top to bottom) — deep arcade blues, no white haze
const vec3 SKY_TOP     = vec3(0.02, 0.04, 0.25);
const vec3 SKY_UPPER   = vec3(0.05, 0.12, 0.50);
const vec3 SKY_MID     = vec3(0.12, 0.28, 0.65);
const vec3 SKY_HORIZON = vec3(0.20, 0.40, 0.78);
const vec3 SKY_HAZE    = vec3(0.20, 0.40, 0.78);

// Cloud colors
const vec3 CLOUD_BRIGHT = vec3(0.92, 0.94, 1.00);
const vec3 CLOUD_MID    = vec3(0.78, 0.82, 0.92);
const vec3 CLOUD_SHADOW = vec3(0.60, 0.65, 0.78);

// Value noise with smooth interpolation (no blocky grid artifacts)
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep interpolation
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	v += value_noise(p) * 0.5;
	v += value_noise(p * 2.0) * 0.25;
	v += value_noise(p * 4.0) * 0.125;
	return v;
}

void sky() {
	float t = clamp(EYEDIR.y, 0.0, 1.0);

	// 5-stop gradient
	vec3 sky_color;
	if (t < 0.05) {
		sky_color = mix(SKY_HAZE, SKY_HORIZON, smoothstep(0.0, 0.05, t));
	} else if (t < 0.2) {
		sky_color = mix(SKY_HORIZON, SKY_MID, smoothstep(0.05, 0.2, t));
	} else if (t < 0.5) {
		sky_color = mix(SKY_MID, SKY_UPPER, smoothstep(0.2, 0.5, t));
	} else {
		sky_color = mix(SKY_UPPER, SKY_TOP, smoothstep(0.5, 1.0, t));
	}

	// Stage color tinting (30% influence)
	vec3 stage_sky = mix(color_horizon.rgb, color_top.rgb, t);
	sky_color = mix(sky_color, stage_sky, 0.3);

	// Clouds using smooth FBM noise — only in mid-sky band
	float cloud_band = smoothstep(0.05, 0.15, t) * smoothstep(0.6, 0.35, t);
	if (cloud_band > 0.0) {
		float angle_x = atan(EYEDIR.x, EYEDIR.z);
		vec2 cloud_uv = vec2(angle_x * 1.5 + TIME * 0.02, t * 4.0);
		float n = fbm(cloud_uv * 3.0);
		// Only draw clouds where noise is high (sparse coverage)
		float cloud_alpha = smoothstep(0.45, 0.65, n) * cloud_band * 0.7;
		vec3 cloud_col = mix(CLOUD_SHADOW, CLOUD_BRIGHT, smoothstep(0.5, 0.65, n));
		sky_color = mix(sky_color, cloud_col, cloud_alpha);
	}

	// Below horizon falloff
	if (EYEDIR.y < 0.0) {
		float below = clamp(-EYEDIR.y * 5.0, 0.0, 1.0);
		sky_color = mix(SKY_HORIZON, vec3(0.1, 0.15, 0.3), below);
	}

	COLOR = sky_color;
}
