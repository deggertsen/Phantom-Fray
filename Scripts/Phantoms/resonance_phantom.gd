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
