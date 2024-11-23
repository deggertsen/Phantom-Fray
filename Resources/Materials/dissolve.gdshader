shader_type spatial;

uniform float dissolve_amount : hint_range(0, 1) = 0;
uniform vec3 impact_point;
uniform vec3 dissolve_direction;
uniform vec4 edge_color : source_color = vec4(0.5, 0.2, 1.0, 1.0);

void fragment() {
	// Convert vertex position to world space
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Calculate distance from impact point along dissolve direction
	vec3 dir_to_point = world_pos - impact_point;
	float distance_along_direction = dot(dir_to_point, normalize(dissolve_direction));
	
	// Create noise pattern
	float noise = fract(sin(dot(UV + distance_along_direction * 0.1, vec2(12.9898, 78.233))) * 43758.5453);
	
	// Adjust dissolve threshold based on distance
	float threshold = dissolve_amount - distance_along_direction * 0.1;
	float dissolve_value = step(threshold, noise);
	
	ALPHA = dissolve_value;
	if (dissolve_value < 0.1) {
		discard;
	}
	
	// Add glowing edge effect
	float edge = smoothstep(threshold - 0.1, threshold, noise);
	EMISSION = edge_color.rgb * (1.0 - edge) * 5.0;
}
