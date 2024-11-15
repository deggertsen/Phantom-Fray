extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Apply the velocity (for gravity only)
	move_and_slide()

func _ready():
	# Set up collision for the player body
	add_to_group("Player")
	
	# Set collision layer and mask
	collision_layer = 1  # Default layer for player
	collision_mask = 4   # Layer 3 for phantoms

	# Make sure collision shape is properly sized
	if $CollisionShape3D:
		var capsule = $CollisionShape3D.shape as CapsuleShape3D
		if capsule:
			capsule.radius = 0.3  # Increased for better phantom detection
			capsule.height = 1.8  # Typical player height
