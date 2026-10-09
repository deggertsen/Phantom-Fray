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
@export var volume_db: float = 0.0

var audio_player: AudioStreamPlayer
var available_tracks: Array[AudioStream] = [
	preload("res://Assets/Audio/Music/galactic_dawn.mp3"),
	preload("res://Assets/Audio/Music/galactic_shadows.mp3"),
	preload("res://Assets/Audio/Music/galactic_showdown.mp3"),
	preload("res://Assets/Audio/Music/galactic_showdown_2.mp3"),
	preload("res://Assets/Audio/Music/phantom_fall.mp3"),
	preload("res://Assets/Audio/Music/starlight_clash.mp3"),
]
var track_names: Array[String] = [
	"galactic_dawn",
	"galactic_shadows",
	"galactic_showdown",
	"galactic_showdown_2",
	"phantom_fall",
	"starlight_clash",
]
var current_track_index: int = 0
var is_playing: bool = false

func _ready() -> void:
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "AudioStreamPlayer"
	audio_player.bus = &"Music"
	audio_player.volume_db = volume_db
	add_child(audio_player)
	
	# Connect signals
	audio_player.finished.connect(_on_music_finished)
	
	# Load available tracks
	_load_music_tracks()

	var settings := get_node_or_null("/root/GameSettings")
	if settings:
		settings.own_music_changed.connect(_on_own_music_changed)

	# Start playing if auto_play is enabled and the player is not bringing their own music
	if auto_play and available_tracks.size() > 0 and not _own_music():
		_play_random_track()

func _own_music() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	return settings != null and bool(settings.own_music)

func _on_own_music_changed(enabled: bool) -> void:
	if enabled:
		stop_music()
	elif auto_play:
		play_music()

func _load_music_tracks() -> void:
	# Explicit preloads guarantee every launch track is included in Android exports.
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
	var audio_stream := available_tracks[current_track_index]
	if audio_stream == null:
		push_error("Music catalog contains an invalid stream at index %d" % current_track_index)
		return
	audio_player.stream = audio_stream
	audio_player.play()
	is_playing = true
	
	var track_name := track_names[current_track_index]
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
	if _own_music():
		return
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
	if track_names.size() > 0 and current_track_index < track_names.size():
		return track_names[current_track_index]
	return ""

func get_track_count() -> int:
	"""Get the number of available tracks"""
	return available_tracks.size()

