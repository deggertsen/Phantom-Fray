extends Node
class_name MusicManager

## Music Manager for Phantom-Fray
## Handles random cycling through music tracks in the Music directory
## Like having your own personal cantina band, but for fighting phantoms! 🎵

signal music_changed(track_name: String)
signal music_finished()

@export var music_directory: String = "res://Assets/Audio/Music/"
@export var auto_play: bool = true
@export var shuffle_mode: bool = true
@export var volume_db: float = -5

var audio_player: AudioStreamPlayer
var available_tracks: Array[String] = []
var current_track_index: int = 0
var is_playing: bool = false

func _ready() -> void:
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "AudioStreamPlayer"
	audio_player.volume_db = volume_db
	add_child(audio_player)
	
	# Connect signals
	audio_player.finished.connect(_on_music_finished)
	
	# Load available tracks
	_load_music_tracks()
	
	# Start playing if auto_play is enabled
	if auto_play and available_tracks.size() > 0:
		_play_random_track()

func _load_music_tracks() -> void:
	"""Load all audio files from the music directory"""
	var dir = DirAccess.open(music_directory)
	if dir == null:
		push_error("Music directory not found: " + music_directory)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".mp3") or file_name.ends_with(".wav") or file_name.ends_with(".ogg"):
			available_tracks.append(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if available_tracks.size() == 0:
		push_warning("No music files found in: " + music_directory)
	else:
		print("Loaded ", available_tracks.size(), " music tracks")

func _play_random_track() -> void:
	"""Play a random track from the available list"""
	if available_tracks.size() == 0:
		push_warning("No tracks available to play")
		return
	
	if shuffle_mode:
		current_track_index = randi() % available_tracks.size()
	else:
		current_track_index = (current_track_index + 1) % available_tracks.size()
	
	_play_current_track()

func _play_current_track() -> void:
	"""Play the currently selected track"""
	var track_path = music_directory + available_tracks[current_track_index]
	var audio_stream = load(track_path)
	
	if audio_stream == null:
		push_error("Failed to load audio file: " + track_path)
		# Try next track
		_play_random_track()
		return
	
	audio_player.stream = audio_stream
	audio_player.play()
	is_playing = true
	
	var track_name = available_tracks[current_track_index].get_basename()
	music_changed.emit(track_name)
	print("Now playing: ", track_name)

func _on_music_finished() -> void:
	"""Called when current track finishes"""
	is_playing = false
	music_finished.emit()
	
	# Auto-play next track
	if available_tracks.size() > 1:
		_play_random_track()

# Public methods for external control
func play_music() -> void:
	"""Start playing music"""
	if not is_playing and available_tracks.size() > 0:
		_play_random_track()

func stop_music() -> void:
	"""Stop current music"""
	audio_player.stop()
	is_playing = false

func pause_music() -> void:
	"""Pause current music"""
	audio_player.stream_paused = true

func resume_music() -> void:
	"""Resume paused music"""
	audio_player.stream_paused = false

func next_track() -> void:
	"""Manually advance to next track"""
	if available_tracks.size() > 1:
		_play_random_track()

func set_volume(new_volume_db: float) -> void:
	"""Set music volume"""
	volume_db = new_volume_db
	audio_player.volume_db = volume_db

func get_current_track_name() -> String:
	"""Get the name of the currently playing track"""
	if available_tracks.size() > 0 and current_track_index < available_tracks.size():
		return available_tracks[current_track_index].get_basename()
	return ""

func get_track_count() -> int:
	"""Get the number of available tracks"""
	return available_tracks.size()

