extends CharacterBody3D

# Signal emitted when the phantom is hit
signal phantom_hit(points)

# Signal emitted when the phantom hits the player
signal player_hit

# Movement properties
@export var move_speed: float = 2.0
@export var acceleration: float = 5.0
@export var wobble_strength: float = 0.5
@export var wobble_speed: float = 2.0
@export var hover_height: float = 1.0  # Height to maintain above ground

# Health and score
var health = 1
var score = 0

# Time tracking for wobble
var _time: float = 0.0

# Cache the player reference
var _player: Node3D = null

func _ready():
	# Set up collision layers
	collision_layer = 4  # Layer 3 for phantoms
	collision_mask = 7   # Layer 1 (world), 2 (hands), and 3 (phantoms)
	
	$Area3D.collision_layer = 4
	$Area3D.collision_mask = 1  # Only detect player
	
	add_to_group("phantom")
	$Area3D.body_entered.connect(_on_Area3D_body_entered)
	_player = get_tree().get_first_node_in_group("Player")

func _physics_process(delta):
	if _player:
		# Update time for wobble effect
		_time += delta
		
		# Calculate direction to player
		var direction = (_player.global_position - global_position).normalized()
		
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
		emit_signal("phantom_hit", calculate_points())
		disappear()
	else:
		$AnimationPlayer.play("hit_reaction")

func disappear():
	# Disable collisions
	collision_layer = 0
	collision_mask = 0
	$Area3D.collision_layer = 0
	$Area3D.collision_mask = 0
	
	# Play death animation
	$AnimationPlayer.play("death")
	await $AnimationPlayer.animation_finished
	queue_free()

	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://Assets/Audio/SFX/phantom_death_sound.mp3")
	add_child(audio)
	audio.play()

func calculate_points():
	return 100  # Base points

func on_hit(hit_info):
	print("Hit detected with velocity: ", hit_info.velocity.length())
	
	# Get the material
	var material = $MeshInstance3D.material_override
	if not material:
		print("No material override found!")
		return
	
	# Calculate impact direction from hit velocity
	var impact_direction = hit_info.velocity.normalized()
	
	# Apply physical force
	var force = hit_info.velocity * 2.0  # Adjust multiplier for desired force
	self.linear_velocity = force # Access linear_velocity through self since this is likely a RigidBody3D
	
	# Set shader parameters for dissolve effect
	material.set_shader_parameter("impact_point", hit_info.position)
	material.set_shader_parameter("dissolve_direction", impact_direction)
	
	# Debug prints
	print("Impact position: ", hit_info.position)
	print("Impact direction: ", impact_direction)
	
	# Play the death animation
	if $AnimationPlayer.has_animation("death"):
		print("Playing death animation")
		$AnimationPlayer.play("death")
	else:
		print("No death animation found!")
