class_name SiteKit
extends RefCounted

## Collects a breach site's set dressing into one mesh: one surface per material, so a whole
## site is a handful of draw calls. Pieces carry their colour as vertex colour, so every prop
## in a site shares the same few materials. Lights are unshaded colour plus glow halos; there
## are no real lights and no shadows.

## Matte, lit by the sun and ambient: walls, rock, metal, ground clutter.
const SOLID := &"solid"
## Unshaded colour: lit windows, lamps, paint, warning lights.
const LIT := &"lit"
## The dead city's facade shader, for buildings with windows (see BreachCity.tower).
const CITY := &"city"

const CITY_SHADER := preload("res://Resources/Materials/breach_city.gdshader")

static var _solid: StandardMaterial3D
static var _lit: StandardMaterial3D
static var _shapes: Dictionary = {}

var _tools: Dictionary = {}
var _halos: Array[Array] = []

## The two shared vertex-colour materials. ShaderWarmup draws them while the menu is up.
static func solid_material() -> StandardMaterial3D:
	if _solid == null:
		_solid = StandardMaterial3D.new()
		_solid.vertex_color_use_as_albedo = true
		_solid.roughness = 0.9
	return _solid

static func lit_material() -> StandardMaterial3D:
	if _lit == null:
		_lit = StandardMaterial3D.new()
		_lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lit.vertex_color_use_as_albedo = true
	return _lit

## A box centred on `center`, turned `yaw` radians about the vertical.
func box(material: StringName, center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	shape(material, &"box", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), center), color)

## A box standing on the ground at `base`.
func block(material: StringName, base: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	box(material, base + Vector3.UP * size.y * 0.5, size, color, yaw)

## A cylinder standing on `base`. `top_ratio` 0 makes a cone.
func cylinder(material: StringName, base: Vector3, radius: float, height: float, color: Color, top_ratio: float = 1.0, segments: int = 8) -> void:
	var key := StringName("cyl_%d_%d" % [segments, roundi(top_ratio * 100.0)])
	shape(material, key, Transform3D(Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0)), base + Vector3.UP * height * 0.5), color)

## A squashed low-poly sphere centred on `center`, sized `size` across each axis.
func lump(material: StringName, center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	shape(material, &"sphere", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), center), color)

## A gable roof: a prism `size` wide, tall and long, ridge running along its length, base at `base`.
func roof(material: StringName, base: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	shape(material, &"prism", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), base + Vector3.UP * size.y * 0.5), color)

## A square beam from `from` to `to`: struts, lattices, booms, wires.
func beam(material: StringName, from: Vector3, to: Vector3, thickness: float, color: Color) -> void:
	var along := to - from
	var length := along.length()
	if length < 0.001:
		return
	var y := along / length
	var side := Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := y.cross(side).normalized()
	var z := x.cross(y)
	shape(material, &"box", Transform3D(Basis(x * thickness, y * length, z * thickness), from + along * 0.5), color)

## Any cached primitive under an arbitrary transform. Transforms must not mirror.
func shape(material: StringName, key: StringName, xform: Transform3D, color: Color) -> void:
	var arrays := _shape_arrays(key)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := xform.basis.inverse().transposed()
	if indices.is_empty():
		indices = PackedInt32Array(range(verts.size()))
	var st := _tool(material)
	for i in indices:
		st.set_color(color)
		st.set_normal((normal_basis * normals[i]).normalized())
		st.add_vertex(xform * verts[i])

