extends RefCounted

## Numbered takes, preloaded so the Quest export actually packs them.
## A runtime folder scan stays on the desktop and never reaches the APK.
## https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html

const DEATH: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/phantom_death_1.mp3"),
	preload("res://Assets/Audio/SFX/phantom_death_2.mp3"),
	preload("res://Assets/Audio/SFX/phantom_death_3.mp3"),
	preload("res://Assets/Audio/SFX/phantom_death_4.mp3"),
]
const POSSESS: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/phantom_possess_1.mp3"),
	preload("res://Assets/Audio/SFX/phantom_possess_2.mp3"),
]
const RIFT_CLOSE: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/rift_close_sound_1.mp3"),
	preload("res://Assets/Audio/SFX/rift_close_sound_2.mp3"),
	preload("res://Assets/Audio/SFX/rift_close_sound_3.mp3"),
]
const RIFT_OPEN: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/rift_open_sound.mp3"),
]

static var _last_index: Dictionary = {}


static func pick(stem: String) -> AudioStream:
	var streams := streams_for(stem)
	if streams.is_empty():
		return null
	if streams.size() == 1:
		return streams[0]
	var previous := int(_last_index.get(stem, -1))
	var index := randi() % streams.size()
	if index == previous:
		index = (index + 1 + randi() % (streams.size() - 1)) % streams.size()
	_last_index[stem] = index
	return streams[index]


static func variation_count(stem: String) -> int:
	return streams_for(stem).size()


static func streams_for(stem: String) -> Array[AudioStream]:
	match stem:
		"phantom_death":
			return DEATH
		"phantom_possess":
			return POSSESS
		"rift_close_sound":
			return RIFT_CLOSE
		"rift_open_sound":
			return RIFT_OPEN
		_:
			return []
