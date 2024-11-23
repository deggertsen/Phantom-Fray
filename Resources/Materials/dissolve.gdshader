shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled;

uniform float dissolve_amount : hint_range(0, 1) = 0;
uniform vec3 impact_point;
uniform vec3 dissolve_direction;
uniform vec4 edge_color : source_color = vec4(0.5, 0.2, 1.0, 1.0);

void fragment() {
	// Base color
	ALBEDO = vec3(0.5, 0.2, 1.0);  // Purple base color
	
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir_to_point = world_pos - impact_point;
	float distance_along_direction = dot(dir_to_point, normalize(dissolve_direction));
	
	float noise = fract(sin(dot(UV + distance_along_direction * 0.1, vec2(12.9898, 78.233))) * 43758.5453);
	float threshold = dissolve_amount;
	
	if (noise < threshold) {
		ALPHA = 0.0;
	} else {
		float edge = smoothstep(threshold - 0.1, threshold, noise);
		EMISSION = edge_color.rgb * (1.0 - edge) * 5.0;
		ALPHA = 1.0;
	}
}
