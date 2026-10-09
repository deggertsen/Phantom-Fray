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
	return [_first_light(), _widen_the_ring(), _chens_gambit(), _double_breach(), _open_arc(), _the_maw()]

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
		"start_line": "CHEN: READ THE LUNGE. THEN ANSWER.",
		"pressure_labels": ["CONTACT", "ADAPTING"],
		"open_barks": ["", "THEY ADJUST — FASTER LUNGES"],
		"seal_lines": ["FIRST SEAL. SCOUTS ARE CORRECTING."],
		"victory_line": "Chen: Clean seals. A civic rift just tore open. They are not wandering. Something is aiming them.",
		"defeat_line": "Chen: The matrix drank you before the seal. Learn the pattern. Then go back in.",
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
		"objective": "SEAL SIX RIFTS",
		"start_line": "CHEN: GREENS CRASH. PINKS OWN A LINE.",
		"pressure_labels": ["CONTACT", "MIXED", "RING LOUD", "SECOND WAVE", "RING HOT", "LAST DOOR"],
		"open_barks": ["", "PINKS IN THE MIX — LEAVE THE LINE", "THE RING IS LOUD. KEEP THE CHAIN.", "THEY OPENED AGAIN.", "SAME RING. KEEP THE CHAIN.", "LAST DOOR. SEAL IT."],
		"seal_lines": ["RING STABILIZING.", "SECOND SEAL. SOMETHING ANSWERED.", "HALF THE RING IS DOWN.", "IT OPENED MORE.", "ONE LEFT IN THE RING."],
		"victory_line": "Chen: A signal rode the last seal. Whatever is on the other side looked back.",
		"defeat_line": "Chen: The ring is still open, and it felt you flinch. Reset and take the line again.",
		"rifts": [
			_wave(90, 3.8, 3, 0.95, 1.12, ["yellow", "blue", "green"]),
			_wave(110, 3.1, 3, 1.05, 0.95, ["yellow", "blue", "green", "pink"]),
			_wave(120, 2.7, 4, 1.15, 0.85, ["blue", "green", "pink", "yellow"]),
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
		"start_line": "CHEN: THE OVERSEER IS AIMING THEM.",
		"pressure_labels": ["MARKED", "HUNTED", "JUNCTION", "IT ANSWERED", "NO MERCY", "LAST SEAL"],
		"open_barks": ["", "THEY KNOW YOUR LEAD HAND.", "JUNCTION LIVE. DO NOT BLINK.", "IT OPENED ANOTHER.", "SHORTER TELLS. KEEP ANSWERING.", "ONE DOOR LEFT."],
		"seal_lines": ["IT FELT THAT.", "TWO DOWN. THE JUNCTION IS ANGRY.", "HALF SEALED. IT IS STILL AIMING.", "AGAIN. DO NOT BLINK.", "LAST DOOR. FINISH THE JUNCTION."],
		"victory_line": "Chen: It knows your resonance now. This was the opening move. Not the end of the war.",
		"defeat_line": "Chen: The Overseer learned more from your fall than from the seals. Get up.",
		"rifts": [
			_wave(100, 3.2, 3, 1.05, 0.95, ["yellow", "blue", "green", "pink"]),
			_wave(120, 2.6, 4, 1.16, 0.8, ["green", "pink", "blue", "yellow", "pink"]),
			_wave(140, 2.2, 4, 1.28, 0.7, ["yellow", "blue", "green", "pink"]),
			_wave(100, 3.2, 3, 1.05, 0.95, ["yellow", "blue", "green", "pink"]),
			_wave(120, 2.6, 4, 1.16, 0.8, ["green", "pink", "blue", "yellow", "pink"]),
			_wave(140, 2.2, 4, 1.28, 0.7, ["yellow", "blue", "green", "pink"]),
		],
	}

static func _double_breach() -> Dictionary:
	return {
		"id": "double_breach",
		"codename": "OP-04",
		"title": "DOUBLE BREACH",
		"summary": "Two rifts open in the same view. Their scouts arrive out of step.",
		"objective": "SEAL THE PAIRED RIFTS",
		"max_concurrent": 2,
		"cluster_rifts": true,
		"start_line": "CHEN: TWO DOORS. SAME VIEW. THEY WILL NOT SYNC.",
		"pressure_labels": ["PAIR LIVE", "PARTNER", "SECOND PAIR", "STILL FEEDING", "THIRD PAIR", "OFFSET", "FOURTH PAIR", "LAST DOOR"],
		"open_barks": ["", "THE OTHER ONE IS ALREADY OPEN.", "NEW PAIR. KEEP THEM IN FRONT.", "ONE DOWN. MORE BEHIND IT.", "THEY OPENED AGAIN. SAME VIEW.", "OFFSET. DON'T CHASE BOTH.", "LAST PAIR. STAY IN FRONT.", "FINISH THE ONE THAT'S LEFT."],
		"seal_lines": ["ONE DOWN. ITS PARTNER IS STILL FEEDING.", "PAIR SEALED. THE NEXT TWO ARE OPENING.", "HALF THE PAIRS ARE DOWN.", "KEEP THE LIVE ONE IN VIEW.", "ANOTHER PAIR. THEY STILL WON'T SYNC.", "ONE PARTNER LEFT IN THIS PAIR.", "LAST DOOR. FINISH IT."],
		"victory_line": "Chen: You sealed them as a pair. The Overseer will not make the next one this polite.",
		"defeat_line": "Chen: The pair drank you. Take the left door before their scouts overlap.",
		"rifts": _paired_assault_waves(),
	}

