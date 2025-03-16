extends "res://Scripts/Phantoms/phantom.gd"

func _ready():
	super()
	
	# Set yellow phantom material with more vibrant yellow
	var material = $MeshInstance3D.material_override
	if material:
		material.set_shader_parameter("base_color", Color(1.0, 0.8, 0.0, 0.9))  # Bright yellow
	
	# Modify collision mask to only detect left hand
	$Area3D.collision_layer = 4  # Layer 3 for phantoms
	$Area3D.collision_mask = 2  # Layer 2 for hands
	print("Yellow Phantom Area3D setup - Layer: ", $Area3D.collision_layer, " Mask: ", $Area3D.collision_mask)  # Debug print
	
	# Set yellow sweet spot visual color with more vibrant yellow
	if has_node("SweetSpotVisual"):
		var sweet_spot_material = $SweetSpotVisual.get_surface_override_material(0)
		if sweet_spot_material:
			sweet_spot_material.albedo_color = Color(1.0, 0.8, 0.0, 0.3)  # More saturated yellow, slightly more opaque
			sweet_spot_material.emission = Color(1.0, 0.8, 0.0, 1.0)
			sweet_spot_material.emission_energy_multiplier = 2.0  # Brighter glow
		
		var particles = $SweetSpotVisual/SweetSpotParticles
		if particles and particles.process_material:
			particles.process_material.color = Color(1.0, 0.8, 0.0, 0.7)  # More visible particles
			particles.emitting = true

# Override is_valid_hit to only accept left hand hits
func is_valid_hit(collider: Node3D) -> bool:
	if not collider:
		print("Yellow Phantom: No collider")  # Debug print
		return false
	
	# Check if it's a left hand controller
	print("Yellow Phantom checking hit from: ", collider.name)  # Debug print
	
	# Check if the controller is valid and is a left hand
	if collider is XRController3D:
		var is_left = collider.tracker == "left_hand"
		print("Yellow Phantom - Is left hand? ", is_left, " Tracker: ", collider.tracker)  # Debug print
		return is_left
	
	return false

# Override handle_punch to handle the punch directly
func handle_punch(velocity: float, punch_position: Vector3):
	print("Yellow Phantom - Handling punch with velocity: ", velocity)  # Debug print
	super.handle_punch(velocity, punch_position)
