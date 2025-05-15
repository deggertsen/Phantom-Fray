extends "res://Scripts/Phantoms/phantom.gd"

# Yellow phantom specific properties
@export var sweet_spot_size: float = 0.3
@export var sweet_spot_score_multiplier: float = 2.0
@export var base_score: int = 100

# Override the ready function to set up yellow-specific properties
func _ready():
	super()
	
	# Set yellow phantom material
	var material = $MeshInstance3D.material_override
	if material:
		material.set_shader_parameter("base_color", Color(1.0, 0.9, 0.0, 0.8))
	
	# Modify collision mask to only detect left hand
	$Area3D.collision_mask = 2  # Layer 2 is for hands
	
	# Start with subtle sweet spot visualization
	var sweet_spot_visual = $SweetSpotVisual
	sweet_spot_visual.material_override.albedo_color.a = 0.2
	var sweet_spot_particles = $SweetSpotVisual/SweetSpotParticles
	sweet_spot_particles.emitting = true

# Override the handle_punch function to implement yellow-specific behavior
func handle_punch(velocity: float, punch_position: Vector3):
	var hit_info = super.handle_punch(velocity, punch_position)
	
	if _is_left_hand_hit():
		var sweet_spot_factor = _calculate_sweet_spot_factor(punch_position)
		if sweet_spot_factor > 0.8:
			_highlight_sweet_spot_hit()
	
	return hit_info

func _is_left_hand_hit() -> bool:
	# Implementation will depend on your hand tracking setup
	# This is a placeholder that should be implemented based on your collision system
	return true

func _calculate_sweet_spot_factor(hit_position: Vector3) -> float:
	# Calculate distance from ideal hit location
	# This is a placeholder - implement based on your sweet spot definition
	var distance_to_sweet_spot = (hit_position - global_position).length()
	return clamp(1.0 - (distance_to_sweet_spot / sweet_spot_size), 0.1, 1.0)

func _highlight_sweet_spot_hit():
	# Create a quick flash effect
	var tween = create_tween()
	tween.tween_property($SweetSpotVisual.material_override, "albedo_color:a", 0.8, 0.1)
	tween.tween_property($SweetSpotVisual.material_override, "albedo_color:a", 0.2, 0.3)
	
	# Increase particle emission temporarily
	$SweetSpotVisual/SweetSpotParticles.amount = 40
	await get_tree().create_timer(0.3).timeout
	$SweetSpotVisual/SweetSpotParticles.amount = 20
