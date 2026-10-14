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
## The player taking a hit.
const BONES_CRACKING: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/bones_cracking_1.mp3"),
	preload("res://Assets/Audio/SFX/bones_cracking_2.mp3"),
	preload("res://Assets/Audio/SFX/bones_cracking_3.mp3"),
	preload("res://Assets/Audio/SFX/bones_cracking_4.mp3"),
	preload("res://Assets/Audio/SFX/bones_cracking_5.mp3"),
	preload("res://Assets/Audio/SFX/bones_cracking_6.mp3"),
	preload("res://Assets/Audio/SFX/bones_cracking_7.mp3"),
	preload("res://Assets/Audio/SFX/bones_cracking_8.mp3"),
]
const RIFT_CLOSE: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/rift_close_sound_1.mp3"),
	preload("res://Assets/Audio/SFX/rift_close_sound_2.mp3"),
	preload("res://Assets/Audio/SFX/rift_close_sound_3.mp3"),
]
const RIFT_OPEN: Array[AudioStream] = [
	preload("res://Assets/Audio/SFX/rift_open_sound.mp3"),
]
## The resonance sweep. No takes yet, so it generates its own; preload sweep_tell_1.mp3 and so on here.
const SWEEP_TELL: Array[AudioStream] = []
const SWEEP_WHOOSH: Array[AudioStream] = []

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
		"bones_cracking":
			return BONES_CRACKING
		"rift_close_sound":
			return RIFT_CLOSE
		"rift_open_sound":
			return RIFT_OPEN
		"sweep_tell":
			return SWEEP_TELL
		"sweep_whoosh":
			return SWEEP_WHOOSH
		_:
			return []
