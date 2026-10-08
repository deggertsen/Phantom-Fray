class_name BreachCity
extends RefCounted

## Static set dressing for the breach site. Each piece is merged into one mesh, so the
## whole skyline is one draw call.

const CITY_SHADER := preload("res://Resources/Materials/breach_city.gdshader")
const CYAN := Color(0.08, 0.7, 1.0)
const VIOLET := Color(0.6, 0.3, 1.0)

## A ring of dead towers 46 to 110 m out. Towers in front of the sky crack (toward -Z)
## stay low, so the crack is never hidden.
static func city(seed_value: int = 11) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for _i in 115:
		var angle := rng.randf() * TAU
		var radius := 46.0 + pow(rng.randf(), 0.8) * 64.0
		var center := Vector3(sin(angle) * radius, -0.5, cos(angle) * radius)
		var height := minf(rng.randf_range(8.0, 40.0), radius * 0.42)
		if absf(atan2(center.x, -center.z)) < 0.75:
			height = minf(height, radius * 0.3)
		var size := Vector3(rng.randf_range(5.0, 14.0), height, rng.randf_range(5.0, 14.0))
		var basis := Basis(Vector3.UP, rng.randf() * PI)
		if rng.randf() < 0.12:
			basis = basis * Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12))
		_tower(st, Transform3D(basis, center), size, rng.randf())
	var material := ShaderMaterial.new()
	material.shader = CITY_SHADER
	var city_mesh := MeshInstance3D.new()
	city_mesh.name = "DeadCity"
	city_mesh.mesh = st.commit()
	city_mesh.material_override = material
	city_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return city_mesh

## Broken concrete scattered between the pylons and the city.
static func rubble(seed_value: int = 5) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rock := SphereMesh.new()
	rock.radial_segments = 6
	rock.rings = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for _i in 42:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(8.5, 24.0)
		var size := rng.randf_range(0.25, 1.35)
		var shape := Basis.from_euler(Vector3(rng.randf() * 3.0, rng.randf() * 3.0, rng.randf() * 3.0))
		shape = shape * Basis.from_scale(Vector3(rng.randf_range(0.8, 1.8), rng.randf_range(0.4, 1.0), rng.randf_range(0.8, 1.8)) * size)
		st.append_from(rock, 0, Transform3D(shape, Vector3(sin(angle) * distance, size * 0.15, cos(angle) * distance)))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.065, 0.09)
	material.roughness = 0.9
	var rubble_mesh := MeshInstance3D.new()
	rubble_mesh.name = "Rubble"
	rubble_mesh.mesh = st.commit()
	rubble_mesh.material_override = material
	rubble_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return rubble_mesh

