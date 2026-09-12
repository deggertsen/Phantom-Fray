extends Node

const SETTINGS_PATH := "user://phantom_fray_settings.cfg"

var master_db: float = 0.0
var music_db: float = -8.0
var sfx_db: float = -4.0
var critical_db: float = -3.0
var haptic_scale: float = 1.0
var reduced_flashes: bool = false
var tutorial_completed: bool = false

func _ready() -> void:
	load_settings()
	apply_audio()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		haptic_scale = XRToolsUserSettings.haptics_scale
		return
	master_db = config.get_value("audio", "master_db", master_db)
	music_db = config.get_value("audio", "music_db", music_db)
	sfx_db = config.get_value("audio", "sfx_db", sfx_db)
	critical_db = config.get_value("audio", "critical_db", critical_db)
	haptic_scale = config.get_value("comfort", "haptic_scale", XRToolsUserSettings.haptics_scale)
	XRToolsUserSettings.haptics_scale = haptic_scale
	reduced_flashes = config.get_value("comfort", "reduced_flashes", reduced_flashes)
	tutorial_completed = config.get_value("progress", "tutorial_completed", tutorial_completed)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_db", master_db)
	config.set_value("audio", "music_db", music_db)
	config.set_value("audio", "sfx_db", sfx_db)
	config.set_value("audio", "critical_db", critical_db)
	config.set_value("comfort", "haptic_scale", haptic_scale)
	config.set_value("comfort", "reduced_flashes", reduced_flashes)
	config.set_value("progress", "tutorial_completed", tutorial_completed)
	config.save(SETTINGS_PATH)
	apply_audio()

func apply_audio() -> void:
	_set_bus_volume(&"Master", master_db)
	_set_bus_volume(&"Music", music_db)
	_set_bus_volume(&"SFX", sfx_db)
	_set_bus_volume(&"Critical", critical_db)

func adjust_music(direction: int) -> void:
	var levels: Array[float] = [-80.0, -20.0, -14.0, -8.0, -2.0]
	var index := levels.find(music_db)
	if index < 0:
		index = 3
	music_db = levels[clampi(index + direction, 0, levels.size() - 1)]
	save_settings()

func adjust_effects(direction: int) -> void:
	var levels: Array[float] = [-80.0, -20.0, -14.0, -8.0, -2.0]
	var index := levels.find(sfx_db)
	if index < 0:
		index = 3
	sfx_db = levels[clampi(index + direction, 0, levels.size() - 1)]
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

func cycle_music_volume() -> void:
	adjust_music(1)

func cycle_haptics() -> void:
	adjust_haptics(-1)

func _set_bus_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, value)
