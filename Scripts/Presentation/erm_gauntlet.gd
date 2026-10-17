extends Node3D

## The ERM gauntlet, worn over the XR Tools glove: a bracer on the forearm, armor on the
## back of the hand and the knuckles, and a core that beats with the player's heart and
## dims as life force drains. Closing the fist on the grip powers it up: the channels run
## hot, the knuckles light, and a ring snaps off them. Opening the hand powers it down.
##
## Controller space, as the glove sits in it: fingers point -Z, the wrist is near z 0.07
## and the forearm runs back along +Z, the thumb is up, and the back of the hand faces
## outward (-X on the left hand, +X on the right).

@export var hand_color: Color = Color(0.08, 0.72, 1.0)
@export var mirror_x: bool = false

const ARMOR_COLOR := Color(0.12, 0.15, 0.21)
const GLOVE_COLOR := Color(0.045, 0.05, 0.07)
const BEAT_RATE := {&"healthy": 1.0, &"caution": 1.15, &"danger": 1.4, &"critical": 1.8, &"depleted": 0.0}
## How far a half-closed hand warms the gauntlet before the grip clicks.
const PRE_CHARGE := 0.25
## A free hand (controller hanging) makes a fist at this finger curl.
const FREE_FIST_CURL := 0.65
const POWER_UP_RATE := 9.0
const POWER_DOWN_RATE := 3.2
## On ignition a band of light runs down the bracer into the fist, then a ring snaps off it.
const SURGE_SEC := 0.1
const RING_SEC := 0.26
const SURGE_FROM_Z := 0.255
const SURGE_TO_Z := 0.03
## The front of the knuckles with the hand closed on the grip, back of the hand on +X.
const KNUCKLES := Vector3(0.012, 0.0, -0.06)

## -1 follows the grip. 0 to 1 holds the charge there, for desktop captures.
var power_override: float = -1.0

var _core_material: StandardMaterial3D
var _core_glow: MeshInstance3D
var _glow_material: StandardMaterial3D
var _knuckle_glow: MeshInstance3D
var _ignition_ring: MeshInstance3D
var _surge: MeshInstance3D
var _life_ratio: float = 1.0
var _beat_rate: float = 1.0
var _critical: bool = false
var _time: float = 0.0
var _charge: float = 0.0
var _powered: bool = false
var _ignition_age: float = INF

func _ready() -> void:
	var side := -1.0 if mirror_x else 1.0
	_dress_glove()
	_build_armor(side)
	_build_core(side)
	_build_power_fx(side)
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
	_update_power(delta, dim)

## The grip is the fist: a full click ignites the gauntlet, a half-closed hand warms it.
func _update_power(delta: float, dim: float) -> void:
	var controller := get_parent() as XRController3D
	var target := power_override
	var gripped := power_override >= 1.0
	var combat := controller as CombatHandController
	var free_curl := combat.free_hand_curl() if combat else -1.0
	if power_override < 0.0 and free_curl >= 0.0:
		# The controller hangs on its strap and the gauntlet rides the tracked hand: the fist is
		# read from finger curl (held fists 0.97 to 1.00, open hands 0.08 to 0.14 on Quest 3).
		gripped = free_curl >= FREE_FIST_CURL
		target = 1.0 if gripped else free_curl * PRE_CHARGE
	elif power_override < 0.0 and controller:
		gripped = controller.is_button_pressed("grip_click")
		target = 1.0 if gripped else clampf(controller.get_float("grip"), 0.0, 1.0) * PRE_CHARGE
	if gripped and not _powered:
		_ignite(controller)
	_powered = gripped
	var rate := POWER_UP_RATE if target > _charge else POWER_DOWN_RATE
	_charge = move_toward(_charge, target, rate * delta)

	# A live hum while powered, and a stutter on the way down as the field collapses.
	var hum := 1.0
	if _powered:
		hum = 0.9 + 0.1 * sin(_time * 40.0)
	elif _charge > 0.05 and randf() < 0.25:
		hum = 0.55
	var level := clampf(_charge * hum * dim, 0.0, 1.0)
	_glow_material.albedo_color = hand_color.darkened(0.55).lerp(hand_color.lerp(Color.WHITE, 0.45), level)
	_core_material.albedo_color = _core_material.albedo_color.lerp(Color.WHITE, 0.5 * level)
	(_core_glow.material_override as StandardMaterial3D).albedo_color.a += 0.35 * level

	_ignition_age += delta
	var surge := _ignition_age / SURGE_SEC
	_surge.visible = surge < 1.0
	if surge < 1.0:
		_surge.position.z = lerpf(SURGE_FROM_Z, SURGE_TO_Z, surge * surge)
		(_surge.material_override as StandardMaterial3D).albedo_color.a = (1.0 - smoothstep(0.7, 1.0, surge)) * dim
	var ring := (_ignition_age - SURGE_SEC) / RING_SEC
	_ignition_ring.visible = ring >= 0.0 and ring < 1.0
	if _ignition_ring.visible:
		_ignition_ring.scale = Vector3.ONE * lerpf(0.2, 1.0, 1.0 - pow(1.0 - ring, 3.0))
		(_ignition_ring.material_override as StandardMaterial3D).albedo_color.a = (1.0 - ring) * dim
	# The knuckles flare as the surge lands, then settle to the held glow.
	var flare := 1.0 - clampf(ring, 0.0, 1.0) if ring >= 0.0 else 0.0
	_knuckle_glow.visible = level > 0.01 or flare > 0.0
	(_knuckle_glow.material_override as StandardMaterial3D).albedo_color.a = 0.95 * level + 0.7 * flare * dim

