extends XRController3D

signal punch_hit(velocity: float)

var punch_area: Area3D
var previous_position: Vector3
var current_velocity: Vector3
var punch_strength_threshold: float = 1.0

func _enter_tree():
	# Create collision area immediately
	punch_area = Area3D.new()
	punch_area.name = "PunchArea"
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
	print("Hand collision area created for: ", name)  # Debug print

func _ready():
	# Connect area signals
	punch_area.area_entered.connect(_on_punch_area_entered)
	
	# Initialize position tracking
	previous_position = global_position
	current_velocity = Vector3.ZERO
	punch_area.set_meta("current_velocity", 0.0)  # Initialize velocity meta
	print("Hand collision ready: ", name, " Layer: ", punch_area.collision_layer, " Mask: ", punch_area.collision_mask)  # Debug print

func _physics_process(delta):
	# Calculate velocity manually
	current_velocity = (global_position - previous_position) / delta
	previous_position = global_position
	
	# Always update the velocity meta
	var speed = current_velocity.length()
	punch_area.set_meta("current_velocity", speed)
	
	if is_button_pressed("grip_click"):
		if speed > punch_strength_threshold:
			print(name, " punch velocity: ", speed)  # Debug print

# Handle Area3D collisions
func _on_punch_area_entered(area: Area3D):
	print(name, " punch area overlapped with: ", area.name, " Parent: ", area.get_parent().name)  # Debug print
	
	var phantom = area.get_parent()
	if phantom.is_in_group("phantom") or phantom.is_in_group("Phantom"):
		var velocity = punch_area.get_meta("current_velocity", 0.0)
		if velocity > punch_strength_threshold and is_button_pressed("grip_click"):  # Check grip is pressed during collision
			# Pass the controller (self) for validation
			if phantom.is_valid_hit(self):
				print(name, " punch hit phantom with velocity: ", velocity)  # Debug print
				emit_signal("punch_hit", velocity)
				phantom.handle_punch(velocity, global_position)
			else:
				print(name, " punch not valid for this phantom type")  # Debug print
