shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(0.05, 0.05, 0.3, 1.0);     // dark navy
uniform vec4 color_horizon : source_color = vec4(0.5, 0.7, 0.95, 1.0);  // pale blue

void fragment() {
    float t = UV.y;
    COLOR = mix(color_top, color_horizon, t);
}
