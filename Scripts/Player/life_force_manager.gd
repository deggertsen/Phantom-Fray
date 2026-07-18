extends Node
class_name LifeForceManager

## Source of truth for player vitality. Signal-driven; keep presentation elsewhere.

signal life_force_changed(current: float, maximum: float)
signal life_force_state_changed(state: StringName)
signal life_force_depleted
signal damage_applied(amount: float, current: float)

enum State { HEALTHY, CAUTION, DANGER, CRITICAL, DEPLETED }

@export var max_life_force: float = 100.0
@export var drain_on_basic_hit: float = 5.0
@export var recovery_per_second: float = 1.0
@export var recovery_delay: float = 3.0
@export var enable_debug_keys: bool = true

var current_life_force: float = 100.0
var _time_since_hit: float = INF
var _is_depleted: bool = false
var _current_state: State = State.HEALTHY

func _ready() -> void:
	add_to_group("LifeForceManager")
	reset()

func _process(delta: float) -> void:
	if _is_depleted:
		return

	_time_since_hit += delta
	if _time_since_hit >= recovery_delay and current_life_force < max_life_force:
		var previous := current_life_force
		current_life_force = minf(current_life_force + recovery_per_second * delta, max_life_force)
		if not is_equal_approx(previous, current_life_force):
			life_force_changed.emit(current_life_force, max_life_force)
			_update_state()

func _unhandled_input(event: InputEvent) -> void:
	if not enable_debug_keys or not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H:
				apply_basic_hit()
				print("LifeForce debug: hit → ", current_life_force)
			KEY_R:
				reset()
				print("LifeForce debug: reset → ", current_life_force)

func apply_basic_hit() -> void:
	apply_damage(drain_on_basic_hit)

func apply_damage(amount: float) -> void:
	if _is_depleted or amount <= 0.0:
		return

	_time_since_hit = 0.0
	current_life_force = clampf(current_life_force - amount, 0.0, max_life_force)
	life_force_changed.emit(current_life_force, max_life_force)
	damage_applied.emit(amount, current_life_force)
	_update_state()

	if current_life_force <= 0.0 and not _is_depleted:
		_is_depleted = true
		_set_state(State.DEPLETED)
		life_force_depleted.emit()

func reset() -> void:
	_is_depleted = false
	_time_since_hit = INF
	current_life_force = max_life_force
	life_force_changed.emit(current_life_force, max_life_force)
	_set_state(State.HEALTHY)

func get_ratio() -> float:
	if max_life_force <= 0.0:
		return 0.0
	return current_life_force / max_life_force

func get_state_name() -> StringName:
	return _state_to_name(_current_state)

func is_depleted() -> bool:
	return _is_depleted

func _update_state() -> void:
	if _is_depleted:
		_set_state(State.DEPLETED)
		return

	var ratio := get_ratio()
	var next_state: State
	if ratio > 0.70:
		next_state = State.HEALTHY
	elif ratio > 0.40:
		next_state = State.CAUTION
	elif ratio > 0.10:
		next_state = State.DANGER
	else:
		next_state = State.CRITICAL

	_set_state(next_state)

func _set_state(next_state: State) -> void:
	if _current_state == next_state:
		return
	_current_state = next_state
	life_force_state_changed.emit(_state_to_name(next_state))

func _state_to_name(state: State) -> StringName:
	match state:
		State.HEALTHY:
			return &"healthy"
		State.CAUTION:
			return &"caution"
		State.DANGER:
			return &"danger"
		State.CRITICAL:
			return &"critical"
		State.DEPLETED:
			return &"depleted"
		_:
			return &"healthy"
