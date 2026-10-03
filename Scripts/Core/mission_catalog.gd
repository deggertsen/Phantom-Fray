extends RefCounted
class_name MissionCatalog

const SCENE_BY_ID := {
	"yellow": "res://Scenes/Phantoms/yellow_phantom.tscn",
	"blue": "res://Scenes/Phantoms/blue_phantom.tscn",
	"green": "res://Scenes/Phantoms/green_phantom.tscn",
	"pink": "res://Scenes/Phantoms/pink_phantom.tscn",
}

static func scene_path(variant_id: String) -> String:
	return String(SCENE_BY_ID.get(variant_id, ""))

static func all_missions() -> Array[Dictionary]:
	return [_first_light(), _widen_the_ring(), _chens_gambit()]

static func get_mission(mission_id: String) -> Dictionary:
	for mission in all_missions():
		if mission.get("id", "") == mission_id:
			return mission
	return {}

static func is_unlocked_with_clears(mission_id: String, cleared: PackedStringArray) -> bool:
	var missions := all_missions()
	for index in range(missions.size()):
		if missions[index].get("id", "") != mission_id:
			continue
		if index == 0:
			return true
		var previous := String(missions[index - 1].get("id", ""))
		return previous in cleared
	return false

static func is_unlocked(mission_id: String, settings: Object) -> bool:
	return is_unlocked_with_clears(mission_id, _cleared_from(settings))

static func next_unlocked_id(settings: Object) -> String:
	var cleared := _cleared_from(settings)
	var missions := all_missions()
	for mission in missions:
		var mission_id := String(mission.get("id", ""))
		if mission_id not in cleared and is_unlocked_with_clears(mission_id, cleared):
			return mission_id
	if missions.is_empty():
		return ""
	return String(missions[missions.size() - 1].get("id", ""))

static func unlocked_followup(mission_id: String, settings: Object) -> String:
	var missions := all_missions()
	for index in range(missions.size() - 1):
		if missions[index].get("id", "") != mission_id:
			continue
		var follow := String(missions[index + 1].get("id", ""))
		if is_unlocked(follow, settings):
			return follow
		return ""
	return ""

static func deploy_detail(settings: Object) -> String:
	var mission := get_mission(next_unlocked_id(settings))
	if mission.is_empty():
		return "Seal the next live rift before the window collapses"
	var cleared := _cleared_from(settings)
	var replay := String(mission.get("id", "")) in cleared
	var prefix := "REPLAY" if replay else "NEXT"
	return "%s • %s %s" % [prefix, mission.get("codename", "OP"), mission.get("title", "MISSION")]

static func operation_entries(settings: Object) -> Array[Dictionary]:
	var cleared := _cleared_from(settings)
	var entries: Array[Dictionary] = []
	var missions := all_missions()
	for index in range(missions.size()):
		var mission: Dictionary = missions[index]
		var mission_id := String(mission.get("id", ""))
		var unlocked := is_unlocked_with_clears(mission_id, cleared)
		var lock_reason := "Clear the previous operation"
		if index > 0:
			lock_reason = "Seal %s first" % missions[index - 1].get("title", "the previous operation")
		entries.append({
			"id": mission_id,
			"codename": mission.get("codename", ""),
			"title": mission.get("title", ""),
			"summary": mission.get("summary", ""),
			"unlocked": unlocked,
			"cleared": mission_id in cleared,
			"lock_reason": lock_reason,
		})
	return entries

static func _cleared_from(settings: Object) -> PackedStringArray:
	if settings == null:
		return PackedStringArray()
	var value: Variant = settings.get("cleared_missions")
	if value is PackedStringArray:
		return value
	return PackedStringArray()

