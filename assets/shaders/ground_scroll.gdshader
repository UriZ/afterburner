shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color_a : source_color = vec4(0.76, 0.6, 0.42, 1.0);  // tan/sand
uniform vec4 color_b : source_color = vec4(0.65, 0.5, 0.35, 1.0);  // darker sand
uniform float scroll_speed : hint_range(0.0, 10.0) = 8.0;
uniform float tile_scale : hint_range(1.0, 64.0) = 20.0;
uniform float scroll_offset = 0.0;

void fragment() {
    vec2 uv = UV * tile_scale;
    uv.y += scroll_offset;
    float checker = mod(floor(uv.x) + floor(uv.y), 2.0);
    ALBEDO = mix(color_a, color_b, checker).rgb;
}
