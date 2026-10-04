extends Phantom
class_name ResonancePhantom

@export var sweet_spot_radius: float = 0.32
@export var sweet_spot_size: float = 0.0
@export var sweet_spot_score_multiplier: float = 0.0
@export var sweet_score: int = 220
@export var sweet_rift_damage: int = 20

@onready var sweet_spot_visual: MeshInstance3D = $SweetSpotVisual

func _ready() -> void:
	if sweet_spot_size > 0.0:
		sweet_spot_radius = sweet_spot_size
	if sweet_spot_score_multiplier > 0.0:
		sweet_score = int(round(base_score * sweet_spot_score_multiplier))
	super()
	var material := sweet_spot_visual.get_active_material(0) as StandardMaterial3D
	if material:
		material = material.duplicate() as StandardMaterial3D
		sweet_spot_visual.material_override = material
	place_sweet_spot()

func place_sweet_spot(face: int = -1) -> void:
	# Local +Z is the face traveling toward the player. +X is the phantom's right.
	var side := signf(sweet_spot_visual.position.x)
	if absf(side) < 0.01:
		side = -1.0 if required_hand == &"left" else 1.0
	var chosen := face if face >= 0 else randi() % 3
	match chosen:
		0:
			# Hook. Stay on the hand that owns this color.
			sweet_spot_visual.position = Vector3(side * 0.36, 0.02, 0.0)
		1:
			# Uppercut.
			sweet_spot_visual.position = Vector3(0.0, -0.34, 0.08)
		_:
			# Jab.
			sweet_spot_visual.position = Vector3(0.0, 0.04, 0.36)

func _evaluate_strike(strike: Dictionary) -> Dictionary:
	var hand_id: StringName = strike.get("hand_id", &"")
	if hand_id != required_hand:
		_flash_sweet_spot(Color(1.0, 0.15, 0.15, 0.8))
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
	material.emission = color
	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.95, 0.06)
	tween.tween_property(material, "albedo_color:a", 0.28, 0.22)
