shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform float dissolve_amount : hint_range(0, 1) = 0;
uniform vec3 impact_point;
uniform vec3 dissolve_direction;

void fragment() {
	// Create world-space based noise for larger chunks
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir_to_point = world_pos - impact_point;
	float distance_along_direction = dot(dir_to_point, normalize(dissolve_direction));
	
	// Create chunky noise pattern
	vec2 noise_uv = UV + distance_along_direction * 0.05;  // Reduced from 0.1 for larger chunks
	float noise1 = fract(sin(dot(noise_uv, vec2(12.9898, 78.233))) * 43758.5453);
	float noise2 = fract(sin(dot(noise_uv * 1.5, vec2(78.233, 12.9898))) * 43758.5453);
	float noise = mix(noise1, noise2, 0.5);
	
	// Create burning edge effect
	float burn_size = 0.2;  // Increased for wider burn effect
	float burn_edge = smoothstep(dissolve_amount - burn_size, dissolve_amount, noise);
	
	// Create intense inner glow
	float inner_glow = smoothstep(dissolve_amount - burn_size * 1.5, dissolve_amount - burn_size * 0.5, noise);
	
	if (burn_edge < 0.01) {
		discard;
	}
	
	// Create dramatic fire colors
	vec3 burn_color = mix(vec3(1.0, 0.3, 0.0),    // Bright orange core
						 vec3(0.7, 0.0, 0.0),      // Deep red edge
						 burn_edge);
	
	// Add white-hot center
	burn_color = mix(vec3(1.0, 1.0, 1.0), burn_color, inner_glow);
	
	// Strong emission for fire effect
	EMISSION = burn_color * (1.0 - burn_edge) * 10.0;  // Increased emission intensity
	ALPHA = burn_edge * 0.95;  // Slightly transparent to blend better
}
