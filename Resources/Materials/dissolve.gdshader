shader_type spatial;
render_mode blend_mix, cull_back;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 impact_point = vec3(0.0);
uniform vec3 dissolve_direction = vec3(0.0, 1.0, 0.0);
uniform vec4 base_color : source_color = vec4(0.55, 0.25, 1.0, 0.88);
uniform vec4 edge_color : source_color = vec4(0.9, 0.65, 1.0, 1.0);
uniform float alert : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_vertex;

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 direction = length(dissolve_direction) > 0.001 ? normalize(dissolve_direction) : vec3(0.0, 1.0, 0.0);
	float directional = dot(world_vertex - impact_point, direction) * 0.08;
	vec2 grid = floor(UV * 18.0) / 18.0;
	float noise_a = fract(sin(dot(grid, vec2(12.9898, 78.233))) * 43758.5453);
	float noise_b = fract(sin(dot(grid * 1.7 + directional, vec2(39.3468, 11.135))) * 24634.6345);
	float noise = mix(noise_a, noise_b, 0.55);
	float threshold = dissolve_amount * 1.2 - 0.1;
	float visible = smoothstep(threshold - 0.12, threshold + 0.04, noise) * (1.0 - step(0.999, dissolve_amount));
	if (visible < 0.02) {
		discard;
	}
	float edge = 1.0 - smoothstep(threshold + 0.01, threshold + 0.16, noise);
	ALBEDO = mix(base_color.rgb, edge_color.rgb, max(edge, alert * 0.35));
	EMISSION = edge_color.rgb * edge * (2.2 + alert * 3.4) + base_color.rgb * (0.25 + alert * 1.15);
	ALPHA = base_color.a * visible;
}
