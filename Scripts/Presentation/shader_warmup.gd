extends Node3D
class_name ShaderWarmup

## Quest's Compatibility renderer compiles a shader the first time something draws with it,
## which stalls that frame. That was the hitch when the first phantom of a mission appeared.
## This draws one of everything combat uses, far too small to see, just in front of the
## player's camera while the menu is up, then removes itself.

const HOLD_FRAMES := 10
const SPECK := 0.001

var _frames: int = 0

## Hangs the warm-up off the player's XR camera, so it compiles the stereo variants too.
static func attach(tree: SceneTree) -> void:
	var player := tree.get_first_node_in_group("Player") as Node3D
	var camera := player.get_node_or_null("XRCamera3D") as Node3D if player else null
	if camera == null:
		return
	var warmup := ShaderWarmup.new()
	warmup.name = "ShaderWarmup"
	warmup.position = Vector3(0.0, 0.0, -0.6)
	camera.add_child(warmup)

func _ready() -> void:
	_add_creatures()
	_add_rift()
	_add_hit_effects()
	_add_quad(_lane_material())
	_add_quad(_veins_material())

func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= HOLD_FRAMES:
		queue_free()

func _add_creatures() -> void:
	var material := (preload("res://Resources/Materials/creature.tres") as ShaderMaterial).duplicate() as ShaderMaterial
	var body := MeshInstance3D.new()
	body.mesh = CreatureMesh.carapace(0)
	body.material_override = material
	_add_speck(body)
	# The lure's sparkle uses GPU particles, which compile their own process shader.
	var yellow := (load("res://Scenes/Phantoms/yellow_phantom.tscn") as PackedScene).instantiate()
	var sparkle := yellow.get_node_or_null("SweetSpotVisual/SweetSpotParticles") as GPUParticles3D
	if sparkle:
		var copy := sparkle.duplicate() as GPUParticles3D
		copy.emitting = true
		_add_speck(copy)
	yellow.free()

## The rift's own builder makes the portal, debris and beacon; borrow its pieces.
func _add_rift() -> void:
	var rift := RiftManager.new()
	rift._initialize_rift_visuals()
	for child in rift.get_children():
		rift.remove_child(child)
		if child is Node3D:
			(child as Node3D).top_level = false
		_add_speck(child)
	rift.free()

## Sparks, ring and flash, made by CombatVFX itself so the materials match exactly.
func _add_hit_effects() -> void:
	var vfx := CombatVFX.new()
	var burst := vfx._make_burst()
	var ring := vfx._make_ring()
	var flash := vfx._make_flash()
	for node in [burst, ring, flash]:
		vfx.remove_child(node)
		node.visible = true
		_add_speck(node)
	burst.restart()
	burst.emitting = true
	vfx.free()

func _lane_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://Resources/Materials/dodge_lane.gdshader")
	material.set_shader_parameter("strength", 1.0)
	return material

func _veins_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://Resources/Materials/life_veins.gdshader")
	material.set_shader_parameter("noise_tex", preload("res://Resources/Materials/breach_noise.tres"))
	material.set_shader_parameter("strength", 0.5)
	return material

func _add_quad(material: Material) -> void:
	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	quad.material_override = material
	_add_speck(quad)

func _add_speck(node: Node) -> void:
	add_child(node)
	if node is Node3D:
		(node as Node3D).position = Vector3.ZERO
		(node as Node3D).scale = Vector3.ONE * SPECK
