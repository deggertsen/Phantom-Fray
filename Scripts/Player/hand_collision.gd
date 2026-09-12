extends XRController3D
class_name CombatHandController

@export var hand_id: StringName = &"left"
@export var punch_strength_threshold: float = 1.0
@export_range(0.1, 20.0, 0.1) var max_punch_velocity: float = 10.0

var punch_area: Area3D
var current_velocity: Vector3
var _strike_active: bool = false
var _last_target_id: int = 0
var _last_hit_msec: int = 0

func _ready() -> void:
	punch_area = Area3D.new()
	punch_area.name = "PunchArea"
	var collision_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.075
	collision_shape.shape = sphere_shape
	punch_area.add_child(collision_shape)
	add_child(punch_area)
	punch_area.collision_layer = 2
	punch_area.collision_mask = 4
	punch_area.monitoring = true
	punch_area.body_entered.connect(_on_punch_area_body_entered)
	add_to_group("%s_hand" % hand_id)

func _physics_process(_delta: float) -> void:
	var pose := get_pose()
	current_velocity = pose.linear_velocity if pose else Vector3.ZERO
	_strike_active = is_button_pressed("grip_click") and current_velocity.length() > punch_strength_threshold
	if not _strike_active:
		_last_target_id = 0
		return
	for body in punch_area.get_overlapping_bodies():
		_try_strike(body)

func _on_punch_area_body_entered(body: Node3D) -> void:
	_try_strike(body)

func _try_strike(body: Node3D) -> void:
	if not _strike_active or not body.has_method("receive_strike"):
		return
	var round := get_tree().get_first_node_in_group("RoundController") as RoundController
	if round and not round.is_round_active():
		return
	var now := Time.get_ticks_msec()
	if body.get_instance_id() == _last_target_id and now - _last_hit_msec < 250:
		return
	_last_target_id = body.get_instance_id()
	_last_hit_msec = now
	var speed := current_velocity.length()
	var strike := {
		"hand_id": hand_id,
		"speed": speed,
		"position": global_position,
		"direction": current_velocity.normalized(),
		"quality": clampf((speed - punch_strength_threshold) / maxf(max_punch_velocity - punch_strength_threshold, 0.1), 0.0, 1.0),
	}
	var result: Dictionary = body.receive_strike(strike)
	if result.get("valid", false):
		_trigger_haptic(1.0 if result.get("sweet_spot", false) else 0.65, 140 if result.get("sweet_spot", false) else 90)
	else:
		_trigger_haptic(0.2, 45)

func _trigger_haptic(magnitude: float, duration_ms: int) -> void:
	var rumble_event := XRToolsRumbleEvent.new()
	rumble_event.magnitude = clampf(magnitude, 0.0, 1.0)
	rumble_event.duration_ms = duration_ms
	rumble_event.active_during_pause = false
	rumble_event.indefinite = false
	var event_key := "combat_%s_%s" % [hand_id, Time.get_ticks_usec()]
	XRToolsRumbleManager.add(event_key, rumble_event, [tracker])
