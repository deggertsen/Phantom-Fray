extends Node
class_name MusicController

## Example controller for demonstrating music manager functionality
## This shows how other scripts can interact with the music system
## Like having your own DJ at the phantom fight club! 🎧

@onready var music_manager: MusicManager = get_node("/root/Main/MusicManager")

func _ready() -> void:
	# Connect to music manager signals if it exists
	if music_manager:
		music_manager.music_changed.connect(_on_music_changed)
		music_manager.music_finished.connect(_on_music_finished)
		print("Music Controller: Connected to MusicManager")
	else:
		push_warning("Music Controller: MusicManager not found!")

func _on_music_changed(track_name: String) -> void:
	print("Music Controller: Now playing - ", track_name)

func _on_music_finished() -> void:
	print("Music Controller: Track finished, next track starting...")

# Example functions that could be called from game events
func on_phantom_defeated() -> void:
	"""Example: Could trigger special music effects when phantoms are defeated"""
	if music_manager:
		# Could add a brief volume boost or echo effect here
		pass

func on_life_force_low() -> void:
	"""Example: Could adjust music when life force is low"""
	if music_manager:
		# Could lower volume or change music style
		music_manager.set_volume(-15.0)  # Quieter when in danger

func on_life_force_normal() -> void:
	"""Example: Restore normal volume when life force is healthy"""
	if music_manager:
		music_manager.set_volume(-10.0)  # Back to normal volume

