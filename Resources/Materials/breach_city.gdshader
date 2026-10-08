shader_type spatial;
render_mode unshaded;

// The dead city ring. Every tower shares this material and one mesh. BreachCity bakes:
//   UV     facade position in meters (across, up)
//   UV2.x  the tower's height, for the violet glow along its roofline
//   COLOR  r = tower seed, g = which face, b = 1 on roofs
// Almost every window is dark. The city fell silent.

uniform vec3 wall_color : source_color = vec3(0.014, 0.016, 0.028);
uniform vec3 roof_color : source_color = vec3(0.03, 0.02, 0.05);
uniform vec3 breach_color : source_color = vec3(0.45, 0.15, 0.9);

// A sin-free hash: the sin() kind repeats in visible clumps across a facade.
float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec3 col = wall_color + vec3(0.02, 0.012, 0.04) * smoothstep(0.0, 40.0, UV.y);
	if (COLOR.b > 0.5) {
		col = roof_color;
	} else {
		vec2 size = vec2(2.4, 3.2);
		vec2 cell = floor(UV / size);
		vec2 g = fract(UV / size);
		float window = step(0.22, g.x) * step(g.x, 0.78) * step(0.28, g.y) * step(g.y, 0.72) * step(2.0, UV.y);
		float h = hash(vec3(cell, COLOR.r * 91.0 + COLOR.g * 7.0));
		float lit = step(0.972, h);
		vec3 lamp = mix(vec3(1.0, 0.62, 0.32), vec3(0.45, 0.8, 1.0), step(0.992, h));
		// Far away, windows shrink below a pixel. Fade them to their average instead of shimmering.
		float detail = 1.0 - smoothstep(0.12, 0.4, max(fwidth(UV.x), fwidth(UV.y)) / size.x);
		col += mix(lamp * 0.0168, lamp * window * lit * 0.6, detail);
		col += vec3(0.02, 0.024, 0.04) * mix(0.3, window * (1.0 - lit), detail);
		col += breach_color * 0.07 * smoothstep(UV2.x - 6.0, UV2.x, UV.y);
	}
	ALBEDO = col;
}
