extends Phantom

@export var block_window_seconds: float = 0.55

var _first_hand: StringName = &""
var _block_window_remaining: float = 0.0

func _ready() -> void:
	variant_id = &"green"
	phantom_color = Color(0.12, 1.0, 0.4, 0.9)
	move_speed *= 1.15
	base_score = 180
	rift_damage = 16
	lateral_bias = 0.0
	height_bias = -0.28
	lateral_reach_min = 0.0
	lateral_reach_max = 0.16
	height_jitter = 0.22
	arc_scale = 1.5
	acceleration = 2.1
	engage_distance = 2.05
	pattern_telegraph_seconds = 0.72
	pattern_commit_speed = 5.4
	pattern_commit_seconds = 0.5
	body_widen = 1.5
	super()

## The Carapace: one crystal claw per hand says "block with both".
func _creature_mesh() -> Mesh:
	return CreatureMesh.carapace()

func _tune_creature_material(material: ShaderMaterial) -> void:
	material.set_shader_parameter("snap", 1.0)
	material.set_shader_parameter("flap_speed", 3.2)
	material.set_shader_parameter("sway_speed", 3.0)

func _process(delta: float) -> void:
	super(delta)
	if _block_window_remaining > 0.0:
		_block_window_remaining -= delta
		if _block_window_remaining <= 0.0:
			_first_hand = &""

func _evaluate_strike(strike: Dictionary) -> Dictionary:
	var hand_id: StringName = strike.get("hand_id", &"")
	if _first_hand == &"":
		_first_hand = hand_id
		_block_window_remaining = block_window_seconds
		return _make_result(false, false, &"block_half", 0, 0, strike)
	if hand_id == _first_hand or _block_window_remaining <= 0.0:
		_first_hand = hand_id
		_block_window_remaining = block_window_seconds
		return _make_result(false, false, &"need_both_hands", 0, 0, strike)
	_first_hand = &""
	_block_window_remaining = 0.0
	return _make_result(true, false, &"two_hand_block", base_score, rift_damage, strike)
