shader_type spatial;
render_mode unshaded;

// The breach site floor: wet dark concrete, the RSF deployment pad with its safe ring and
// pylon line, and violet corruption veins spreading from every open rift. The veins pull
// back as a rift weakens, so sealing progress shows on the ground.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 ground_color : source_color = vec3(0.022, 0.026, 0.04);
uniform vec3 rsf_color : source_color = vec3(0.08, 0.7, 1.0);
uniform vec3 breach_color : source_color = vec3(0.6, 0.22, 1.0);
uniform float safe_radius = 1.375;
uniform float pylon_radius = 6.5;
// Each open rift: x and y are its floor position (world X and Z), w is how hard it corrupts.
uniform vec4 rifts[4];
// The boss turn: veins racing out from a rift at (x, y) to z metres, under the player's feet.
uniform vec3 surge = vec3(0.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Distance to the nearest hexagon edge: 0.5 on the edge, 0 at the center.
float hex_edge(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return max(dot(q, vec2(0.5, 0.8660254)), q.x);
}

void fragment() {
	vec2 p = world_pos.xz;
	float d = length(p);
	float grain = texture(noise_tex, p * 0.05).r;
	vec3 col = ground_color + vec3(0.02, 0.022, 0.03) * grain;

	float vein = 1.0 - abs(texture(noise_tex, p * 0.035 + vec2(0.37, 0.11)).r * 2.0 - 1.0);
	vein = pow(vein, 22.0) * smoothstep(0.3, 0.6, texture(noise_tex, p * 0.011).r);
	float pool = 0.0;
	float reach = 0.0;
	for (int i = 0; i < 4; i++) {
		float rd = length(p - rifts[i].xy);
		pool += exp(-rd * 0.22) * rifts[i].w;
		reach += exp(-rd * 0.15) * rifts[i].w;
	}
	if (surge.z > 0.0) {
		reach = max(reach, smoothstep(surge.z, surge.z - 4.0, length(p - surge.xy)) * 1.2);
	}
	col += breach_color * 0.28 * pool;
	col += breach_color * vein * clamp(reach, 0.0, 1.0) * (0.8 + 0.4 * sin(TIME * 1.6 - d * 0.4));

	float pad = 1.0 - smoothstep(3.5, 6.8, d);
	col += rsf_color * smoothstep(0.43, 0.49, hex_edge(p * 1.25)) * pad * 0.16;
	col += rsf_color * exp(-abs(d - safe_radius) * 70.0) * 1.1;
	float dash = step(0.35, fract(atan(p.y, p.x) * 16.0 / PI));
	col += rsf_color * exp(-abs(d - pylon_radius) * 30.0) * 0.35 * dash;
	ALBEDO = col;
}
