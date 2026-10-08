shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

// Life force draining: frost creeps in from the edges of view and pale veins glow along
// the path of the drain, pulsing with the heartbeat. Drawn on a quad just in front of the
// camera, and only while life force is below healthy.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float beat_rate = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float phase = fract(TIME * beat_rate);
	float beat = exp(-phase * 14.0) + 0.6 * exp(-abs(phase - 0.22) * 16.0);
	float coarse = 1.0 - abs(texture(noise_tex, p * 0.35 + 0.1).r * 2.0 - 1.0);
	float fine = 1.0 - abs(texture(noise_tex, p * 0.8 + vec2(0.3, TIME * 0.01)).r * 2.0 - 1.0);
	float veins = pow(coarse, 22.0) + pow(fine, 26.0) * 0.6;
	// The lower the life force, the further the frost creeps toward the center.
	float reach = mix(1.05, 0.4, strength);
	float mask = smoothstep(reach - 0.15, reach + 0.45, r + (texture(noise_tex, p * 0.5).r - 0.5) * 0.4);
	float frost = smoothstep(reach, reach + 0.55, r);
	vec3 vein_color = mix(vec3(0.62, 0.5, 1.0), vec3(0.75, 0.95, 1.0), fine);
	ALBEDO = mix(vec3(0.03, 0.04, 0.09), vein_color, clamp(veins * mask * 1.5, 0.0, 1.0));
	ALPHA = clamp((frost * 0.8 + veins * mask * (0.7 + 0.5 * beat)) * strength, 0.0, 1.0);
}
