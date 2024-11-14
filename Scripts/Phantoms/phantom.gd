extends CharacterBody3D

# Signal emitted when the phantom is hit
signal phantom_hit(points)

# Movement properties
@export var move_speed: float = 2.0
@export var acceleration: float = 5.0
@export var wobble_strength: float = 0.5
@export var wobble_speed: float = 2.0

# Health and score
var health = 3
var score = 0

# Time tracking for wobble
var _time: float = 0.0

# Cache the player reference
var _player: Node3D = null

func _ready():
	# Start with idle animation
	$AnimationPlayer.play("idle")
	
	# Connect collision signal
	$Area3D.body_entered.connect(_on_Area3D_body_entered)
	
	# Find the player (assuming it's tagged with group "Player")
	_player = get_tree().get_first_node_in_group("Player")
	
	# Add to existing ready function
	add_to_group("phantom")
	
	# Set collision layer/mask
	collision_layer = 4  # Layer 3 for phantoms
	collision_mask = 2   # Layer 2 for hands

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
		
		# Calculate target velocity
		var target_velocity = (direction + wobble).normalized() * move_speed
		
		# Smoothly interpolate current velocity
		velocity = velocity.lerp(target_velocity, acceleration * delta)
		
		# Move and slide using Godot's built-in function
		move_and_slide()

func _on_Area3D_body_entered(body):
	if body.is_in_group("PlayerPunch"):
		health -= 1
		if health <= 0:
			emit_signal("phantom_hit", calculate_points())
			$AnimationPlayer.play("death")
			# Remove phantom after death animation
			await get_tree().create_timer(1.0).timeout
			queue_free()
		else:
			$AnimationPlayer.play("hit_reaction")

func calculate_points():
	# Implement your scoring logic here
	return 100  # Placeholder value

func handle_punch(velocity: float, punch_position: Vector3):
	# Calculate points based on punch velocity
	var points = int(velocity * 10)
	
	# Play hit effect/animation
	$AnimationPlayer.play("hit_reaction")
	
	# Emit signal for scoring
	emit_signal("phantom_hit", points)
	
	# Start disappearing
	disappear()

func disappear():
	# Disable collisions
	collision_layer = 0
	collision_mask = 0
	
	# Play death animation
	$AnimationPlayer.play("death")
	
	# Queue free after animation
	await $AnimationPlayer.animation_finished
	queue_free()
