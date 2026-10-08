extends Node3D

## The ERM gauntlet, worn over the XR Tools glove: a bracer on the forearm, armor on the
## back of the hand and the knuckles, and a core that beats with the player's heart and
## dims as life force drains.
##
## Controller space, as the glove sits in it: fingers point -Z, the wrist is near z 0.07
## and the forearm runs back along +Z, the thumb is up, and the back of the hand faces
## outward (-X on the left hand, +X on the right).

@export var hand_color: Color = Color(0.08, 0.72, 1.0)
@export var mirror_x: bool = false

const ARMOR_COLOR := Color(0.12, 0.15, 0.21)
const GLOVE_COLOR := Color(0.045, 0.05, 0.07)
const BEAT_RATE := {&"healthy": 1.0, &"caution": 1.15, &"danger": 1.4, &"critical": 1.8, &"depleted": 0.0}

var _core_material: StandardMaterial3D
var _core_glow: MeshInstance3D
var _life_ratio: float = 1.0
var _beat_rate: float = 1.0
var _critical: bool = false
var _time: float = 0.0

func _ready() -> void:
	var side := -1.0 if mirror_x else 1.0
	_dress_glove()
	_build_armor(side)
	_build_core(side)
	_follow_life_force()

func _process(delta: float) -> void:
	_time += delta * _beat_rate
	var beat_phase := fmod(_time, 1.0)
	# A double thump: lub, then a softer dub.
	var beat := exp(-beat_phase * 14.0) + 0.6 * exp(-absf(beat_phase - 0.22) * 16.0)
	var dim := lerpf(0.3, 1.0, _life_ratio)
	var flicker := 0.35 if _critical and randf() < 0.12 else 1.0
	(_core_glow.material_override as StandardMaterial3D).albedo_color.a = (0.4 + 0.6 * beat) * dim * flicker
	_core_material.albedo_color = hand_color.lerp(Color.WHITE, 0.65 * dim)

## A dark tactical glove under the armor, instead of the stock glove color.
func _dress_glove() -> void:
	var glove := StandardMaterial3D.new()
	glove.albedo_color = GLOVE_COLOR
	glove.roughness = 0.75
	glove.rim_enabled = true
	glove.rim = 0.35
	glove.rim_tint = 0.6
	for sibling in get_parent().get_children():
		if sibling is XRToolsHand:
			(sibling as XRToolsHand).hand_material_override = glove

## Every armor part merged into one mesh: one surface lit, one surface glowing.
func _build_armor(side: float) -> void:
	var armor := SurfaceTool.new()
	var glow := SurfaceTool.new()
	armor.begin(Mesh.PRIMITIVE_TRIANGLES)
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along_forearm := Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0))
	var oval := Basis.from_scale(Vector3(0.85, 1.0, 1.12))

	var bracer := CylinderMesh.new()
	bracer.top_radius = 0.047
	bracer.bottom_radius = 0.04
	bracer.height = 0.2
	bracer.radial_segments = 10
	bracer.rings = 1
	armor.append_from(bracer, 0, Transform3D(along_forearm * oval, Vector3(-side * 0.008, -0.004, 0.17)))
	armor.append_from(_box(0.012, 0.05, 0.17), 0, Transform3D(Basis(), Vector3(side * 0.042, 0.0, 0.17)))
	armor.append_from(_box(0.01, 0.06, 0.07), 0, Transform3D(Basis(), Vector3(side * 0.027, 0.012, 0.02)))
	armor.append_from(_box(0.014, 0.072, 0.022), 0, Transform3D(Basis(), Vector3(side * 0.028, 0.012, -0.03)))
	# The core's housing on top of the bracer.
	armor.append_from(_box(0.034, 0.008, 0.042), 0, Transform3D(Basis(), Vector3(-side * 0.008, 0.049, 0.105)))

	for y in [-0.016, 0.016]:
		glow.append_from(_box(0.004, 0.004, 0.16), 0, Transform3D(Basis(), Vector3(side * 0.049, y, 0.17)))
	for ring in [[0.085, 0.041], [0.255, 0.046]]:
		var torus := TorusMesh.new()
		torus.inner_radius = ring[1]
		torus.outer_radius = ring[1] + 0.007
		torus.rings = 16
		torus.ring_segments = 4
		glow.append_from(torus, 0, Transform3D(along_forearm * oval, Vector3(-side * 0.008, -0.004, ring[0])))
	glow.append_from(_box(0.004, 0.06, 0.005), 0, Transform3D(Basis(), Vector3(side * 0.036, 0.012, -0.03)))

	var mesh := armor.commit()
	glow.commit(mesh)
	var armor_material := StandardMaterial3D.new()
	armor_material.albedo_color = ARMOR_COLOR
	armor_material.metallic = 0.7
	armor_material.roughness = 0.38
	armor_material.rim_enabled = true
	armor_material.rim = 0.5
	armor_material.rim_tint = 0.3
	mesh.surface_set_material(0, armor_material)
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.albedo_color = hand_color
	mesh.surface_set_material(1, glow_material)

	var shell := MeshInstance3D.new()
	shell.name = "Armor"
	shell.mesh = mesh
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)

func _build_core(side: float) -> void:
	var core := MeshInstance3D.new()
	core.name = "Core"
	var orb := SphereMesh.new()
	orb.radius = 0.013
	orb.height = 0.026
	orb.radial_segments = 10
	orb.rings = 5
	core.mesh = orb
	_core_material = StandardMaterial3D.new()
	_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_material.albedo_color = hand_color.lerp(Color.WHITE, 0.65)
	core.material_override = _core_material
	# On top of the bracer, like a watch face: the back of the hand faces away from the eyes.
	core.position = Vector3(-side * 0.008, 0.054, 0.105)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	_core_glow = GlowSprite.create(hand_color, 0.13, 0.9)
	_core_glow.name = "CoreGlow"
	core.add_child(_core_glow)

func _follow_life_force() -> void:
	var manager := get_node_or_null("../../LifeForceManager")
	if manager == null:
		manager = get_tree().get_first_node_in_group("LifeForceManager")
	if manager == null:
		return
	manager.life_force_changed.connect(_on_life_force_changed)
	manager.life_force_state_changed.connect(_on_life_force_state_changed)

func _on_life_force_changed(current: float, maximum: float) -> void:
	_life_ratio = 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)

func _on_life_force_state_changed(state: StringName) -> void:
	_beat_rate = float(BEAT_RATE.get(state, 1.0))
	_critical = state == &"critical"

func _box(x: float, y: float, z: float) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = Vector3(x, y, z)
	return box
