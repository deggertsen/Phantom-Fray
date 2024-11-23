shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled;

uniform float dissolve_amount : hint_range(0, 1) = 0;
uniform vec3 impact_point;
uniform vec3 dissolve_direction;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);

void fragment() {
	// Base color (ghostly purple with transparency)
	ALBEDO = vec3(0.5, 0.2, 1.0);
	
	// Create directional noise based on world position and impact
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir_to_point = world_pos - impact_point;
	float distance_along_direction = dot(dir_to_point, normalize(dissolve_direction));
	
	// Create complex noise pattern
	vec2 noise_uv = UV * 3.0 + distance_along_direction * 0.1;
	float noise1 = fract(sin(dot(noise_uv, vec2(12.9898, 78.233))) * 43758.5453);
	float noise2 = fract(sin(dot(noise_uv * 2.0, vec2(78.233, 12.9898))) * 43758.5453);
	float noise3 = fract(sin(dot(noise_uv * 4.0, vec2(37.719, 95.457))) * 89432.3421);
	
	// Combine noise patterns for more organic look
	float noise = mix(noise1, noise2, 0.5);
	noise = mix(noise, noise3, 0.3);
	
	// Create burn effect thresholds
	float edge_width = 0.1;
	float core_threshold = dissolve_amount;
	float edge_threshold = core_threshold - edge_width;
	float glow_threshold = core_threshold - (edge_width * 2.0);
	
	// Calculate burn layers
	float burn_edge = smoothstep(edge_threshold, core_threshold, noise);
	float burn_glow = smoothstep(glow_threshold, edge_threshold, noise);
	
	// Discard pixels beyond the burn threshold
	if (noise < glow_threshold) {
		discard;
	}
	
	// Create color gradient from white core to orange edge to dark red
	vec3 burn_color = mix(vec3(1.0, 1.0, 1.0),      // White hot core
						 edge_color.rgb,              // Orange mid
						 burn_edge);
	burn_color = mix(vec3(0.5, 0.0, 0.0),           // Dark red outer
					burn_color,
					burn_glow);
	
	// Add strong emission for the burning effect
	EMISSION = burn_color * (1.0 - burn_edge) * 8.0;
	ALPHA = burn_glow;
}
