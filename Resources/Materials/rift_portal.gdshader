shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform vec4 inner_color : source_color = vec4(0.2, 0.65, 1.0, 1.0);
uniform vec4 outer_color : source_color = vec4(0.08, 0.0, 0.35, 1.0);
uniform vec4 rim_color : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform float spiral_speed : hint_range(0.1, 3.0) = 1.0;
uniform float spiral_density : hint_range(1.0, 10.0) = 4.0;
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
	vec2 pos = UV - vec2(0.5);
	float dist = length(pos);
	float angle = atan(pos.y, pos.x);
	float instability = 1.0 - health_ratio;
	float spiral = sin(angle * spiral_density + TIME * spiral_speed * time_scale * (1.0 + instability) + dist * 12.0);
	float pulse = sin(TIME * pulse_speed * time_scale * (1.0 + instability * 1.5)) * 0.5 + 0.5;
	float radial = 1.0 - smoothstep(0.08, 0.5, dist);
	float breakup = fract(sin(dot(floor(UV * 24.0), vec2(12.9898, 78.233))) * 43758.5453);
	float integrity = smoothstep(instability * 0.75 - 0.15, instability * 0.75 + 0.2, breakup);
	float portal = clamp((spiral * 0.35 + 0.65) * (pulse * 0.35 + 0.65) * radial, 0.0, 1.0);
	vec3 weakened = mix(vec3(0.9, 0.2, 0.35), outer_color.rgb, health_ratio);
	vec3 color = mix(weakened, inner_color.rgb, portal);
	float rim = smoothstep(0.28, 0.39, dist) * (1.0 - smoothstep(0.39, 0.5, dist));
	color = mix(color, rim_color.rgb, rim * (0.45 + damage_flash * 0.55));
	color += vec3(1.0, 0.28, 0.15) * damage_flash;
	float edge_fade = 1.0 - smoothstep(0.44, 0.5, dist);
	float dissolve_mask = smoothstep(dissolve_amount - 0.12, dissolve_amount + 0.08, breakup + (1.0 - dist) * 0.2);
	float alpha = edge_fade * mix(1.0, integrity, instability * 0.8) * dissolve_mask;
	ALBEDO = color;
	ALPHA = alpha;
	EMISSION = color * (0.55 + health_ratio * 0.55 + damage_flash) * intensity;
}
