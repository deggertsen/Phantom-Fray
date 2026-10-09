extends Node3D
class_name MawTentacle

## One of The Maw's limbs: a tapered tube drawn through a handful of world-space control points,
## from its root in the rift to its tip. A procedural placeholder until the tentacle art exists.
## MawBoss poses it every frame with set_path; the tentacle adds its own slow writhe on top.
## Visual only. The attacks it drives (the sweep, the slam) do their own detection.
## https://docs.godotengine.org/en/stable/classes/class_immediatemesh.html

const SEGMENTS := 40
const SIDES := 10
const SKIN := Color(0.22, 0.08, 0.33)
const GLOW := Color(0.85, 0.18, 0.42)

@export var base_radius: float = 0.95
@export var tip_radius: float = 0.07

## How far it undulates on its own, in metres at the tip.
var writhe: float = 0.3
## 0 lit, 1 spent: a slammed tentacle lies dim on the floor.
var dim: float = 0.0
## 0 to 1. Below 1 the tube is cut short from the tip back, as it slides out of the rift.
var reach: float = 1.0

var _points: Array[Vector3] = []
var _mesh: ImmediateMesh
var _material: StandardMaterial3D
var _time: float = 0.0
var _phase: float = 0.0

func _ready() -> void:

	top_level = true
	global_transform = Transform3D.IDENTITY
	_phase = randf() * TAU
	_mesh = ImmediateMesh.new()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _mesh
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.albedo_color = SKIN
	_material.roughness = 0.4
	_material.rim_enabled = true
	_material.rim = 0.9
	_material.rim_tint = 0.6
	_material.emission_enabled = true
	_material.emission = GLOW
	_material.emission_energy_multiplier = 0.35
	_material.vertex_color_use_as_albedo = true
	body.material_override = _material
	add_child(body)

## Control points from the root to the tip, in world space. Four or more.
func set_path(points: Array[Vector3]) -> void:
	_points = points

func path() -> Array[Vector3]:
	return _points

func tip() -> Vector3:
	return _points[_points.size() - 1] if not _points.is_empty() else global_position

func _process(delta: float) -> void:
	_time += delta
	_material.emission_energy_multiplier = lerpf(0.35, 0.05, dim)
	_material.albedo_color = SKIN.lerp(SKIN.darkened(0.5), dim)
	_rebuild()

func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _points.size() < 2 or reach <= 0.01:
		return
	var centers: Array[Vector3] = []
	var count := maxi(int(SEGMENTS * reach), 2)
	for i in count + 1:
		var t := float(i) / float(SEGMENTS)
		centers.append(_sample(t) + _undulation(t))
	# Parallel-transported frames keep the tube from twisting as it bends.
	var tangent := (centers[1] - centers[0]).normalized()
	var normal := tangent.cross(Vector3.UP)
	if normal.length_squared() < 0.001:
		normal = tangent.cross(Vector3.RIGHT)
	normal = normal.normalized()
	var rings: Array = []
	for i in centers.size():
		var forward := (centers[mini(i + 1, centers.size() - 1)] - centers[maxi(i - 1, 0)]).normalized()
		if forward.length_squared() < 0.0001:
			forward = tangent
		normal = (normal - forward * normal.dot(forward)).normalized()
		var binormal := forward.cross(normal)
		tangent = forward
		var t := float(i) / float(SEGMENTS)
		var radius := lerpf(base_radius, tip_radius, pow(t, 0.75))
		if i == centers.size() - 1 and reach >= 0.999:
			radius = tip_radius * 0.3
		rings.append([centers[i], normal, binormal, radius])
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings.size() - 1:
		for side in SIDES:
			var a := float(side) / SIDES * TAU
			var b := float(side + 1) / SIDES * TAU
			_quad(rings[i], rings[i + 1], a, b)
	_mesh.surface_end()

func _quad(near: Array, far: Array, a: float, b: float) -> void:
	var corners := [[near, a], [far, a], [far, b], [near, a], [far, b], [near, b]]
	for corner in corners:
		var ring: Array = corner[0]
		var angle: float = corner[1]
		var out: Vector3 = ring[1] * cos(angle) + ring[2] * sin(angle)
		# The underside, where suckers would be, is paler.
		var belly := clampf(-out.y, 0.0, 1.0)
		_mesh.surface_set_color(Color(0.5, 0.45, 0.55).lerp(Color.WHITE, belly))
		_mesh.surface_set_normal(out)
		_mesh.surface_add_vertex(ring[0] + out * float(ring[3]))

## Catmull-Rom through the control points, t from 0 at the root to 1 at the tip.
func _sample(t: float) -> Vector3:
	var spans := _points.size() - 1
	var x := clampf(t, 0.0, 1.0) * spans
	var i := mini(int(x), spans - 1)
	var u := x - i
	var p0 := _points[maxi(i - 1, 0)]
	var p1 := _points[i]
	var p2 := _points[i + 1]
	var p3 := _points[mini(i + 2, spans)]
	return 0.5 * (
		2.0 * p1
		+ (p2 - p0) * u
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * u * u * u
	)

## A slow travelling wave, growing toward the tip. The root stays planted in the rift.
func _undulation(t: float) -> Vector3:
	if writhe <= 0.0:
		return Vector3.ZERO
	var wave := t * t * writhe
	return Vector3(
		sin(_time * 1.7 + t * 7.0 + _phase),
		sin(_time * 1.3 + t * 5.0 + _phase * 1.7) * 0.6,
		cos(_time * 1.5 + t * 6.0 + _phase)
	) * wave
