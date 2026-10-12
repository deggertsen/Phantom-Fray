extends Node3D
class_name MawEye

## The eye in The Maw's void. It opens during the turn and follows the player's head for the rest
## of the fight: the body never comes through, but something on the far side is looking at you.
## A procedural placeholder: a sphere with a slit pupil drawn by its shader. MawBoss sets `open`
## and calls `watch` every frame.
## See development/Exercise_Mechanics_Exploration.md, "The turn: opening phase two".

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 sclera : source_color = vec3(0.78, 0.66, 0.42);
uniform vec3 iris_color : source_color = vec3(1.0, 0.28, 0.12);
uniform float dilate = 0.0;
varying vec3 local_n;
void vertex() {
	local_n = normalize(VERTEX);
}
void fragment() {
	// The eye looks along its local -Z.
	float front = -local_n.z;
	float iris = smoothstep(0.78, 0.81, front);
	float ring = iris * (1.0 - smoothstep(0.88, 0.95, front));
	// A vertical slit, widest at the middle, that opens a little when it dilates.
	float slit_width = mix(0.05, 0.12, dilate) * (1.0 - clamp(pow(local_n.y / 0.6, 2.0), 0.0, 1.0));
	float pupil = (1.0 - smoothstep(slit_width, slit_width + 0.015, abs(local_n.x))) * smoothstep(0.8, 0.83, front);
	vec3 white = sclera * (0.25 + 0.75 * smoothstep(-0.2, 0.9, front));
	vec3 col = mix(white, iris_color * (0.55 + 0.6 * ring), iris);
	ALBEDO = mix(col, vec3(0.0), pupil);
}
"""

## How wide it is, in metres. MawBoss sizes it to the mouth.
@export var radius: float = 0.9
## 0 shut (a thin slit of a lid line), 1 fully open.
var open: float = 0.0

static var _shader: Shader
var _material: ShaderMaterial
var _body: MeshInstance3D
var _look: Basis = Basis.IDENTITY

static func shared_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader

func _ready() -> void:
	_body = MeshInstance3D.new()
	_body.name = "Eyeball"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	_body.mesh = sphere
	_material = ShaderMaterial.new()
	_material.shader = shared_shader()
	_body.material_override = _material
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	_apply()

## Turns toward `target` with a little lag, the way a large eye would.
func watch(target: Vector3, delta: float) -> void:
	var to_target := target - global_position
	if to_target.length_squared() < 0.01:
		return
	var wanted := Basis.looking_at(to_target.normalized(), Vector3.UP)
	_look = _look.slerp(wanted, clampf(delta * 4.0, 0.0, 1.0)).orthonormalized()
	_apply()

func set_dilate(amount: float) -> void:
	if _material:
		_material.set_shader_parameter("dilate", clampf(amount, 0.0, 1.0))

func _apply() -> void:
	if _body == null:
		return
	# Opening squashes the eye from a lid line to a full sphere, in its own frame.
	var lid := maxf(open, 0.04)
	_body.basis = _look * Basis.from_scale(Vector3(radius, radius * lid, radius))
	visible = open > 0.0
