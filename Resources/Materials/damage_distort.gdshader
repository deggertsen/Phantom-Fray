shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

// Screen-reading radial smear. The quad stays hidden until a hit, then fades out.
// https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - vec2(0.5);
	float dist = length(from_center);
	float edge = smoothstep(0.02, 0.68, dist);

	float ripple = sin(dist * 26.0 - TIME * 16.0) * strength * 0.01 * edge;
	vec2 warped = uv + from_center * (strength * 0.05 + ripple);

	vec4 blurred = vec4(0.0);
	for (int i = 0; i < 6; i++) {
		float t = float(i) / 5.0;
		vec2 sample_uv = mix(uv, warped, t);
		vec2 split = from_center * strength * 0.014 * t;
		blurred.r += texture(screen_texture, sample_uv + split).r;
		blurred.g += texture(screen_texture, sample_uv).g;
		blurred.b += texture(screen_texture, sample_uv - split).b;
	}
	blurred /= 6.0;

	float presence = strength * mix(0.2, 0.82, edge);
	ALBEDO = blurred.rgb;
	ALPHA = presence;
}
