shader_type sky;

// Breach night: a near-black zenith, violet haze at the horizon, and a glowing crack torn
// across the sky where the Breach opened. Static on purpose: a sky that never changes is
// rendered into the radiance map once, not every frame.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 horizon_color : source_color = vec3(0.09, 0.055, 0.16);
uniform vec3 zenith_color : source_color = vec3(0.008, 0.01, 0.03);
uniform vec3 breach_color : source_color = vec3(0.45, 0.15, 0.9);
uniform vec3 crack_color : source_color = vec3(1.0, 0.8, 1.0);
// Where the crack sits around the player, in radians. 0 is straight down -Z.
uniform float crack_azimuth = 0.0;

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, zenith_color, smoothstep(-0.02, 0.6, h));

	vec2 cloud_uv = d.xz / max(h + 0.18, 0.05);
	float cloud = texture(noise_tex, cloud_uv * 0.08).r;

	float az = mod(atan(d.x, -d.z) - crack_azimuth + PI, TAU) - PI;
	float el = asin(clamp(h, -1.0, 1.0));
	float wobble = texture(noise_tex, vec2(az * 0.12, 0.31)).r - 0.5;
	float line = 0.36 + 0.05 * sin(az * 2.3 + 0.6) + wobble * 0.09;
	float dist = abs(el - line);
	float span = 1.0 - smoothstep(0.6, 1.3, abs(az));
	float crack = exp(-dist * 220.0) * span;
	float glow = exp(-dist * 9.0) * span;

	col += mix(vec3(0.035, 0.03, 0.07), breach_color * 0.6, glow) * smoothstep(0.38, 0.75, cloud) * smoothstep(-0.02, 0.22, h);
	col += breach_color * glow * 0.38 * (0.5 + cloud);
	col += crack_color * crack * 1.1;

	vec3 star_cell = floor(d * 280.0);
	float star = fract(sin(dot(star_cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	col += vec3(0.8, 0.85, 1.0) * step(0.9975, star) * smoothstep(0.08, 0.45, h) * (1.0 - smoothstep(0.42, 0.7, cloud)) * (1.0 - glow);

	col = mix(col, horizon_color * 0.6, smoothstep(0.02, -0.06, h));
	COLOR = col;
}
