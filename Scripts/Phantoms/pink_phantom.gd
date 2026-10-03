extends Phantom

@export var telegraph_seconds: float = 1.15
@export var charge_speed: float = 7.0
@export var dodge_radius: float = 0.65

var _telegraph_remaining: float
var _charging: bool = false
var _previous_target_distance: float = INF

func _ready() -> void:
	uses_attack_pattern = false
	variant_id = &"pink"
	phantom_color = Color(1.0, 0.15, 0.65, 0.9)
	base_score = 200
	rift_damage = 18
	super()
	_telegraph_remaining = telegraph_seconds
	_lock_pink_target()

func apply_pressure(speed_scale: float, telegraph_scale: float) -> void:
	super.apply_pressure(speed_scale, telegraph_scale)
	charge_speed *= speed_scale
	telegraph_seconds = maxf(telegraph_seconds * telegraph_scale, 0.45)
	_telegraph_remaining *= telegraph_scale

func _physics_process(delta: float) -> void:
	if _terminal:
		super(delta)
		return
	if _try_possess_between(global_position, global_position):
		return
	if _telegraph_remaining > 0.0:
		_telegraph_remaining -= delta
		velocity = Vector3.ZERO
		if _locked_target.distance_squared_to(global_position) > 0.001:
			_aim_at(self, _locked_target)
		var strength := 1.0 - clampf(_telegraph_remaining / maxf(telegraph_seconds, 0.01), 0.0, 1.0)
		_set_alert(lerpf(0.4, 1.0, strength))
		_update_commit_lane(_locked_target, true, strength)
		return
	_charging = true
	_set_alert(1.0)
	_update_commit_lane(_locked_target, true, 1.0)
	var origin := global_position
	var direction := (_locked_target - global_position).normalized()
	velocity = direction * charge_speed
	move_and_slide()
	if _try_possess_between(origin, global_position):
		return
	var distance := global_position.distance_to(_locked_target)
	var passed_target := distance > _previous_target_distance and _previous_target_distance < dodge_radius * 1.8
	_previous_target_distance = distance
	if passed_target:
		var result := _make_result(true, false, &"dodge", base_score, rift_damage)
		result["on_beat"] = true
		resolve_without_strike(result)

func _evaluate_strike(strike: Dictionary) -> Dictionary:
	return _make_result(false, false, &"dodge_only", 0, 0, strike)

func _lock_pink_target() -> void:
	if _player_camera:
		_locked_target = _player_camera.global_position
	else:
		_locked_target = Vector3(0.0, 1.5, 0.0)
	_previous_target_distance = global_position.distance_to(_locked_target)
