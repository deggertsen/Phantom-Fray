extends XRController3D

signal punch_hit(velocity: float, direction: Vector3)

var punch_area: Area3D
var previous_position: Vector3
var current_velocity: Vector3
var punch_strength_threshold: float = 1.0

# Haptic feedback settings
@export_range(0.0, 1.0, 0.01) var min_haptic_magnitude: float = 0.3
@export_range(0.0, 1.0, 0.01) var max_haptic_magnitude: float = 1.0
@export_range(0.1, 20.0, 0.1) var min_punch_velocity: float = 1.0
@export_range(1.0, 50.0, 0.1) var max_punch_velocity: float = 10.0
@export_range(10, 300, 10) var min_haptic_duration_ms: int = 75
@export_range(50, 500, 10) var max_haptic_duration_ms: int = 200

func _ready():
	# Create collision area if it doesn't exist
	if !punch_area:
		punch_area = Area3D.new()
		var collision_shape = CollisionShape3D.new()
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 0.05  # Small sphere for punch detection
		collision_shape.shape = sphere_shape
		punch_area.add_child(collision_shape)
		add_child(punch_area)
	
	# Set collision layer and mask
	punch_area.collision_layer = 2  # Layer 2 for hands
	punch_area.collision_mask = 4   # Layer 3 for phantoms
	
	# Add to punch group
	add_to_group("PlayerPunch")
	
	# Connect area signals
	punch_area.body_entered.connect(_on_punch_area_body_entered)
	
	# Initialize position tracking
	previous_position = global_position

func _physics_process(delta):
	# Calculate velocity manually
	current_velocity = (global_position - previous_position) / delta
	previous_position = global_position
	
	if is_button_pressed("grip_click"):
		var speed = current_velocity.length()
		if speed > punch_strength_threshold:
			punch_area.set_meta("current_velocity", speed)
			punch_area.set_meta("current_direction", current_velocity.normalized())

func _on_punch_area_body_entered(body: Node3D):
	if body.is_in_group("phantom") or body.is_in_group("Phantom"):
		var velocity = punch_area.get_meta("current_velocity", 0.0)
		var direction = punch_area.get_meta("current_direction", Vector3.ZERO)
		if velocity > punch_strength_threshold:
			# Trigger haptic feedback proportional to punch velocity
			trigger_haptic_feedback(velocity)
			emit_signal("punch_hit", velocity, direction)
			body.handle_punch(velocity, global_position, direction)

## Trigger haptic feedback scaled by punch velocity
func trigger_haptic_feedback(punch_velocity: float) -> void:
	# Calculate haptic magnitude based on velocity
	var normalized_velocity = clamp(
		(punch_velocity - min_punch_velocity) / (max_punch_velocity - min_punch_velocity),
		0.0, 1.0
	)
	
	var haptic_magnitude = lerp(min_haptic_magnitude, max_haptic_magnitude, normalized_velocity)
	
	# Create a rumble event for this punch
	var rumble_event = XRToolsRumbleEvent.new()
	rumble_event.magnitude = haptic_magnitude
	rumble_event.duration_ms = int(lerp(min_haptic_duration_ms, max_haptic_duration_ms, normalized_velocity))
	rumble_event.active_during_pause = false
	rumble_event.indefinite = false
	
	# Add the rumble event to the controller
	var event_key = "punch_hit_" + str(get_instance_id()) + "_" + str(Time.get_unix_time_from_system())
	XRToolsRumbleManager.add(event_key, rumble_event, [tracker])