## Holds the gauntlet `age` seconds after ignition, for desktop captures with time stopped.
func show_ignition(age: float) -> void:
	power_override = 1.0
	_powered = true
	_ignition_age = age
	_charge = minf(age * POWER_UP_RATE, 1.0)

func _ignite(controller: XRController3D) -> void:
	_ignition_age = 0.0
	if controller == null or power_override >= 0.0:
		return
	# No tick for a free hand: its controller hangs on the strap, nowhere near the palm.
	var combat := controller as CombatHandController
	if combat and combat.hand_free:
		return
	# A short tick in the palm: the gauntlet is armed.
	var interface := XRServer.primary_interface
	var amplitude := clampf(0.3 * XRToolsUserSettings.haptics_scale, 0.0, 1.0)
	if interface and amplitude > 0.0:
		interface.trigger_haptic_pulse(&"haptic", controller.tracker, 0.0, amplitude, 0.04, 0.0)

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
	_glow_material = glow_material

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

## The surge band, the halo over the knuckles, and the ring that snaps off them. The halo and
## ring draw over the glove, which would otherwise swallow half of each.
func _build_power_fx(side: float) -> void:
	var hot := hand_color.lerp(Color.WHITE, 0.45)
	var band := TorusMesh.new()
	band.inner_radius = 0.05
	band.outer_radius = 0.062
	band.rings = 16
	band.ring_segments = 4
	_surge = MeshInstance3D.new()
	_surge.name = "Surge"
	_surge.mesh = band
	_surge.material_override = GlowSprite.material(hot, 1.0)
	(_surge.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	(_surge.material_override as StandardMaterial3D).albedo_texture = null
	_surge.basis = Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)) * Basis.from_scale(Vector3(0.85, 1.0, 1.12))
	_surge.position = Vector3(-side * 0.008, -0.004, SURGE_FROM_Z)
	_surge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surge.visible = false
	add_child(_surge)

	var at := Vector3(side * KNUCKLES.x, KNUCKLES.y, KNUCKLES.z)
	_knuckle_glow = GlowSprite.create(hand_color.lerp(Color.WHITE, 0.2), 0.22, 0.0)
	_knuckle_glow.name = "KnuckleGlow"
	(_knuckle_glow.material_override as StandardMaterial3D).no_depth_test = true
	_knuckle_glow.position = at
	_knuckle_glow.visible = false
	add_child(_knuckle_glow)
	_ignition_ring = GlowSprite.create(hot, 0.3, 0.0)
	_ignition_ring.name = "IgnitionRing"
	(_ignition_ring.material_override as StandardMaterial3D).albedo_texture = GlowSprite.ring_texture()
	(_ignition_ring.material_override as StandardMaterial3D).no_depth_test = true
	_ignition_ring.position = at
	_ignition_ring.visible = false
	add_child(_ignition_ring)

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
