extends CharacterBody3D

# Signal emitted when the phantom is hit
signal phantom_hit(points)

# Signal emitted when the phantom hits the player
signal player_hit

# Movement properties
@export var move_speed: float = 5.0
@export var acceleration: float = 5.0
@export var wobble_strength: float = 0.2
@export var wobble_speed: float = 2.0
@export var hover_height: float = 1.0  # Height to maintain above ground
@export var rotation_speed: float = 10.0  # How quickly the phantom rotates to face the player

# Health and score
var health = 1
var score = 0

# Time tracking for wobble
var _time: float = 0.0

# Cache the player reference
var _player: Node3D = null
var _player_camera: Node3D = null

# At the top with other variables
@onready var mesh_instance = $MeshInstance3D
var dissolve_speed = 0.7
var dissolve_amount = 0.0
var dissolving = false
var audio_player: AudioStreamPlayer3D = null

# Add at the top with other variables
var is_hit = false
var hit_velocity = Vector3.ZERO
var hit_drag = 0.95  # Adjust this to control how quickly the phantom slows down

func _ready():
	# Set up collision layers
	collision_layer = 4  # Layer 3 for phantoms
	collision_mask = 7   # Layer 1 (world), 2 (hands), and 3 (phantoms)
	
	$Area3D.collision_layer = 4
	$Area3D.collision_mask = 1  # Only detect player
	
	add_to_group("phantom")
	$Area3D.body_entered.connect(_on_Area3D_body_entered)
	
	# Get references to player and player camera
	_player = get_tree().get_first_node_in_group("Player")
	if _player:
		# Find the XRCamera3D node which represents the player's head
		_player_camera = _player.get_node_or_null("XRCamera3D")
		if not _player_camera:
			push_warning("Could not find XRCamera3D node in player hierarchy!")
			_player_camera = _player
		else:
			print("Found player camera at: ", _player_camera.global_position)
	
	# Create a unique instance of the material for this phantom
	var base_material = preload("res://Resources/Materials/dissolve.tres")
	var unique_material = base_material.duplicate()
	mesh_instance.material_override = unique_material
	
	# Initialize shader parameters
	unique_material.set_shader_parameter("dissolve_amount", 0.0)
	unique_material.set_shader_parameter("impact_point", Vector3.ZERO)
	unique_material.set_shader_parameter("dissolve_direction", Vector3.UP)
	
	# Get the audio bus for sound effects
	var sfx_bus_index = AudioServer.get_bus_index("SFX")  # Create this bus in the Audio settings
	if sfx_bus_index != -1:
		# Set the volume to about half (-6 dB is approximately half volume)
		AudioServer.set_bus_volume_db(sfx_bus_index, -6.0)
	
	# Wait one frame to ensure everything is initialized
	await get_tree().process_frame
	
	# Now face the player
	_face_player()

func _face_player():
	if _player_camera:
		# Calculate direction to player in XZ plane
		var direction = (_player_camera.global_position - global_position).normalized()
		var direction_xz = Vector3(direction.x, 0, direction.z).normalized()
		
		if direction_xz != Vector3.ZERO:
			# Calculate the angle to face the player
			var angle = atan2(direction_xz.x, direction_xz.z)
			# Apply the rotation around Y-axis only
			global_transform.basis = global_transform.basis.rotated(Vector3.UP, angle)

func _physics_process(delta):
	if is_hit:
		# Apply drag to gradually slow down the phantom
		velocity *= hit_drag
		move_and_slide()
		return
		
	if _player_camera:
		# Update time for wobble effect
		_time += delta
		
		# Calculate direction to player's camera (head)
		var direction = (_player_camera.global_position - global_position).normalized()
		
		# Add wobble effect
		var wobble = Vector3(
			sin(_time * wobble_speed) * wobble_strength,
			cos(_time * wobble_speed * 0.7) * wobble_strength,
			sin(_time * wobble_speed * 1.3) * wobble_strength
		)
		
		# Raycast downward to maintain height above ground
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			global_position,
			global_position + Vector3.DOWN * 10.0,
			1  # Layer 1 for world
		)
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var target_height = result.position.y + hover_height
			direction.y = (target_height - global_position.y) * 2.0
		
		# Calculate target velocity
		var target_velocity = (direction + wobble).normalized() * move_speed
		
		# Smoothly interpolate current velocity
		velocity = velocity.lerp(target_velocity, acceleration * delta)
		
		# Make the phantom face the player's camera while maintaining horizontal orientation
		var direction_xz = Vector3(direction.x, 0, direction.z).normalized()
		if direction_xz != Vector3.ZERO:
			# Calculate the target angle to face the player
			var target_angle = atan2(direction_xz.x, direction_xz.z)
			# Set the rotation directly, keeping the phantom horizontal
			var current_basis = global_transform.basis
			var new_basis = Basis(Vector3.UP, target_angle)
			# Preserve the current orientation of the mesh (so it stays horizontal)
			global_transform.basis = new_basis
			
		# Move and slide using Godot's built-in function
		move_and_slide()

func _on_Area3D_body_entered(body: Node3D):
	print("Collision with: ", body.name, " Groups: ", body.get_groups())  # Debug print
	if body.is_in_group("PlayerPunch"):
		handle_punch(body.velocity, body.global_position)
	elif body.get_parent() is XROrigin3D or body.is_in_group("Player"):
		print("Phantom hit player!")
		emit_signal("player_hit")
		disappear()

func handle_punch(velocity: float, punch_position: Vector3):
	# Create hit info dictionary
	var hit_info = {
		"velocity": Vector3.FORWARD * velocity,  # Convert float to Vector3
		"position": punch_position
	}
	
	# Call on_hit with the hit information
	on_hit(hit_info)
	
	health -= 1
	if health <= 0:
		# Pass the velocity as points
		emit_signal("phantom_hit", velocity)
		disappear()

func disappear():
	# Disable collisions
	collision_layer = 0
	collision_mask = 0
	$Area3D.collision_layer = 0
	$Area3D.collision_mask = 0
	
	# Play sound
	audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = preload("res://Assets/Audio/SFX/phantom_death.mp3")
	add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(_on_audio_finished)
	
	# Start dissolve effect
	dissolving = true

func _on_audio_finished():
	queue_free()

func on_hit(hit_info):
	# Get the unique material instance
	var material = mesh_instance.material_override
	if not material:
		print("No material found!")
		return
	
	# Calculate impact direction from hit velocity
	var impact_direction = hit_info.velocity.normalized()
	
	# Set hit state and velocity
	is_hit = true
	velocity = hit_info.velocity * 2.0  # Adjust multiplier for desired force
		# Set dissolve parameters
	dissolving = true
	material.set_shader_parameter("impact_point", hit_info.position)
	material.set_shader_parameter("dissolve_direction", hit_info.velocity.normalized())
	
	# Play sound
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.stream = preload("res://Assets/Audio/SFX/phantom_death.mp3")
		add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(_on_audio_finished)

func _process(delta):
	if dissolving:
		dissolve_amount = min(dissolve_amount + dissolve_speed * delta, 1.0)
		var material = mesh_instance.material_override
		if material:
			material.set_shader_parameter("dissolve_amount", dissolve_amount)
