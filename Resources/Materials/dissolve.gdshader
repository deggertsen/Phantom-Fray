shader_type spatial;
render_mode blend_mix, cull_back;

uniform float dissolve_amount : hint_range(0, 1) = 0;
uniform vec3 impact_point;
uniform vec3 dissolve_direction;

varying vec3 world_vertex;

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Get world position for directional effect
	vec3 dir_to_point = world_vertex - impact_point;
	float distance_along_direction = dot(dir_to_point, normalize(dissolve_direction));
	
	// Create very chunky noise pattern
	vec2 base_uv = UV * 0.4; // Much larger scale for bigger chunks
	float noise1 = fract(sin(dot(base_uv, vec2(12.9898, 78.233))) * 43758.5453);
	float noise2 = fract(sin(dot(base_uv * 1.5 + distance_along_direction * 0.1, vec2(78.233, 12.9898))) * 43758.5453);
	float noise = mix(noise1, noise2, 0.7);
	
	// Sharper thresholds for more defined chunks
	float edge_width = 0.15;
	float threshold = dissolve_amount;
	float edge = smoothstep(threshold - edge_width, threshold, noise);
	
	// Discard dissolved pixels
	if (edge < 0.01) {
		discard;
	}
	
	// Keep original color but add fire effect
	ALBEDO = mix(vec3(1.0, 0.2, 0.0), vec3(0.5, 0.2, 1.0), edge);
	
	// Strong emission at the edges
	float glow = (1.0 - edge) * 3.0;
	EMISSION = mix(vec3(1.0, 0.5, 0.0), vec3(0.7, 0.0, 0.0), edge) * glow;
	
	// Add some alpha for better blending
	ALPHA = edge;
}
