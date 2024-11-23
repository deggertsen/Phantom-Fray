shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled;

uniform float dissolve_amount : hint_range(0, 1) = 0;
uniform vec3 impact_point;
uniform vec3 dissolve_direction;
uniform vec4 edge_color : source_color = vec4(1.0, 0.2, 0.0, 1.0);
uniform sampler2D noise_texture;

void fragment() {
	// Base color (ghostly purple)
	ALBEDO = vec3(0.5, 0.2, 1.0);
	
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir_to_point = world_pos - impact_point;
	float distance_along_direction = dot(dir_to_point, normalize(dissolve_direction));
	
	// Create more organic noise pattern
	vec2 noise_uv = UV + distance_along_direction * 0.1;
	float noise1 = fract(sin(dot(noise_uv, vec2(12.9898, 78.233))) * 43758.5453);
	float noise2 = fract(sin(dot(noise_uv * 2.0, vec2(78.233, 12.9898))) * 43758.5453);
	float noise = mix(noise1, noise2, 0.5);
	
	// Create burning edge effect
	float burn_size = 0.15;
	float burn_edge = smoothstep(dissolve_amount - burn_size, dissolve_amount, noise);
	
	// Create inner glow
	float inner_glow = smoothstep(dissolve_amount - burn_size * 2.0, dissolve_amount - burn_size, noise);
	
	if (burn_edge < 0.01) {
		discard;
	}
	
	// Mix colors for burning effect
	vec3 burn_color = mix(vec3(1.0, 0.0, 0.0), edge_color.rgb, burn_edge);  // Red core to orange edge
	EMISSION = burn_color * (1.0 - burn_edge) * 5.0 + vec3(1.0, 0.5, 0.0) * inner_glow * 2.0;
	ALPHA = burn_edge;
}