## A ring of hills or mountains at `radius`, facing the player. Heights come from `seed_value`;
## the crest takes `crest` colour and the foot `foot`, so snow or haze can sit on the tops.
## The foot reaches below the floor so the edge of the ground never shows under it.
func ridge(radius: float, low: float, high: float, foot: Color, crest: Color, seed_value: int, segments: int = 64) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var heights := PackedFloat32Array()
	for i in segments:
		heights.append(rng.randf_range(low, high))
	var st := _tool(SOLID)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := Vector3(sin(a0) * radius, 0.0, cos(a0) * radius)
		var p1 := Vector3(sin(a1) * radius, 0.0, cos(a1) * radius)
		var h0 := heights[i]
		var h1 := heights[(i + 1) % segments]
		var mid := (p0 + p1) * 0.5 * 1.03 + Vector3.UP * (maxf(h0, h1) + (high - low) * 0.25)
		var inward := -((p0 + p1) * 0.5).normalized()
		var foot0 := p0 + Vector3.DOWN * 8.0
		var foot1 := p1 + Vector3.DOWN * 8.0
		var top0 := p0 + Vector3.UP * h0
		var top1 := p1 + Vector3.UP * h1
		_triangle(st, [foot0, foot1, top1], [foot, foot, crest], inward)
		_triangle(st, [foot0, top1, top0], [foot, crest, crest], inward)
		_triangle(st, [top0, top1, mid], [crest, crest, crest.lerp(foot, 0.3)], inward)

## A camera-facing glow, for lamps and warning lights. All of a site's halos are one multimesh.
func halo(at: Vector3, color: Color, size: float) -> void:
	_halos.append([at, color, size])

## The tool that writes facade buildings in BreachCity's format.
func city_tool() -> SurfaceTool:
	return _tool(CITY)

## Commits everything into one node: the merged mesh and the halos.
func build(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var mesh := ArrayMesh.new()
	for key in [SOLID, LIT, CITY]:
		if not _tools.has(key):
			continue
		(_tools[key] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(key))
	if mesh.get_surface_count() > 0:
		var body := MeshInstance3D.new()
		body.name = "Dressing"
		body.mesh = mesh
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(body)
	if not _halos.is_empty():
		var halos := MultiMesh.new()
		halos.transform_format = MultiMesh.TRANSFORM_3D
		halos.use_colors = true
		halos.instance_count = _halos.size()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		halos.mesh = quad
		for i in _halos.size():
			var entry: Array = _halos[i]
			halos.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * float(entry[2])), entry[0]))
			halos.set_instance_color(i, entry[1])
		var glow := GlowSprite.material(Color.WHITE, 0.85)
		glow.vertex_color_use_as_albedo = true
		var lights := MultiMeshInstance3D.new()
		lights.name = "Lights"
		lights.multimesh = halos
		lights.material_override = glow
		lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lights)
	return root

func _tool(material: StringName) -> SurfaceTool:
	if not _tools.has(material):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[material] = st
	return _tools[material]

func _material(key: StringName) -> Material:
	match key:
		LIT:
			return lit_material()
		CITY:
			var city := ShaderMaterial.new()
			city.shader = CITY_SHADER
			return city
	return solid_material()

## Godot draws clockwise triangles as front faces; wind each one to face along `normal`.
func _triangle(st: SurfaceTool, points: Array, colors: Array, normal: Vector3) -> void:
	var order := [0, 1, 2]
	if ((points[1] - points[0]) as Vector3).cross(points[2] - points[0]).dot(normal) > 0.0:
		order = [0, 2, 1]
	for k in order:
		st.set_color(colors[k])
		st.set_normal(normal)
		st.add_vertex(points[k])

## Unit primitives (1 m across, centred), built once and shared by every site.
static func _shape_arrays(key: StringName) -> Array:
	if _shapes.has(key):
		return _shapes[key]
	var mesh: PrimitiveMesh
	var name := String(key)
	if key == &"box":
		mesh = BoxMesh.new()
	elif key == &"sphere":
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh = sphere
	elif key == &"prism":
		mesh = PrismMesh.new()
	elif name.begins_with("cyl_"):
		var parts := name.split("_")
		var cylinder := CylinderMesh.new()
		cylinder.bottom_radius = 0.5
		cylinder.top_radius = 0.5 * float(parts[2]) / 100.0
		cylinder.height = 1.0
		cylinder.radial_segments = int(parts[1])
		cylinder.rings = 1
		mesh = cylinder
	var arrays := mesh.get_mesh_arrays()
	_shapes[key] = arrays
	return arrays
