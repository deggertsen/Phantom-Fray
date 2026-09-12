extends Node3D

@export var hand_color: Color = Color(0.08, 0.72, 1.0)
@export var mirror_x: bool = false

func _ready() -> void:
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	core.mesh = sphere
	core.position = Vector3(-0.045 if mirror_x else 0.045, 0.005, -0.055)
	var core_material := StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = hand_color
	core_material.emission_enabled = true
	core_material.emission = hand_color
	core_material.emission_energy_multiplier = 2.2
	core.material_override = core_material
	add_child(core)

	for index in range(3):
		var rail := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.018, 0.018, 0.11 + index * 0.015)
		rail.mesh = box
		rail.position = Vector3((-0.04 + index * 0.04) * (-1.0 if mirror_x else 1.0), -0.005, -0.09)
		rail.material_override = core_material
		add_child(rail)