static func _first_light() -> Dictionary:
	return {
		"id": "first_light",
		"codename": "OP-01",
		"title": "FIRST LIGHT",
		"summary": "Proving ground. Gold lunges left, blue lunges right. Read it, then answer.",
		"objective": "SEAL TWO RIFTS",
		"duration": 180.0,
		"start_line": "CHEN: READ THE LUNGE. THEN ANSWER.",
		"pressure_labels": ["CONTACT", "ADAPTING"],
		"open_barks": ["", "THEY ADJUST — FASTER LUNGES"],
		"seal_lines": ["FIRST SEAL. SCOUTS ARE CORRECTING."],
		"victory_line": "Chen: Clean seals. A civic rift just tore open. They are not wandering. Something is aiming them.",
		"defeat_line": "Chen: The matrix drank you before the seal. Learn the pattern. Then go back in.",
		"timeout_line": "Chen: The window collapsed. The proving rift is still feeding.",
		"rifts": [
			_wave(70, 4.2, 2, 0.85, 1.28, ["yellow", "yellow", "blue"]),
			_wave(90, 3.4, 3, 1.0, 1.05, ["yellow", "blue", "yellow", "blue"]),
		],
	}

static func _widen_the_ring() -> Dictionary:
	return {
		"id": "widen_the_ring",
		"codename": "OP-02",
		"title": "WIDEN THE RING",
		"summary": "Civic ring. Greens crash the chest. Pinks paint a line and own it.",
		"objective": "SEAL THREE RIFTS",
		"duration": 210.0,
		"start_line": "CHEN: GREENS CRASH. PINKS OWN A LINE.",
		"pressure_labels": ["CONTACT", "MIXED", "RING LOUD"],
		"open_barks": ["", "PINKS IN THE MIX — LEAVE THE LINE", "THE RING IS LOUD. KEEP THE CHAIN."],
		"seal_lines": ["RING STABILIZING.", "SECOND SEAL. SOMETHING ANSWERED."],
		"victory_line": "Chen: A signal rode the last seal. Whatever is on the other side looked back.",
		"defeat_line": "Chen: The ring is still open, and it felt you flinch. Reset and take the line again.",
		"timeout_line": "Chen: Time bled out. The civic rifts are still pouring scouts.",
		"rifts": [
			_wave(90, 3.8, 3, 0.95, 1.12, ["yellow", "blue", "green"]),
			_wave(110, 3.1, 3, 1.05, 0.95, ["yellow", "blue", "green", "pink"]),
			_wave(120, 2.7, 4, 1.15, 0.85, ["blue", "green", "pink", "yellow"]),
		],
	}

static func _chens_gambit() -> Dictionary:
	return {
		"id": "chens_gambit",
		"codename": "OP-03",
		"title": "CHEN'S GAMBIT",
		"summary": "Junction rift. The Overseer is aiming them. Shorter tells. No free swings.",
		"objective": "SEAL THE JUNCTION",
		"duration": 240.0,
		"start_line": "CHEN: THE OVERSEER IS AIMING THEM.",
		"pressure_labels": ["MARKED", "HUNTED", "JUNCTION"],
		"open_barks": ["", "THEY KNOW YOUR LEAD HAND.", "JUNCTION LIVE. DO NOT BLINK."],
		"seal_lines": ["IT FELT THAT.", "TWO DOWN. THE JUNCTION IS ANGRY."],
		"victory_line": "Chen: It knows your resonance now. This was the opening move. Not the end of the war.",
		"defeat_line": "Chen: The Overseer learned more from your fall than from the seals. Get up.",
		"timeout_line": "Chen: The junction is still open. It will not forget your timing.",
		"rifts": [
			_wave(100, 3.2, 3, 1.05, 0.95, ["yellow", "blue", "green", "pink"]),
			_wave(120, 2.6, 4, 1.16, 0.8, ["green", "pink", "blue", "yellow", "pink"]),
			_wave(140, 2.2, 4, 1.28, 0.7, ["yellow", "blue", "green", "pink"]),
		],
	}

static func _wave(
	health: int,
	interval: float,
	max_live: int,
	speed_scale: float,
	telegraph_scale: float,
	pool: Array
) -> Dictionary:
	return {
		"health": health,
		"interval": interval,
		"max_live": max_live,
		"speed_scale": speed_scale,
		"telegraph_scale": telegraph_scale,
		"pool": pool,
	}
