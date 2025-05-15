# Scripts/RiftManager/RiftManager.gd
extends Node3D

# Path to the Phantom scene
@export var phantom_scene: PackedScene

# Spawn interval in seconds
@export var spawn_interval: float = 5.0

# Maximum number of phantoms per rift
@export var max_phantoms: int = 10

# Rift health
var rift_health: int = 100

# Current number of spawned phantoms
var current_phantoms: int = 0

# Timer for spawning phantoms
var spawn_timer: Timer

# Dissolve variables
var dissolving = false
var dissolve_amount = 0.0
var dissolve_speed = 0.5

# Phantom container
var phantom_container: Node3D = null

func _ready():
	# Initialize and add the spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_SpawnTimer_timeout)
	add_child(spawn_timer)
	
	# Optional: Initialize visual indicators for the rift
	_initialize_rift_visuals()
	
	# Add unique material for dissolve effect
	var portal = $MeshInstance3D
	var dissolve_material = preload("res://Resources/Materials/rift.tres").duplicate()
	portal.material_override = dissolve_material
	
	# Add to existing _ready function
	phantom_container = get_tree().get_root().get_node_or_null("Main/PhantomContainer")
	if not phantom_container:
		push_warning("PhantomContainer not found in scene tree!")

func _on_SpawnTimer_timeout():
	if current_phantoms < max_phantoms and rift_health > 0:
		_spawn_phantom()
		
func _spawn_phantom():
	var phantom_instance = phantom_scene.instantiate()
	
	# Add to phantom container instead of self
	if phantom_container:
		phantom_container.add_child(phantom_instance)
	else:
		add_child(phantom_instance)
	
	# Position the phantom at the rift's location with some randomness
	var spawn_position = global_transform.origin + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	phantom_instance.global_transform.origin = spawn_position
	
	# Connect the phantom_hit signal
	phantom_instance.phantom_hit.connect(_on_Phasmton_hit)
	
	current_phantoms += 1

func _on_Phasmton_hit(points):
	rift_health -= points
	current_phantoms -= 1
	_update_rift_health_visuals()
	
	if rift_health <= 0:
		_close_rift()

func _close_rift():
	# Stop spawning new phantoms
	spawn_timer.stop()
	
	# Start dissolve effect
	dissolving = true
	
	# Play sound effect
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://Assets/Audio/SFX/rift_close_sound.mp3")
	add_child(audio)
	audio.play()

func _initialize_rift_visuals():
	# Create the portal mesh
	var portal = MeshInstance3D.new()
	portal.name = "MeshInstance3D"  # Keep the same name for consistency
	portal.mesh = SphereMesh.new()
	portal.mesh.radius = 2.0
	portal.mesh.height = 4.0
	
	# Create and set the dissolve material
	var dissolve_material = preload("res://Resources/Materials/rift.tres").duplicate()
	portal.material_override = dissolve_material
	
	# Add the portal to the scene
	add_child(portal)

func _update_rift_health_visuals():
	# Update visuals based on rift_health
	for child in get_children():
		if child is MeshInstance3D:
			var material = child.material_override
			if material:
				# Update the shader parameter instead of albedo_color
				material.set_shader_parameter("base_color", Color(0.0, 0.0, 1.0, clamp(rift_health / 100.0, 0.1, 1.0)))

func _play_rift_closure_effect():
	# Play particle effects or animations to signify rift closure
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.process_material = ParticleProcessMaterial.new()
	# Configure particle properties as needed
	add_child(particles)
	
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://Assets/Audio/SFX/rift_close_sound.mp3")
	add_child(audio)
	audio.play()

func _process(delta):
	if dissolving:
		dissolve_amount = min(dissolve_amount + dissolve_speed * delta, 1.0)
		var portal = get_node_or_null("MeshInstance3D")
		if portal and portal.material_override:
			portal.material_override.set_shader_parameter("dissolve_amount", dissolve_amount)
		
		if dissolve_amount >= 1.0:
			queue_free()
