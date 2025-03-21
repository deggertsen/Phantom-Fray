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

# Sweet spot properties
@export var sweet_spot_size: float = 0.3
@export var sweet_spot_score_multiplier: float = 2.0
@export var base_score: int = 100
@export var sweet_spot_rotation_speed: float = 1.0

# Health and score
var health = 1
var score = 0

# Sweet spot tracking
var sweet_spot_position: Vector3
var sweet_spot_rotation: float = 0.0
var sweet_spot_orbit_radius: float = 0.5  # Distance from phantom center

# Time tracking for wobble
var _time: float = 0.0

# Cache the player reference
var _player: Node3D = null

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
	_player = get_tree().get_first_node_in_group("Player")
	
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
	
	# Initialize sweet spot position
	_update_sweet_spot_position()

func _physics_process(delta):
	if is_hit:
		# Apply drag to gradually slow down the phantom
		velocity *= hit_drag
		move_and_slide()
		return
		
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
		
		# Update sweet spot position
		sweet_spot_rotation += sweet_spot_rotation_speed * delta
		_update_sweet_spot_position()

func _update_sweet_spot_position():
	# Calculate sweet spot position in a circular orbit around the phantom
	sweet_spot_position = Vector3(
		cos(sweet_spot_rotation) * sweet_spot_orbit_radius,
		0.0,  # Keep it at the same height
		sin(sweet_spot_rotation) * sweet_spot_orbit_radius
	)
	
	# Update visual position if the phantom has a sweet spot visual
	if has_node("SweetSpotVisual"):
		$SweetSpotVisual.position = sweet_spot_position

func _calculate_sweet_spot_factor(hit_position: Vector3) -> float:
	# Calculate distance from sweet spot
	var global_sweet_spot = global_position + sweet_spot_position
	var distance_to_sweet_spot = (hit_position - global_sweet_spot).length()
	
	# Return a factor between 0 and 1 based on distance
	return clamp(1.0 - (distance_to_sweet_spot / sweet_spot_size), 0.1, 1.0)

func _highlight_sweet_spot_hit():
	if has_node("SweetSpotVisual"):
		# Create a quick flash effect
		var tween = create_tween()
		tween.tween_property($SweetSpotVisual.material_override, "albedo_color:a", 0.8, 0.1)
		tween.tween_property($SweetSpotVisual.material_override, "albedo_color:a", 0.2, 0.3)
		
		# Increase particle emission temporarily
		var particles = $SweetSpotVisual/SweetSpotParticles
		if particles:
			particles.amount = 40
			await get_tree().create_timer(0.3).timeout
			if is_instance_valid(particles):
				particles.amount = 20

func _on_Area3D_body_entered(body: Node3D):
	print("Collision with: ", body.name, " Groups: ", body.get_groups())  # Debug print
	if body.is_in_group("PlayerPunch"):
		handle_punch(body.velocity, body.global_position)
	elif body.get_parent() is XROrigin3D or body.is_in_group("Player"):
		print("Phantom hit player!")
		emit_signal("player_hit")
		disappear()

# Virtual method to be overridden by child classes
func is_valid_hit(collider: Node3D) -> bool:
	return true  # Base phantom accepts all hits

func handle_punch(velocity: float, punch_position: Vector3):
	var sweet_spot_factor = _calculate_sweet_spot_factor(punch_position)
	var final_score = base_score
	
	if sweet_spot_factor > 0.8:
		final_score = int(base_score * sweet_spot_score_multiplier * sweet_spot_factor)
		_highlight_sweet_spot_hit()
	
	# Create hit info with score
	var hit_info = {
		"velocity": Vector3.FORWARD * velocity,
		"position": punch_position,
		"score": final_score
	}
	
	# Call on_hit with the hit information
	on_hit(hit_info)
	
	# Emit signal with score
	emit_signal("phantom_hit", final_score)
	
	# Start disappear sequence if health depleted
	health -= 1
	if health <= 0:
		disappear()

func disappear():
	print("Starting disappear function")
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
