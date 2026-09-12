extends Node3D

const CYAN := Color(0.08, 0.7, 1.0, 1.0)
const VIOLET := Color(0.45, 0.12, 0.85, 1.0)
const DARK := Color(0.012, 0.018, 0.04, 1.0)

func _ready() -> void:
	_build_floor()
	_build_safe_ring()
	_build_pylons()
	_build_briefing_panel()

func _build_floor() -> void:
	var floor_mesh := get_node_or_null("../Floor/MeshInstance3D") as MeshInstance3D
	if floor_mesh:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.025, 0.035, 0.07)
		material.metallic = 0.35
		material.roughness = 0.72
		floor_mesh.material_override = material

func _build_safe_ring() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "SafeAreaRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.35
	torus.outer_radius = 1.4
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position.y = 0.015
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = CYAN
	material.emission_enabled = true
	material.emission = CYAN
	material.emission_energy_multiplier = 1.5
	ring.material_override = material
	add_child(ring)

func _build_pylons() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 3.4, 0.3)
	var materials := [_make_pylon_material(CYAN), _make_pylon_material(VIOLET)]
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var pylon := MeshInstance3D.new()
		pylon.name = "RSFPylon%d" % index
		pylon.mesh = box
		pylon.position = Vector3(sin(angle) * 6.5, 1.7, cos(angle) * 6.5)
		pylon.material_override = materials[index % 2]
		add_child(pylon)

func _make_pylon_material(emission_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = DARK
	material.metallic = 0.65
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = 0.55
	return material

func _build_briefing_panel() -> void:
	var label := Label3D.new()
	label.name = "RSFBriefing"
	label.text = "RSF // ERM TRAINING CHAMBER 07\nTHE BREACH IS ACTIVE"
	label.font_size = 42
	label.pixel_size = 0.003
	label.modulate = Color(0.45, 0.9, 1.0)
	label.outline_size = 10
	label.outline_modulate = DARK
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, 2.8, -6.0)
	add_child(label)
