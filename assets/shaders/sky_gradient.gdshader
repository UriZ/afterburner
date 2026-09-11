shader_type sky;

// Uniforms kept for stage_manager.gd compatibility.
uniform vec4 color_top : source_color = vec4(0.02, 0.04, 0.25, 1.0);
uniform vec4 color_horizon : source_color = vec4(0.20, 0.40, 0.78, 1.0);

// Sky gradient stops (top to bottom) — higher saturation arcade blues
const vec3 SKY_TOP     = vec3(0.01, 0.03, 0.30);
const vec3 SKY_UPPER   = vec3(0.04, 0.14, 0.58);
const vec3 SKY_MID     = vec3(0.10, 0.32, 0.78);
const vec3 SKY_HORIZON = vec3(0.22, 0.52, 0.95);
const vec3 SKY_HAZE    = vec3(0.22, 0.52, 0.95);

// Cloud colors
const vec3 CLOUD_BRIGHT = vec3(0.96, 0.97, 1.00);
const vec3 CLOUD_MID    = vec3(0.82, 0.86, 0.96);
const vec3 CLOUD_SHADOW = vec3(0.60, 0.65, 0.78);

// Value noise — operates on 3D direction to avoid any wrap seam
float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float value_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash3(i);
	float b = hash3(i + vec3(1.0, 0.0, 0.0));
	float c = hash3(i + vec3(0.0, 1.0, 0.0));
	float d = hash3(i + vec3(1.0, 1.0, 0.0));
	float e = hash3(i + vec3(0.0, 0.0, 1.0));
	float ff = hash3(i + vec3(1.0, 0.0, 1.0));
	float g = hash3(i + vec3(0.0, 1.0, 1.0));
	float h = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
	           mix(mix(e, ff, f.x), mix(g, h, f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	v += value_noise3(p) * 0.5;
	v += value_noise3(p * 2.0) * 0.25;
	v += value_noise3(p * 4.0) * 0.125;
	return v;
}

void sky() {
	float t = clamp(EYEDIR.y, 0.0, 1.0);

	// 5-stop gradient based purely on elevation — no horizontal angle, no seam
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

	// Clouds using 3D FBM noise on the eye direction — seamless, no wrap artifact
	float cloud_band = smoothstep(0.05, 0.15, t) * smoothstep(0.6, 0.35, t);
	if (cloud_band > 0.0) {
		// Animate by drifting the sample point along X over time
		vec3 cloud_dir = normalize(EYEDIR) * 3.0 + vec3(TIME * 0.04, 0.0, 0.0);
		float n = fbm3(cloud_dir);
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
