extends Node3D

## Dresses the breach site: the floor, the RSF pylons, the dead city and its rubble.
## The floor's corruption veins follow whichever rifts are open and fade as they seal.

const CYAN := Color(0.08, 0.7, 1.0, 1.0)
const DARK := Color(0.012, 0.018, 0.04, 1.0)
const FLOOR_SHADER := preload("res://Resources/Materials/arena_floor.gdshader")
const NOISE := preload("res://Resources/Materials/breach_noise.tres")
const MAX_RIFTS := 4

var _floor_material: ShaderMaterial
## Rift instance id -> [floor position, corruption strength].
var _corruption: Dictionary = {}

func _ready() -> void:
	CreatureMesh.prewarm()
	_build_floor()
	add_child(BreachCity.pylons())
	add_child(BreachCity.city())
	add_child(BreachCity.rubble())
	var vfx := CombatVFX.new()
	vfx.name = "CombatVFX"
	add_child(vfx)
	_build_briefing_panel()
	_warm_shaders.call_deferred()

## Compile combat shaders while the menu is up, not when the first phantom appears.
func _warm_shaders() -> void:
	ShaderWarmup.attach(get_tree())

func _process(delta: float) -> void:
	_update_corruption(delta)

func _build_floor() -> void:
	var floor_mesh := get_node_or_null("../Floor/MeshInstance3D") as MeshInstance3D
	if floor_mesh == null:
		return
	# The Floor node is scaled 2x, so this reaches 260 m across, out past the city.
	var plane := PlaneMesh.new()
	plane.size = Vector2(130.0, 130.0)
	floor_mesh.mesh = plane
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = FLOOR_SHADER
	_floor_material.set_shader_parameter("noise_tex", NOISE)
	floor_mesh.material_override = _floor_material

func _update_corruption(delta: float) -> void:
	if _floor_material == null:
		return
	var seen := {}
	for node in get_tree().get_nodes_in_group("active_rift"):
		var rift := node as Node3D
		if rift == null:
			continue
		var id := rift.get_instance_id()
		seen[id] = true
		var target := 0.0
		if rift.has_method("is_marked") and rift.is_marked():
			var health := float(rift.get("rift_health")) / maxf(float(rift.get("maximum_health")), 1.0)
			target = lerpf(0.35, 1.0, clampf(health, 0.0, 1.0))
		var entry: Array = _corruption.get(id, [rift.global_position, 0.0])
		entry[0] = rift.global_position
		entry[1] = move_toward(entry[1], target, delta * 0.6)
		_corruption[id] = entry
	for id in _corruption.keys():
		if not seen.has(id):
			_corruption[id][1] = move_toward(_corruption[id][1], 0.0, delta * 0.6)
			if _corruption[id][1] <= 0.0:
				_corruption.erase(id)
	var packed := PackedVector4Array()
	for entry in _corruption.values():
		if packed.size() >= MAX_RIFTS:
			break
		packed.append(Vector4(entry[0].x, entry[0].z, 0.0, entry[1]))
	while packed.size() < MAX_RIFTS:
		packed.append(Vector4.ZERO)
	_floor_material.set_shader_parameter("rifts", packed)

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
