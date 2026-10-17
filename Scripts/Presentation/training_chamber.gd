extends Node3D
class_name TrainingChamber

## Chen's training chamber: a dark dome of projector grid over the play space that hides the
## dead city and the sky while training runs, so everything inside reads as a simulation.
## The rift and phantoms inside wear their own hologram look (the `hologram` shader uniforms).

const RADIUS := 16.0
const GRID := Color(0.1, 0.7, 1.0)
const DOME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;

uniform vec4 grid_color : source_color = vec4(0.1, 0.7, 1.0, 1.0);
uniform vec4 wall_color : source_color = vec4(0.006, 0.014, 0.032, 1.0);

varying vec3 local_vertex;

void vertex() {
	local_vertex = VERTEX;
}

void fragment() {
	vec3 d = normalize(local_vertex);
	// 48 panels round, 12 up the wall: a projector grid, brightest at eye level.
	vec2 cell = vec2(atan(d.x, d.z) / 6.2831853 * 48.0, asin(clamp(d.y, -1.0, 1.0)) / 1.5707963 * 12.0);
	vec2 edge = abs(fract(cell) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.04, 0.5 - max(edge.x, edge.y));
	float horizon = exp(-abs(d.y) * 5.0);
	float scan = smoothstep(0.985, 1.0, sin(d.y * 9.0 - TIME * 0.8));
	vec3 col = wall_color.rgb + grid_color.rgb * (line * (0.18 + horizon * 0.3) + scan * 0.1 + horizon * 0.04);
	ALBEDO = col;
}
"""

var _dome: MeshInstance3D

func _ready() -> void:
	visible = false

func set_active(on: bool) -> void:
	if on and _dome == null:
		_build()
	visible = on

func is_active() -> bool:
	return visible

func _build() -> void:
	_dome = MeshInstance3D.new()
	_dome.name = "Dome"
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_dome.mesh = sphere
	var shader := Shader.new()
	shader.code = DOME_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grid_color", GRID)
	_dome.material_override = material
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dome)
	# Centered on the play space, wherever the director sits in the scene.
	_dome.top_level = true
	_dome.global_position = Vector3.ZERO
