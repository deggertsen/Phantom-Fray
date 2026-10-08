extends Phantom
class_name ResonancePhantom

## The Angler. Its glowing lure is the sweet spot, and the lure hangs on the side of the
## hand that should strike it: out to the side for a hook, under the chin for an uppercut,
## in front of the mouth for a jab.

## Hook hangs out on the punching side (X flips), uppercut under the chin, jab in front.
const HOOK := Vector3(0.4, 0.06, 0.12)
const UPPERCUT := Vector3(0.0, -0.36, 0.1)
const JAB := Vector3(0.0, 0.08, 0.58)

@export var sweet_spot_radius: float = 0.32
@export var sweet_spot_size: float = 0.0
@export var sweet_spot_score_multiplier: float = 0.0
@export var sweet_score: int = 220
@export var sweet_rift_damage: int = 20

@onready var sweet_spot_visual: MeshInstance3D = $SweetSpotVisual

var _lure_color: Color

func _ready() -> void:
	if sweet_spot_size > 0.0:
		sweet_spot_radius = sweet_spot_size
	if sweet_spot_score_multiplier > 0.0:
		sweet_score = int(round(base_score * sweet_spot_score_multiplier))
	super()
	_style_lure()
	place_sweet_spot()

func place_sweet_spot(face: int = -1) -> void:
	sweet_spot_visual.position = _spot_for(face if face >= 0 else randi() % 3)
	if mesh_instance:
		mesh_instance.mesh = CreatureMesh.angler(sweet_spot_visual.position, _form)

## Every place a lure can hang, for building the meshes before the first spawn.
static func lure_spots() -> Array[Vector3]:
	return [HOOK * Vector3(-1.0, 1.0, 1.0), HOOK, UPPERCUT, JAB]

## Local +Z is the face traveling toward the player. +X is the phantom's right.
func _spot_for(face: int) -> Vector3:
	match face:
		0:
			# Hook. Stay on the hand that owns this color.
			return HOOK * Vector3(_hook_side(), 1.0, 1.0)
		1:
			return UPPERCUT
		_:
			return JAB

func _hook_side() -> float:
	if required_hand == &"left":
		return -1.0
	if required_hand == &"right":
		return 1.0
	var side := signf(sweet_spot_visual.position.x)
	return side if absf(side) > 0.01 else 1.0

func _creature_mesh() -> Mesh:
	return CreatureMesh.angler(_spot_for(0), _form)

## Anglers keep exact scale: the lure stalk has to meet the sweet spot it points at.
func _body_scale() -> float:
	return 1.0

func _tune_creature_material(material: ShaderMaterial) -> void:
	material.set_shader_parameter("sway_speed", 2.2)
	material.set_shader_parameter("flap_speed", 3.4)

func _style_lure() -> void:
	_lure_color = phantom_color.lightened(0.55)
	_lure_color.a = 1.0
	var orb := SphereMesh.new()
	orb.radius = 0.05
	orb.height = 0.1
	orb.radial_segments = 12
	orb.rings = 6
	sweet_spot_visual.mesh = orb
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _lure_color
	sweet_spot_visual.material_override = material
	var glow := GlowSprite.create(phantom_color, 0.5, 0.95)
	glow.name = "LureGlow"
	sweet_spot_visual.add_child(glow)
	var particles := sweet_spot_visual.get_node_or_null("SweetSpotParticles") as GPUParticles3D
	if particles:
		var process := (particles.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		process.emission_sphere_radius = 0.06
		process.scale_min = 0.3
		process.scale_max = 0.6
		particles.process_material = process
		particles.emitting = false
		particles.one_shot = true

func _on_dissolve_started() -> void:
	sweet_spot_visual.visible = false

func _evaluate_strike(strike: Dictionary) -> Dictionary:
	var hand_id: StringName = strike.get("hand_id", &"")
	if hand_id != required_hand:
		_flash_sweet_spot(Color(1.0, 0.15, 0.15, 1.0))
		return _make_result(false, false, &"wrong_hand", 0, 0, strike)
	var hit_position: Vector3 = strike.get("position", global_position)
	var distance := hit_position.distance_to(sweet_spot_visual.global_position)
	var sweet := distance <= sweet_spot_radius
	_flash_sweet_spot(Color.WHITE if sweet else phantom_color)
	return _make_result(
		true,
		sweet,
		&"sweet_spot" if sweet else &"strike",
		sweet_score if sweet else base_score,
		sweet_rift_damage if sweet else rift_damage,
		strike
	)

func _flash_sweet_spot(color: Color) -> void:
	var particles := sweet_spot_visual.get_node_or_null("SweetSpotParticles") as GPUParticles3D
	if particles:
		particles.restart()
	var material := sweet_spot_visual.material_override as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = color
	var tween := create_tween()
	tween.tween_property(sweet_spot_visual, "scale", Vector3.ONE * 1.8, 0.06)
	tween.tween_property(sweet_spot_visual, "scale", Vector3.ONE, 0.22)
	tween.parallel().tween_property(material, "albedo_color", _lure_color, 0.22)
