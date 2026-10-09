extends Node

signal own_music_changed(enabled: bool)

const SETTINGS_PATH := "user://phantom_fray_settings.cfg"
const VOLUME_DB: Array[float] = [-80.0, -20.0, -14.0, -8.0, -2.0]
const VOLUME_LABELS: PackedStringArray = ["OFF", "25%", "50%", "75%", "100%"]

var master_db: float = 0.0
var music_db: float = -8.0
var sfx_db: float = -8.0
var critical_db: float = -8.0
var own_music: bool = false
var haptic_scale: float = 1.0
var reduced_flashes: bool = false
var tutorial_completed: bool = false
var cleared_missions: PackedStringArray = PackedStringArray()
## Mission id -> the best score a victory has earned there.
var best_scores: Dictionary = {}
## Mission id -> the fastest victory there, in seconds of live round time.
var best_times: Dictionary = {}
var pending_mission_id: String = ""
## Where load_settings and save_settings read and write. Validation points it at a scratch file.
var settings_path: String = SETTINGS_PATH

func _ready() -> void:
	load_settings()
	apply_audio()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		haptic_scale = XRToolsUserSettings.haptics_scale
		_snap_volumes(false)
		return
	master_db = config.get_value("audio", "master_db", master_db)
	music_db = config.get_value("audio", "music_db", music_db)
	sfx_db = config.get_value("audio", "sfx_db", sfx_db)
	critical_db = config.get_value("audio", "critical_db", critical_db)
	own_music = config.get_value("audio", "own_music", own_music)
	haptic_scale = config.get_value("comfort", "haptic_scale", XRToolsUserSettings.haptics_scale)
	XRToolsUserSettings.haptics_scale = haptic_scale
	reduced_flashes = config.get_value("comfort", "reduced_flashes", reduced_flashes)
	tutorial_completed = config.get_value("progress", "tutorial_completed", tutorial_completed)
	var saved_clears: Variant = config.get_value("progress", "cleared_missions", PackedStringArray())
	if saved_clears is PackedStringArray:
		cleared_missions = saved_clears
	elif saved_clears is Array:
		cleared_missions = PackedStringArray(saved_clears)
	var saved_bests: Variant = config.get_value("progress", "best_scores", {})
	if saved_bests is Dictionary:
		best_scores = saved_bests
	var saved_times: Variant = config.get_value("progress", "best_times", {})
	if saved_times is Dictionary:
		best_times = saved_times
	_snap_volumes(true)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_db", master_db)
	config.set_value("audio", "music_db", music_db)
	config.set_value("audio", "sfx_db", sfx_db)
	config.set_value("audio", "critical_db", critical_db)
	config.set_value("audio", "own_music", own_music)
	config.set_value("comfort", "haptic_scale", haptic_scale)
	config.set_value("comfort", "reduced_flashes", reduced_flashes)
	config.set_value("progress", "tutorial_completed", tutorial_completed)
	config.set_value("progress", "cleared_missions", cleared_missions)
	config.set_value("progress", "best_scores", best_scores)
	config.set_value("progress", "best_times", best_times)
	config.save(settings_path)
	apply_audio()

func apply_audio() -> void:
	_set_bus_volume(&"Master", master_db)
	_set_bus_volume(&"Music", music_db)
	_set_bus_volume(&"SFX", sfx_db)
	_set_bus_volume(&"Critical", critical_db)
	var music_bus := AudioServer.get_bus_index(&"Music")
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, own_music)

func volume_label(db: float) -> String:
	return VOLUME_LABELS[volume_index(db)]

func volume_index(db: float) -> int:
	var best := 0
	var best_distance := INF
	for index in VOLUME_DB.size():
		var distance := absf(VOLUME_DB[index] - db)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best

func adjust_music(direction: int) -> void:
	var index := volume_index(music_db)
	music_db = VOLUME_DB[clampi(index + direction, 0, VOLUME_DB.size() - 1)]
	save_settings()

func set_own_music(enabled: bool) -> void:
	# The player's own app (Spotify, YouTube Music, and so on) plays alongside the game while the score stays silent.
	if own_music == enabled:
		return
	own_music = enabled
	save_settings()
	own_music_changed.emit(own_music)

func adjust_effects(direction: int) -> void:
	var index := volume_index(sfx_db)
	sfx_db = VOLUME_DB[clampi(index + direction, 0, VOLUME_DB.size() - 1)]
	critical_db = sfx_db
	save_settings()

func adjust_haptics(direction: int) -> void:
	var levels: Array[float] = [0.0, 0.5, 1.0]
	var index := levels.find(haptic_scale)
	if index < 0:
		index = 2
	haptic_scale = levels[clampi(index + direction, 0, levels.size() - 1)]
	XRToolsUserSettings.haptics_scale = haptic_scale
	XRToolsUserSettings.save()
	save_settings()

func has_cleared_mission(mission_id: String) -> bool:
	return mission_id in cleared_missions

func mark_mission_cleared(mission_id: String) -> void:
	if mission_id == "" or mission_id in cleared_missions:
		return
	cleared_missions.append(mission_id)
	save_settings()

func best_score(mission_id: String) -> int:
	return int(best_scores.get(mission_id, 0))

## Keeps the higher of the stored best and this victory's score.
func record_score(mission_id: String, score: int) -> void:
	if mission_id == "" or score <= best_score(mission_id):
		return
	best_scores[mission_id] = score
	save_settings()

## Fastest stored victory in seconds, or 0.0 when the mission has never been won.
func best_time(mission_id: String) -> float:
	return float(best_times.get(mission_id, 0.0))

## Keeps the faster of the stored best and this victory's time.
func record_time(mission_id: String, seconds: float) -> void:
	if mission_id == "" or seconds <= 0.0:
		return
	var previous := best_time(mission_id)
	if previous > 0.0 and seconds >= previous:
		return
	best_times[mission_id] = seconds
	save_settings()

func clear_mission_progress() -> void:
	cleared_missions = PackedStringArray()
	best_scores = {}
	best_times = {}
	pending_mission_id = ""

func reset_mission_progress() -> void:
	clear_mission_progress()
	save_settings()

func _snap_volumes(persist: bool) -> void:
	# The buses stay in decibels. The steps are what the settings screen calls OFF through 100%.
	# https://docs.godotengine.org/en/stable/classes/class_audioserver.html#class-audioserver-method-set-bus-volume-db
	var music := VOLUME_DB[volume_index(music_db)]
	var effects := VOLUME_DB[volume_index(sfx_db)]
	var changed := not is_equal_approx(music, music_db) or not is_equal_approx(effects, sfx_db)
	music_db = music
	sfx_db = effects
	critical_db = effects
	if persist and changed:
		save_settings()

func cycle_music_volume() -> void:
	adjust_music(1)

func cycle_haptics() -> void:
	adjust_haptics(-1)

func _set_bus_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, value)
