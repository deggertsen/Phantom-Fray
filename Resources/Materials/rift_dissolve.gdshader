shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled;

uniform float dissolve_amount : hint_range(0, 1) = 0;
uniform vec4 edge_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform vec4 base_color : source_color = vec4(0.0, 0.0, 1.0, 0.5);

void fragment() {
    ALBEDO = base_color.rgb;
    
    float noise = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);
    float threshold = dissolve_amount;
    
    if (noise < threshold) {
        ALPHA = 0.0;
    } else {
        float edge = smoothstep(threshold - 0.1, threshold, noise);
        EMISSION = edge_color.rgb * (1.0 - edge) * 5.0;
        ALPHA = base_color.a * edge;
    }
}