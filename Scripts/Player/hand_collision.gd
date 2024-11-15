extends XRController3D

signal punch_hit(velocity: float)

@onready var punch_area: Area3D = $PunchArea
var previous_position: Vector3
var current_velocity: Vector3
var punch_strength_threshold: float = 1.0

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

func _on_punch_area_body_entered(body: Node3D):
	if body.is_in_group("phantom") or body.is_in_group("Phantom"):
		var velocity = punch_area.get_meta("current_velocity", 0.0)
		if velocity > punch_strength_threshold:
			print("Punch hit with velocity: ", velocity)  # Debug print
			emit_signal("punch_hit", velocity)
			body.handle_punch(velocity, global_position)