## Eight RSF field emitters on the boundary, turned 22.5 degrees so none stands between
## the player and a rift straight ahead. Shafts, strips and beacons are one mesh; the
## beacon halos are one multimesh.
static func pylons(radius: float = 6.5) -> Node3D:
	var root := Node3D.new()
	root.name = "RSFPylons"
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.1
	shaft.bottom_radius = 0.22
	shaft.height = 3.1
	shaft.radial_segments = 6
	shaft.rings = 1
	var strip := BoxMesh.new()
	strip.size = Vector3(0.035, 2.3, 0.02)
	var beacon := SphereMesh.new()
	beacon.radius = 0.11
	beacon.height = 0.22
	beacon.radial_segments = 4
	beacon.rings = 2
	var shafts := SurfaceTool.new()
	var cyan := SurfaceTool.new()
	var violet := SurfaceTool.new()
	for st in [shafts, cyan, violet]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var halos := MultiMesh.new()
	halos.transform_format = MultiMesh.TRANSFORM_3D
	halos.use_colors = true
	halos.instance_count = 8
	var halo_quad := QuadMesh.new()
	halo_quad.size = Vector2(1.0, 1.0)
	halos.mesh = halo_quad
	for i in 8:
		var angle := TAU * float(i) / 8.0 + TAU / 16.0
		var base := Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
		var facing := Basis.looking_at(-base.normalized(), Vector3.UP)
		var glow: SurfaceTool = cyan if i % 2 == 0 else violet
		shafts.append_from(shaft, 0, Transform3D(facing, base + Vector3.UP * 1.55))
		glow.append_from(strip, 0, Transform3D(facing, base + Vector3.UP * 1.55 + facing * Vector3(0.0, 0.0, -0.17)))
		glow.append_from(beacon, 0, Transform3D(facing, base + Vector3.UP * 3.3))
		halos.set_instance_transform(i, Transform3D(Basis(), base + Vector3.UP * 3.3))
		halos.set_instance_color(i, CYAN if i % 2 == 0 else VIOLET)
	var mesh := shafts.commit()
	cyan.commit(mesh)
	violet.commit(mesh)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.06, 0.075, 0.11)
	metal.metallic = 0.6
	metal.roughness = 0.4
	mesh.surface_set_material(0, metal)
	mesh.surface_set_material(1, _unshaded(CYAN))
	mesh.surface_set_material(2, _unshaded(VIOLET))
	var body := MeshInstance3D.new()
	body.name = "Emitters"
	body.mesh = mesh
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	var halo_material := GlowSprite.material(Color.WHITE, 0.85)
	halo_material.vertex_color_use_as_albedo = true
	var beacons := MultiMeshInstance3D.new()
	beacons.name = "BeaconGlow"
	beacons.multimesh = halos
	beacons.material_override = halo_material
	beacons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beacons)
	return root

static func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

## Four walls and a roof. UV is facade meters, UV2.x the tower height, COLOR.r its seed.
static func _tower(st: SurfaceTool, xform: Transform3D, size: Vector3, seed_value: float) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	var sides := [
		[Vector3.BACK, Vector3(-hx, 0.0, hz), Vector3(hx, 0.0, hz)],
		[Vector3.RIGHT, Vector3(hx, 0.0, hz), Vector3(hx, 0.0, -hz)],
		[Vector3.FORWARD, Vector3(hx, 0.0, -hz), Vector3(-hx, 0.0, -hz)],
		[Vector3.LEFT, Vector3(-hx, 0.0, -hz), Vector3(-hx, 0.0, hz)],
	]
	for f in sides.size():
		var a: Vector3 = sides[f][1]
		var b: Vector3 = sides[f][2]
		var width := a.distance_to(b)
		_face(st, xform, [[a, Vector2(0.0, 0.0)], [b, Vector2(width, 0.0)], [b + Vector3.UP * h, Vector2(width, h)], [a + Vector3.UP * h, Vector2(0.0, h)]],
			xform.basis * sides[f][0], Color(seed_value, float(f) / 4.0, 0.0, 1.0), h)
	_face(st, xform, [[Vector3(-hx, h, hz), Vector2.ZERO], [Vector3(hx, h, hz), Vector2.ZERO], [Vector3(hx, h, -hz), Vector2.ZERO], [Vector3(-hx, h, -hz), Vector2.ZERO]],
		xform.basis * Vector3.UP, Color(seed_value, 1.0, 1.0, 1.0), h)

## Godot draws clockwise triangles as front faces; wind each one to face along `normal`.
static func _face(st: SurfaceTool, xform: Transform3D, corners: Array, normal: Vector3, color: Color, height: float) -> void:
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var points := [xform * (corners[tri[0]][0] as Vector3), xform * (corners[tri[1]][0] as Vector3), xform * (corners[tri[2]][0] as Vector3)]
		var order := [0, 1, 2]
		if ((points[1] - points[0]) as Vector3).cross(points[2] - points[0]).dot(normal) > 0.0:
			order = [0, 2, 1]
		for k in order:
			st.set_normal(normal)
			st.set_color(color)
			st.set_uv(corners[tri[k]][1])
			st.set_uv2(Vector2(height, 0.0))
			st.add_vertex(points[k])
