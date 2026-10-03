shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

// Additive visor hit. This does not read the screen, so it stays visible on the Quest.
// https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hit_color : source_color = vec4(1.0, 0.08, 0.12, 1.0);

void fragment() {
	vec2 from_center = UV - vec2(0.5);
	float dist = length(from_center);
	float vignette = smoothstep(0.05, 0.62, dist);
	float ring_radius = mix(0.08, 0.48, 1.0 - strength);
	float ring = exp(-pow((dist - ring_radius) * 14.0, 2.0));
	float core = exp(-dist * 3.2) * strength;
	float flash = strength * (0.35 + vignette * 1.15) + ring * strength * 1.4 + core * 0.45;
	ALBEDO = hit_color.rgb * flash;
	ALPHA = clamp(flash, 0.0, 1.0);
}
