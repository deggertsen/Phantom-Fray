shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_test_disabled, diffuse_burley, specular_schlick_ggx;

uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform vec4 inner_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 outer_color : source_color = vec4(0.0, 0.0, 0.8, 1.0);
uniform vec4 rim_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float spiral_speed : hint_range(0.1, 3.0) = 1.0;
uniform float spiral_density : hint_range(1.0, 10.0) = 4.0;
uniform float pulse_speed : hint_range(0.1, 3.0) = 2.0;

void vertex() {
	// Billboard effect: make the quad always face the camera
	mat4 modified_model_view = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1], 
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = modified_model_view;
}

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 pos = UV - center;
	
	float dist = length(pos);
	float angle = atan(pos.y, pos.x);
	
	// Create spiral pattern
	float spiral = sin(angle * spiral_density + TIME * spiral_speed * time_scale + dist * 10.0);
	
	// Add pulsing effect
	float pulse = sin(TIME * pulse_speed * time_scale) * 0.5 + 0.5;
	
	// Create radial gradient
	float radial = 1.0 - smoothstep(0.1, 0.5, dist);
	
	// Combine effects
	float intensity = spiral * pulse * radial;
	intensity = clamp(intensity, 0.0, 1.0);
	
	// Mix colors based on distance from center
	vec4 color = mix(outer_color, inner_color, intensity);
	
	// Add rim glow
	float rim = 1.0 - smoothstep(0.4, 0.5, dist);
	color = mix(color, rim_color, rim * 0.3);
	
	// Fade edges
	float edge_fade = 1.0 - smoothstep(0.45, 0.5, dist);
	color.a *= edge_fade;
	
	ALBEDO = color.rgb;
	ALPHA = color.a;
	EMISSION = color.rgb * 0.8;
}
