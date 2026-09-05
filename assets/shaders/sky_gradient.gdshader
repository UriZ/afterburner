shader_type sky;

uniform vec4 color_top : source_color = vec4(0.05, 0.05, 0.3, 1.0);     // dark navy
uniform vec4 color_horizon : source_color = vec4(0.5, 0.7, 0.95, 1.0);  // pale blue

void sky() {
	// EYEDIR.y goes from -1 (down) to +1 (up)
	// Map to 0 (horizon/bottom) to 1 (top)
	float t = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	// Invert: t=1 at top (dark), t=0 at bottom (light)
	COLOR = mix(color_horizon, color_top, t).rgb;
}
