extends XRController3D
class_name CombatHandController

## Strikes need the controller in the hand: grip held and moving fast. When the player lets the
## controller hang on its strap, the hand is free (TrackedHands): this node then follows the
## tracked hand instead, carrying the glove and gauntlet onto the palm, it cannot strike, and a
## pinch stands in for the trigger in menus. Gripping the controller again takes it back.
## Tracked hands lost 4 to 10 of 20 full-speed punches on Quest 3 (2026-10-14), so they never
## strike; see decision 39 in development/Exercise_Mechanics_Exploration.md.

## Controller space to palm-joint space. Controller space has the fingers on -Z, the thumb on +Y,
## and the back of the hand on +X (right) or -X (left); an OpenXR palm joint has the fingers on -Z
## and the back of the hand on +Y.
const PALM_BASIS_RIGHT := Basis(Vector3(0.0, 1.0, 0.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
const PALM_BASIS_LEFT := Basis(Vector3(0.0, -1.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))

@export var hand_id: StringName = &"left"
@export var punch_strength_threshold: float = 1.0
@export_range(0.1, 20.0, 0.1) var max_punch_velocity: float = 10.0
## Where the controller's grip pose sits in palm-joint space, so the glove lands on the tracked
## hand: the grip is inside a closed hand, a little toward the palm from the palm joint. A first
## guess; check on the headset that the glove covers the hand.
@export var free_hand_offset: Vector3 = Vector3(0.0, -0.02, 0.0)
## Thumb tip to index tip closer than this (m) is a pinch, and it ends past `pinch_release`.
@export var pinch_distance: float = 0.015
@export var pinch_release: float = 0.03

var punch_area: Area3D
var current_velocity: Vector3
## True while the controller hangs and this node follows the tracked hand.
var hand_free: bool = false
var _strike_active: bool = false
var _last_target_id: int = 0
var _last_hit_msec: int = 0
var _held_tracker: StringName
var _hands: TrackedHands
var _rest: Dictionary = {}
var _pinching: bool = false

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
	_held_tracker = tracker
	_hands = get_parent().get_node_or_null("TrackedHands") as TrackedHands
	if _hands:
		_hands.hand_freed.connect(_on_hand_freed)

func _process(_delta: float) -> void:
	if not hand_free or _hands == null:
		return
	var gap := _hands.pinch_gap(hand_id)
	var pinching := gap >= 0.0 and gap < (pinch_release if _pinching else pinch_distance)
	if pinching != _pinching:
		_pinching = pinching
		if pinching:
			button_pressed.emit("trigger_click")
		else:
			button_released.emit("trigger_click")

## The menu trigger: the controller's trigger, or a pinch while the controller hangs.
func is_menu_trigger_down() -> bool:
	return _pinching if hand_free else is_button_pressed("trigger_click")

## Finger curl of the free hand, 0 open to 1 a fist; -1 while the controller is held.
func free_hand_curl() -> float:
	return _hands.curl(hand_id) if hand_free and _hands else -1.0

func _on_hand_freed(side: StringName, free: bool) -> void:
	if side == hand_id:
		set_hand_free(free)

## Moves this node between the controller and the tracked hand. The children keep their places
## relative to the hand: on the palm they are turned from controller space into palm space.
func set_hand_free(free: bool) -> void:
	if free == hand_free:
		return
	hand_free = free
	if not free and _pinching:
		_pinching = false
		button_released.emit("trigger_click")
	tracker = StringName("/user/hand_tracker/%s" % hand_id) if free else _held_tracker
	var to_palm := Transform3D(PALM_BASIS_LEFT if hand_id == &"left" else PALM_BASIS_RIGHT, free_hand_offset)
	for child in get_children():
		var node := child as Node3D
		if node == null or node == punch_area:
			continue
		if not _rest.has(node):
			_rest[node] = node.transform
		node.transform = to_palm * _rest[node] if free else _rest[node]

func _physics_process(_delta: float) -> void:
	var pose := get_pose()
	current_velocity = pose.linear_velocity if pose else Vector3.ZERO
	_strike_active = not hand_free and is_button_pressed("grip_click") and current_velocity.length() > punch_strength_threshold
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
