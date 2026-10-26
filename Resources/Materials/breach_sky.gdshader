shader_type sky;

// Breach night: a near-black zenith and violet haze at the horizon, with the low cloud lit
// from below by the breach. Static on purpose: a sky that never changes is rendered into the
// radiance map once, not every frame.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 horizon_color : source_color = vec3(0.09, 0.055, 0.16);
uniform vec3 zenith_color : source_color = vec3(0.008, 0.01, 0.03);
uniform vec3 breach_color : source_color = vec3(0.45, 0.15, 0.9);
uniform vec3 boss_color : source_color = vec3(0.85, 0.12, 0.3);
// The boss turn, 0 to 1: the haze climbs, burns toward the boss's colour behind its rift, and
// puts the stars out. Set rarely: each change re-renders the radiance map.
uniform float boss_mood = 0.0;
// Where the boss's rift sits around the player, in radians. 0 is straight down -Z.
uniform float boss_azimuth = 0.0;

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, zenith_color, smoothstep(-0.02, 0.6 + boss_mood * 0.4, h));

	vec2 cloud_uv = d.xz / max(h + 0.18, 0.05);
	float cloud = texture(noise_tex, cloud_uv * 0.08).r;

	// The boss burns hardest behind its rift and still reaches all the way round. Kept dark so
	// the crimson tentacles and the pink phantoms stand out against it.
	float toward = 0.5 + 0.5 * dot(d.xz, vec2(sin(boss_azimuth), -cos(boss_azimuth)));
	float burn = boss_mood * mix(0.35, 1.0, toward * toward);
	vec3 under = mix(breach_color, boss_color * 0.7, burn);
	float low = exp(-max(h, 0.0) * mix(5.0, 2.2, burn)) * smoothstep(-0.06, 0.02, h);

	col += under * low * (0.14 + burn * 0.16);
	col += under * low * smoothstep(0.38, 0.75, cloud) * (0.3 + burn * 0.45);

	vec3 star_cell = floor(d * 280.0);
	float star = fract(sin(dot(star_cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	col += vec3(0.8, 0.85, 1.0) * step(0.9975, star) * smoothstep(0.08, 0.45, h) * (1.0 - smoothstep(0.42, 0.7, cloud)) * (1.0 - boss_mood);

	col = mix(col, horizon_color * 0.6, smoothstep(0.02, -0.06, h));
	COLOR = col;
}
