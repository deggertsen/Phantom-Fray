shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

// The rift: a black void with violet bands swirling into it, light leaking from the far
// side, and a ragged white-hot edge. As it weakens it shrinks, its bands spin faster, and
// cracks spread across its face. RiftManager drives health_ratio, damage_flash,
// dissolve_amount and intensity.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform vec4 inner_color : source_color = vec4(0.35, 0.08, 0.75, 1.0);
uniform vec4 outer_color : source_color = vec4(0.012, 0.004, 0.03, 1.0);
uniform vec4 rim_color : source_color = vec4(0.95, 0.82, 1.0, 1.0);
uniform float spiral_speed : hint_range(0.1, 3.0) = 0.6;
uniform float spiral_density : hint_range(1.0, 10.0) = 5.0;
uniform float pulse_speed : hint_range(0.1, 5.0) = 2.0;
uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

void vertex() {
	mat4 modified_model_view = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = modified_model_view;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 dir = p / max(r, 0.0001);
	float t = TIME * time_scale;
	float instability = 1.0 - health_ratio;

	float edge_noise = texture(noise_tex, dir * 0.14 + vec2(t * 0.03, 0.5)).r;
	float edge_r = (0.48 + (edge_noise - 0.5) * (0.3 + instability * 0.25)) * mix(0.75, 1.0, health_ratio);
	edge_r *= 1.0 + sin(t * pulse_speed) * 0.015;

	float twist = atan(p.y, p.x) + r * spiral_density - t * spiral_speed * (1.0 + instability);
	float swirl = texture(noise_tex, vec2(cos(twist), sin(twist)) * r * 0.45 + vec2(0.5, t * 0.03)).r;
	float inside = 1.0 - smoothstep(edge_r - 0.02, edge_r + 0.01, r);
	vec3 band = mix(inner_color.rgb, vec3(1.0, 0.22, 0.68), smoothstep(0.55, 0.8, swirl));
	vec3 col = mix(outer_color.rgb, band, smoothstep(0.45, 0.72, swirl) * smoothstep(0.0, edge_r, r));
	col += rim_color.rgb * exp(-r * 9.0) * 0.8;

	float rim = exp(-abs(r - edge_r) * 45.0);
	col += rim_color.rgb * rim * (1.2 + damage_flash);
	float outer = exp(-max(r - edge_r, 0.0) * 7.0) * (1.0 - inside);
	col = mix(col, inner_color.rgb * 0.8, (1.0 - inside) * (1.0 - rim));
	col += vec3(1.0, 0.3, 0.6) * damage_flash * inside * 0.5;

	float crack = pow(1.0 - abs(texture(noise_tex, p * 0.6 + 0.2).r * 2.0 - 1.0), 30.0) * instability;
	col += rim_color.rgb * crack * inside * 1.5;

	float alpha = max(inside, max(rim, outer * 0.5)) * (1.0 - smoothstep(0.85, 1.0, r));
	float breakup = texture(noise_tex, UV * 1.3).r;
	alpha *= smoothstep(dissolve_amount - 0.12, dissolve_amount + 0.08, breakup + (1.0 - r) * 0.2);
	ALBEDO = col * intensity;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
