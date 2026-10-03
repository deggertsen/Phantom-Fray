extends RefCounted

## Loads numbered takes from Assets/Audio/SFX and picks one per play.
## phantom_death matches phantom_death_1.mp3. A bare stem.mp3 is a single take.
## https://docs.godotengine.org/en/stable/classes/class_diraccess.html

const FOLDER := "res://Assets/Audio/SFX"

static var _streams: Dictionary = {}
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
	if _streams.has(stem):
		return _streams[stem]
	var loaded: Array[AudioStream] = []
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		_streams[stem] = loaded
		return loaded
	var prefix := stem + "_"
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		var extension := file_name.get_extension().to_lower()
		if extension not in ["mp3", "wav", "ogg"]:
			continue
		var base := file_name.get_basename()
		var suffix := base.substr(prefix.length())
		var numbered := base.begins_with(prefix) and suffix.is_valid_int()
		if base != stem and not numbered:
			continue
		var stream := load("%s/%s" % [FOLDER, file_name]) as AudioStream
		if stream:
			loaded.append(stream)
	_streams[stem] = loaded
	return loaded
