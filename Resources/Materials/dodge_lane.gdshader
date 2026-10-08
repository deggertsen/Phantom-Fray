shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// The Spearfin's lane: chevrons on the floor that run toward the player and point at them.
// UV.y is 0 at the player's end of the lane and 1 at the Spearfin's end.

uniform vec4 lane_color : source_color = vec4(1.0, 0.18, 0.62, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float lane_length = 10.0;

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float phase = fract(UV.y * lane_length * 1.3 - x * 0.9 + TIME * 2.6);
	float arrow = smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.3, 0.42, phase)) * (1.0 - smoothstep(0.7, 0.86, x));
	float edge = smoothstep(0.84, 0.93, x) * (1.0 - smoothstep(0.97, 1.0, x));
	float ends = smoothstep(0.0, 0.06, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	ALBEDO = lane_color.rgb;
	ALPHA = clamp((arrow * 0.75 + edge) * ends * strength, 0.0, 1.0);
}
