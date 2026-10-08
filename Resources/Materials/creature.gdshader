shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_never;

// Phantom creatures: dark translucent bodies, bright rims, tails that fray to nothing.
// Every body part lives in one mesh. CreatureMesh bakes what each vertex does:
//   COLOR.r  opacity (tails and filaments fade to 0)
//   COLOR.g  solidity (claws and bills read denser than the body)
//   COLOR.b  white-hot glow (eyes, teeth, lure stalk)
//   COLOR.a  brightness (the maw is nearly black)
//   UV2.x    sideways sway, UV2.y up-down flap or snap
// The dissolve uniforms keep the names Phantom has always driven.

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 impact_point = vec3(0.0);
uniform vec3 dissolve_direction = vec3(0.0, 1.0, 0.0);
uniform vec4 base_color : source_color = vec4(0.55, 0.25, 1.0, 0.88);
uniform vec4 edge_color : source_color = vec4(0.9, 0.65, 1.0, 1.0);
uniform float alert : hint_range(0.0, 1.0) = 0.0;
uniform float phase_offset = 0.0;
uniform float sway_speed = 2.6;
uniform float flap_speed = 4.0;
// 0: fins swing both ways. 1: jaws snap open and shut.
uniform float snap : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 world_vertex;

void vertex() {
	float t = TIME + phase_offset;
	VERTEX.x += sin(t * sway_speed + VERTEX.z * 3.2) * UV2.x;
	float beat = sin(t * flap_speed + VERTEX.z * 1.5);
	VERTEX.y += mix(beat, abs(beat), snap) * UV2.y;
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME + phase_offset;
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fres = pow(1.0 - facing, 2.0);
	float drift = texture(noise_tex, UV * vec2(2.0, 1.0) + vec2(0.0, -t * 0.22)).r;
	float grain = texture(noise_tex, UV * 0.7 + vec2(t * 0.04, 0.37)).r;

	// Burn outward from the punch.
	float reach = clamp(distance(world_vertex, impact_point) * 1.1, 0.0, 1.0);
	float field = mix(grain, reach, 0.45);
	float threshold = dissolve_amount * 1.15 - 0.08;
	if (field < threshold) {
		discard;
	}
	float burn = (1.0 - smoothstep(threshold, threshold + 0.08, field)) * step(0.001, dissolve_amount);

	float solid = COLOR.g;
	float glow = COLOR.b;
	vec3 deep = base_color.rgb * (0.08 + solid * 0.2);
	vec3 col = mix(deep, base_color.rgb * 1.15, fres) + vec3(pow(fres, 5.0) * 0.45);
	col += base_color.rgb * smoothstep(0.55, 0.8, drift) * 0.5;
	col = mix(col, mix(base_color.rgb, vec3(1.0), 0.72), glow);
	col += edge_color.rgb * alert * fres * 0.6;
	col *= COLOR.a;
	col = mix(col, edge_color.rgb + vec3(0.35), burn);

	float alpha = (0.42 + solid * 0.38 + fres * 0.6 + glow) * COLOR.r;
	alpha *= smoothstep(0.1, 0.5, drift + COLOR.r * 0.5);
	ALBEDO = col;
	ALPHA = clamp(max(alpha * base_color.a, burn), 0.0, 1.0);
}
