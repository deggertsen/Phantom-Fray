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
	var kind: StringName = result.get("resolution_kind", &"")
	if kind == &"block_half":
		_pulse_hand(0.7, 0.12)
	elif result.get("valid", false):
		var sweet: bool = result.get("sweet_spot", false)
		var on_beat: bool = result.get("on_beat", false)
		_pulse_hand(1.0, 0.22 if sweet or on_beat else 0.16)
	else:
		_pulse_hand(0.4 if kind == &"not_open" else 0.55, 0.07)

func _pulse_hand(magnitude: float, duration_sec: float) -> void:
	## OpenXR haptic on the punching controller, the same frame the strike resolves.
	## https://docs.godotengine.org/en/stable/classes/class_xrinterface.html#class-xrinterface-method-trigger-haptic-pulse
	var amplitude := clampf(magnitude * XRToolsUserSettings.haptics_scale, 0.0, 1.0)
	var interface := XRServer.primary_interface
	if interface and amplitude > 0.0:
		interface.trigger_haptic_pulse(&"haptic", tracker, 0.0, amplitude, duration_sec, 0.0)
	var rumble_event := XRToolsRumbleEvent.new()
	rumble_event.magnitude = clampf(magnitude, 0.0, 1.0)
	rumble_event.duration_ms = int(duration_sec * 1000.0)
	rumble_event.active_during_pause = false
	rumble_event.indefinite = false
	XRToolsRumbleManager.add("combat_%s_%s" % [hand_id, Time.get_ticks_usec()], rumble_event, [tracker])
