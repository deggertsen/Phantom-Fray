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
// The training chamber: 1 draws the body as a hologram, scanlines climbing through it.
uniform float hologram : hint_range(0.0, 1.0) = 0.0;
// A paused hologram: 0 or more stops the sway, the flap, and the scanlines at that moment.
uniform float frozen_time = -1.0;

varying vec3 world_vertex;

float clock() {
	return (frozen_time >= 0.0 ? frozen_time : TIME) + phase_offset;
}

void vertex() {
	float t = clock();
	VERTEX.x += sin(t * sway_speed + VERTEX.z * 3.2) * UV2.x;
	float beat = sin(t * flap_speed + VERTEX.z * 1.5);
	VERTEX.y += mix(beat, abs(beat), snap) * UV2.y;
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = clock();
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
	if (hologram > 0.0) {
		// Scanlines in world height, so they read as a projection rather than a skin. Paused,
		// they stop and the body takes Chen's cyan.
		bool paused = frozen_time >= 0.0;
		float band = sin(world_vertex.y * 140.0 - t * 9.0) * 0.5 + 0.5;
		float sweep = smoothstep(0.9, 1.0, sin(world_vertex.y * 3.0 - t * 2.4));
		float flicker = paused ? 1.0 : 0.9 + 0.1 * sin(TIME * 37.0 + phase_offset);
		vec3 tint = paused ? vec3(0.35, 0.9, 1.0) : base_color.rgb;
		vec3 holo = col * (0.6 + band * 0.6) + tint * sweep * 0.5;
		if (paused) {
			holo = mix(holo, tint * (0.35 + band * 0.4), 0.3);
		}
		col = mix(col, holo, hologram);
		alpha = mix(alpha, alpha * (0.55 + band * 0.45) * flicker + sweep * 0.25 * COLOR.r, hologram);
	}
	ALBEDO = col;
	ALPHA = clamp(max(alpha * base_color.a, burn), 0.0, 1.0);
}
