extends Phantom

@export var telegraph_seconds: float = 1.15
@export var charge_speed: float = 7.0
@export var dodge_radius: float = 0.65

var _telegraph_remaining: float
var _locked_target: Vector3
var _charging: bool = false
var _previous_target_distance: float = INF

func _ready() -> void:
	variant_id = &"pink"
	phantom_color = Color(1.0, 0.15, 0.65, 0.9)
	base_score = 200
	rift_damage = 18
	super()
	_telegraph_remaining = telegraph_seconds
	if _player_camera:
		_locked_target = _player_camera.global_position
	else:
		_locked_target = Vector3(0.0, 1.5, 0.0)
	_previous_target_distance = global_position.distance_to(_locked_target)

func _physics_process(delta: float) -> void:
	if _terminal:
		super(delta)
		return
	if _telegraph_remaining > 0.0:
		_telegraph_remaining -= delta
		velocity = Vector3.ZERO
		look_at(_locked_target, Vector3.UP)
		return
	_charging = true
	var direction := (_locked_target - global_position).normalized()
	velocity = direction * charge_speed
	move_and_slide()
	var distance := global_position.distance_to(_locked_target)
	var passed_target := distance > _previous_target_distance and _previous_target_distance < dodge_radius * 1.8
	_previous_target_distance = distance
	if passed_target:
		var result := _make_result(true, false, &"dodge", base_score, rift_damage)
		resolve_without_strike(result)

func _evaluate_strike(strike: Dictionary) -> Dictionary:
	return _make_result(false, false, &"dodge_only", 0, 0, strike)