static func _open_arc() -> Dictionary:
	return {
		"id": "open_arc",
		"codename": "OP-05",
		"title": "OPEN ARC",
		"summary": "The paired doors again, set wider across the arc in front of you.",
		"objective": "SEAL THE OPEN ARC",
		"max_concurrent": 2,
		"arc_rifts": true,
		"start_line": "CHEN: SAME PAIR. WIDER ARC. NOTHING BEHIND YOU.",
		"pressure_labels": ["ARC LIVE", "PARTNER", "SECOND ARC", "STILL WIDE", "THIRD ARC", "HOLD THE FRONT", "FOURTH ARC", "LAST DOOR"],
		"open_barks": ["", "THE OTHER DOOR IS WIDE, NOT BEHIND.", "NEW PAIR. BOTH STAY IN FRONT.", "ONE DOWN. THE ARC IS STILL OPEN.", "THEY OPENED WIDER. DON'T TURN AROUND.", "OFFSET. KEEP BOTH IN THE ARC.", "LAST PAIR. NINETY DEGREES, NO MORE.", "FINISH THE ONE STILL IN FRONT."],
		"seal_lines": ["ONE DOWN. ITS PARTNER IS STILL IN THE ARC.", "PAIR SEALED. THE NEXT TWO OPEN WIDER.", "HALF THE ARC IS DOWN.", "STAY INSIDE THE FRONT.", "ANOTHER PAIR. STILL NOTHING BEHIND YOU.", "ONE PARTNER LEFT ON THIS ARC.", "LAST DOOR. FINISH THE ARC."],
		"victory_line": "Chen: You held a wider front. The Overseer is running out of polite geometry.",
		"defeat_line": "Chen: The wide pair drank you. Face the arc. Do not spin around looking for the other door.",
		"rifts": _paired_assault_waves(),
	}

static func _the_maw() -> Dictionary:
	return {
		"id": "the_maw",
		"codename": "OP-06",
		"title": "THE MAW",
		"summary": "One vast rift. Phantoms pour out in a steady flood, and the mouth takes a long chew to shut.",
		"objective": "SEAL THE MAW",
		"arc_rifts": true,
		"start_line": "CHEN: ONE MOUTH. IT DOES NOT STOP FEEDING.",
		"pressure_labels": ["THE MAW"],
		"open_barks": [""],
		"seal_lines": [],
		"victory_line": "Chen: The Maw is shut. It will remember how long you made it chew.",
		"defeat_line": "Chen: The Maw outpaced you. Kill faster than it can replace them.",
		"rifts": [
			_wave(800, 0.875, 8, 1.0, 1.0, ["yellow", "blue", "green", "pink"], 2.0),
		],
	}

static func _paired_assault_waves() -> Array:
	return [
		_wave(120, 3.1, 2, 1.12, 0.88, ["yellow", "blue", "green", "pink"]),
		_wave(120, 3.6, 2, 1.12, 0.88, ["blue", "green", "pink", "yellow"]),
		_wave(140, 2.6, 2, 1.24, 0.74, ["green", "pink", "yellow", "blue"]),
		_wave(140, 3.0, 2, 1.24, 0.74, ["pink", "yellow", "green", "blue"]),
		_wave(120, 3.1, 2, 1.12, 0.88, ["yellow", "blue", "green", "pink"]),
		_wave(120, 3.6, 2, 1.12, 0.88, ["blue", "green", "pink", "yellow"]),
		_wave(140, 2.6, 2, 1.24, 0.74, ["green", "pink", "yellow", "blue"]),
		_wave(140, 3.0, 2, 1.24, 0.74, ["pink", "yellow", "green", "blue"]),
	]

static func _wave(
	health: int,
	interval: float,
	max_live: int,
	speed_scale: float,
	telegraph_scale: float,
	pool: Array,
	scale: float = 1.0
) -> Dictionary:
	return {
		"health": health,
		"interval": interval,
		"max_live": max_live,
		"speed_scale": speed_scale,
		"telegraph_scale": telegraph_scale,
		"pool": pool,
		"scale": scale,
	}
