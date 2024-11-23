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

func _on_SpawnTimer_timeout():
	if current_phantoms < max_phantoms and rift_health > 0:
		_spawn_phantom()
		
func _spawn_phantom():
	var phantom_instance = phantom_scene.instantiate()
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
	
	# Optionally, perform closure animations or effects
	_play_rift_closure_effect()
	
	# Declare victory or move to the next stage
	print("Rift closed!")
	# You can emit a signal here to notify other systems
	emit_signal("rift_closed")

func _initialize_rift_visuals():
	# Implement visual indicators for the Rift (e.g., glowing portal)
	var portal = MeshInstance3D.new()
	portal.mesh = SphereMesh.new()
	portal.scale = Vector3(2, 2, 2)
	portal.material_override = StandardMaterial3D.new()
	portal.material_override.albedo_color = Color(0, 0, 1, 0.5) # Semi-transparent blue
	add_child(portal)

func _update_rift_health_visuals():
	# Update visuals based on rift_health
	# For example, change the color intensity
	for child in get_children():
		if child is MeshInstance3D:
			var material = child.material_override as StandardMaterial3D
			material.albedo_color.a = clamp(rift_health / 100.0, 0.1, 1.0)

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
