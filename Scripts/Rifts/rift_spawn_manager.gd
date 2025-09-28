extends Node3D

# Path to the RiftManager scene
@export var rift_manager_scene: PackedScene

# Minimum and maximum number of rifts to maintain
@export var min_rifts: int = 2
@export var max_rifts: int = 3

# Minimum distance between rifts
@export var min_rift_distance: float = 10.0

# Minimum and maximum distance from player
@export var min_player_distance: float = 15.0
@export var max_player_distance: float = 25.0

# Spawn area dimensions
@export var spawn_area_size: Vector3 = Vector3(30, 0, 30)

# Spawn timer duration in seconds
@export var spawn_timer_duration: float = 45.0

# Current number of active rifts
var active_rifts: int = 0

# Array to store active rift instances
var rift_instances: Array = []

# Timer for spawning new rifts
var spawn_timer: Timer

# Reference to the player
var player: Node3D

func _ready():
	# Get reference to the player
	player = get_tree().get_root().get_node_or_null("Main/Player")
	if not player:
		push_warning("Player not found in scene tree!")
	
	# Initialize and start the spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_timer_duration
	spawn_timer.one_shot = false
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# Connect to the tree_exiting signal of any existing rifts
	for child in get_children():
		if child is Node3D and "RiftManager" in child.name:
			child.tree_exiting.connect(_on_rift_closed.bind(child))
			rift_instances.append(child)
			active_rifts += 1
	
	# Spawn initial rifts if needed
	_spawn_initial_rifts()

func _spawn_initial_rifts():
	while active_rifts < min_rifts:
		_spawn_new_rift()

func _spawn_new_rift():
	var new_rift = rift_manager_scene.instantiate()
	add_child(new_rift)
	
	# Position the new rift
	var valid_position = _find_valid_position()
	new_rift.global_transform.origin = valid_position
	
	# Make the rift face the player
	if player:
		var direction_to_player = (player.global_transform.origin - valid_position).normalized()
		# Only create a look transform if the positions are different
		if not valid_position.is_equal_approx(player.global_transform.origin):
			# Create a transform that looks at the player
			var look_transform = Transform3D()
			look_transform = look_transform.looking_at(player.global_transform.origin, Vector3.UP)
			new_rift.global_transform = look_transform
			new_rift.global_transform.origin = valid_position
		else:
			# If positions are the same, just set the position without rotation
			new_rift.global_transform.origin = valid_position
	
	# Connect to the tree_exiting signal
	new_rift.tree_exiting.connect(_on_rift_closed.bind(new_rift))
	
	rift_instances.append(new_rift)
	active_rifts += 1

func _find_valid_position() -> Vector3:
	var attempts = 0
	var max_attempts = 20  # Increased attempts since we have more constraints
	
	while attempts < max_attempts:
		# Generate random position within spawn area
		var random_pos = Vector3(
			randf_range(-spawn_area_size.x/2, spawn_area_size.x/2),
			3.0, # Keep at a consistent height
			randf_range(-spawn_area_size.z/2, spawn_area_size.z/2)
		)
		
		# Check if position is valid (far enough from other rifts and player)
		var is_valid = true
		
		# Check distance from other rifts
		for rift in rift_instances:
			if rift.global_transform.origin.distance_to(random_pos) < min_rift_distance:
				is_valid = false
				break
		
		# Check distance from player
		if player and is_valid:
			var distance_to_player = player.global_transform.origin.distance_to(random_pos)
			if distance_to_player < min_player_distance or distance_to_player > max_player_distance:
				is_valid = false
		
		if is_valid:
			return random_pos
		
		attempts += 1
	
	# If we couldn't find a valid position, return a default one
	return Vector3(0, 3.0, 0)

func _on_rift_closed(rift):
	rift_instances.erase(rift)
	active_rifts -= 1

func _on_spawn_timer_timeout():
	# Only spawn a new rift if we're below the maximum
	if active_rifts < max_rifts:
		_spawn_new_rift() 
