extends RefCounted
class_name WorldMap

## The war, as data. Two tears, two fronts, and cities whose state is their distance to the
## nearest front: consumed behind it, overrun on it, in danger near it, threatened farther out,
## safe beyond. The state is the tier. Picking a city opens one section of it, a short generated
## path of districts; three seals along a connected path are an operation, and operations are
## what liberate a city. See development/World_Map_Design.md.

const STATE_CONSUMED := "consumed"
const STATE_OVERRUN := "overrun"
const STATE_DANGER := "danger"
const STATE_THREATENED := "threatened"
const STATE_SAFE := "safe"

## Distances in projected map units (WorldCoastline's 1000 by 560 box). One degree of
## longitude is about 2.8 units.
const OVERRUN_UNITS := 16.0
const DANGER_UNITS := 48.0
const THREATENED_UNITS := 80.0

const KIND_SINGLE := "single"
const KIND_DUAL := "dual"
const KIND_HOLD := "hold"
const KIND_MAW := "maw"
const KINDS: Array[String] = [KIND_SINGLE, KIND_DUAL, KIND_HOLD, KIND_MAW]

## The ground each tear has taken, in longitude and latitude. Authored until a server moves it.
const ZONES := {
	"jakarta": [[58, 36], [66, 30], [80, 26], [96, 27], [118, 28], [134, 31], [150, 34], [166, 10], [160, -42], [112, -46], [90, -40], [72, -30], [60, -8], [55, 10]],
	"chicago": [[-101, 50], [-90, 50], [-82, 46], [-78, 41], [-83, 33.5], [-92, 31.5], [-96, 36], [-100, 44]],
}
## Where each front is pushing: [lon, lat, degrees], drawn as arrows.
const ARROWS := [
	[54, 22, -100], [80, 27, -10], [126, 31, -15], [160, 10, 70], [168, -20, 90],
	[-106, 40, -110], [-95, 51, -10], [-78, 43, 60], [-88, 29, 170], [-102, 34, -150],
]

## ops is the resistance: operations to liberate. opsDone seeds a fresh profile's war so the map
## is not empty on day one; the player's own operations add to it.
const CITIES := [
	{"id": "portland", "name": "Portland", "lon": -122.7, "lat": 45.5, "ops": 8, "seed_ops": 2, "home": true, "blurb": "Your home city. Breach Night happened here. The northern front is a mountain range away and getting closer."},
	{"id": "vancouver", "name": "Vancouver", "lon": -123.1, "lat": 49.3, "ops": 6, "seed_ops": 1, "blurb": "Threatened. Behind the Rockies, for now."},
	{"id": "denver", "name": "Denver", "lon": -105.0, "lat": 39.7, "ops": 12, "seed_ops": 1, "blurb": "The northern front's western edge. Nobody is here."},
	{"id": "chicago", "name": "Chicago", "lon": -87.6, "lat": 41.9, "ops": 40, "seed_ops": 0, "origin": "SECOND TEAR", "blurb": "The Second Tear. The Overseer opened a second door here on day 31, and the Midwest went in a month."},
	{"id": "toronto", "name": "Toronto", "lon": -79.4, "lat": 43.7, "ops": 20, "seed_ops": 3, "blurb": "Overrun. A Maw rose on the lakefront."},
	{"id": "new_york", "name": "New York", "lon": -74.0, "lat": 40.7, "ops": 24, "seed_ops": 6, "blurb": "On the front. The most fought-over city in the north."},
	{"id": "atlanta", "name": "Atlanta", "lon": -84.4, "lat": 33.7, "ops": 16, "seed_ops": 1, "blurb": "Overrun as the front turned south."},
	{"id": "mexico_city", "name": "Mexico City", "lon": -99.1, "lat": 19.4, "ops": 8, "seed_ops": 4, "blurb": "Threatened. The front is a few days north of the border."},
	{"id": "bogota", "name": "Bogotá", "lon": -74.1, "lat": 4.7, "ops": 0, "seed_ops": 0, "blurb": "Safe. Nothing has crossed the isthmus."},
	{"id": "lima", "name": "Lima", "lon": -77.0, "lat": -12.0, "ops": 0, "seed_ops": 0, "blurb": "Safe. Quiet nights."},
	{"id": "sao_paulo", "name": "São Paulo", "lon": -46.6, "lat": -23.5, "ops": 0, "seed_ops": 0, "blurb": "Safe, and the largest city on Earth still whole."},
	{"id": "buenos_aires", "name": "Buenos Aires", "lon": -58.4, "lat": -34.6, "ops": 0, "seed_ops": 0, "blurb": "Safe."},
	{"id": "berlin", "name": "Berlin", "lon": 13.4, "lat": 52.5, "ops": 0, "seed_ops": 0, "blurb": "Safe. The RSF's European base; strikers deploy from here."},
	{"id": "cairo", "name": "Cairo", "lon": 31.2, "lat": 30.0, "ops": 6, "seed_ops": 3, "blurb": "Threatened. Two cities behind Tehran."},
	{"id": "lagos", "name": "Lagos", "lon": 3.4, "lat": 6.5, "ops": 0, "seed_ops": 0, "blurb": "Safe."},
	{"id": "johannesburg", "name": "Johannesburg", "lon": 28.0, "lat": -26.2, "ops": 0, "seed_ops": 0, "blurb": "Safe."},
	{"id": "nairobi", "name": "Nairobi", "lon": 36.8, "lat": -1.3, "ops": 6, "seed_ops": 2, "blurb": "Threatened. It watches the Indian Ocean."},
	{"id": "moscow", "name": "Moscow", "lon": 37.6, "lat": 55.8, "ops": 0, "seed_ops": 0, "blurb": "Safe, and cold for other reasons."},
	{"id": "tehran", "name": "Tehran", "lon": 51.4, "lat": 35.7, "ops": 12, "seed_ops": 2, "blurb": "In danger. The southern front's western edge is a week away."},
	{"id": "delhi", "name": "Delhi", "lon": 77.2, "lat": 28.6, "ops": 24, "seed_ops": 2, "blurb": "Overrun. On the front itself; a boss holds the junction."},
	{"id": "beijing", "name": "Beijing", "lon": 116.4, "lat": 39.9, "ops": 14, "seed_ops": 3, "blurb": "In danger. The front is moving north through the plain."},
	{"id": "seoul", "name": "Seoul", "lon": 127.0, "lat": 37.6, "ops": 12, "seed_ops": 2, "blurb": "In danger."},
	{"id": "tokyo", "name": "Tokyo", "lon": 139.7, "lat": 35.7, "ops": 28, "seed_ops": 7, "blurb": "Overrun, and fought over every night. The front has stalled here for a month."},
	{"id": "mumbai", "name": "Mumbai", "lon": 72.9, "lat": 19.1, "ops": 30, "seed_ops": 0, "blurb": "Consumed in the third week."},
	{"id": "bangkok", "name": "Bangkok", "lon": 100.5, "lat": 13.8, "ops": 30, "seed_ops": 0, "blurb": "Consumed in the first week."},
	{"id": "jakarta", "name": "Jakarta", "lon": 106.8, "lat": -6.2, "ops": 60, "seed_ops": 0, "origin": "THE BREACH", "blurb": "The Breach. Day zero. The experiments were here."},
	{"id": "manila", "name": "Manila", "lon": 121.0, "lat": 14.6, "ops": 30, "seed_ops": 0, "blurb": "Consumed in the first week."},
	{"id": "perth", "name": "Perth", "lon": 115.9, "lat": -31.9, "ops": 20, "seed_ops": 0, "blurb": "Consumed."},
	{"id": "sydney", "name": "Sydney", "lon": 151.2, "lat": -33.9, "ops": 30, "seed_ops": 0, "blurb": "Consumed in the second week. The last broadcast came from here."},
]

## The world map zooms to a region before a city is picked. Every city is in exactly one; label is
## where the region's name sits on the world view, in longitude and latitude.
const REGIONS := [
	{"id": "north_america", "name": "North America", "label": [-112, 27], "cities": ["portland", "vancouver", "denver", "chicago", "toronto", "new_york", "atlanta", "mexico_city"]},
	{"id": "south_america", "name": "South America", "label": [-66, -10], "cities": ["bogota", "lima", "sao_paulo", "buenos_aires"]},
	{"id": "europe_africa", "name": "Europe & Africa", "label": [18, 16], "cities": ["berlin", "moscow", "cairo", "lagos", "nairobi", "johannesburg"]},
	{"id": "asia", "name": "Asia", "label": [100, 47], "cities": ["tehran", "delhi", "mumbai", "beijing", "seoul", "tokyo", "bangkok", "manila", "jakarta"]},
	{"id": "oceania", "name": "Oceania", "label": [134, -24], "cities": ["perth", "sydney"]},
]
## A region's box is its cities and label grown by this, in projected units.
const REGION_PADDING := 18.0
## The side of the box the map closes in on when a city opens.
const CITY_ZOOM_UNITS := 44.0

## Generic district names; a city's sections draw from these. No in-world place names.
const DISTRICT_NAMES: Array[String] = ["Harbor", "Rail Yards", "Junction", "Stadium", "Reservoir", "Old Town", "Civic Ring", "Foundry", "Airport", "Docks", "University", "Bluffs", "Quarry", "Northgate", "Eastbank", "Riverside"]
## A district's breach-site id is its name as a key ("Rail Yards" is rail_yards). BreachSites
## decides which environment each one plays in; anything it does not know falls back to this.
const DEFAULT_SITE := "dead_city"

## Where a section's three columns sit on an 820 by 500 map, and how rows spread in a column.
const COLUMN_X: Array[float] = [140.0, 410.0, 680.0]
const ROW_STEP := 150.0
const MAP_SIZE := Vector2(820, 500)

# --- Geometry -------------------------------------------------------------------------------

## Longitude and latitude into WorldCoastline's box.
static func project(lon: float, lat: float) -> Vector2:
	return Vector2(
		(lon + 180.0) / 360.0 * WorldCoastline.WIDTH,
		(WorldCoastline.LAT_TOP - lat) / (WorldCoastline.LAT_TOP - WorldCoastline.LAT_BOTTOM) * WorldCoastline.HEIGHT
	)

## The fronts as projected polygons, keyed by the tear that opened them.
static func zone_polygons() -> Dictionary:
	var out := {}
	for key in ZONES:
		var polygon := PackedVector2Array()
		for point in ZONES[key]:
			polygon.append(project(float(point[0]), float(point[1])))
		out[key] = polygon
	return out

static func arrows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for arrow in ARROWS:
		out.append({"point": project(float(arrow[0]), float(arrow[1])), "degrees": float(arrow[2])})
	return out

## The whole projected map.
static func world_box() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(WorldCoastline.WIDTH, WorldCoastline.HEIGHT))

## Every region with its projected label point and box.
static func regions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw in REGIONS:
		var region_data: Dictionary = (raw as Dictionary).duplicate()
		var label_point := project(float(raw["label"][0]), float(raw["label"][1]))
		var box := Rect2(label_point, Vector2.ZERO)
		for city_id in raw["cities"]:
			for city_raw in CITIES:
				if city_raw["id"] == city_id:
					box = box.expand(project(float(city_raw["lon"]), float(city_raw["lat"])))
		region_data["label_point"] = label_point
		region_data["box"] = box.grow(REGION_PADDING)
		out.append(region_data)
	return out

static func region(region_id: String) -> Dictionary:
	for candidate in regions():
		if candidate["id"] == region_id:
			return candidate
	return {}

## The region a city is in, or "".
static func region_of(city_id: String) -> String:
	for raw in REGIONS:
		if city_id in raw["cities"]:
			return String(raw["id"])
	return ""

## The box the map closes in on when a city opens.
static func city_box(point: Vector2) -> Rect2:
	return Rect2(point - Vector2.ONE * CITY_ZOOM_UNITS * 0.5, Vector2.ONE * CITY_ZOOM_UNITS)

static func distance_to_polygon(point: Vector2, polygon: PackedVector2Array) -> float:
	var best := INF
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		# https://docs.godotengine.org/en/stable/classes/class_geometry2d.html#class-geometry2d-method-get-closest-point-to-segment
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)))
	return best

## The state a point on the map is in, and its distance to the nearest front.
static func state_at(point: Vector2) -> Dictionary:
	var polygons := zone_polygons()
	var distance := INF
	for key in polygons:
		var polygon: PackedVector2Array = polygons[key]
		if Geometry2D.is_point_in_polygon(point, polygon):
			return {"state": STATE_CONSUMED, "distance": 0.0}
		distance = minf(distance, distance_to_polygon(point, polygon))
	var state := STATE_SAFE
	if distance <= OVERRUN_UNITS:
		state = STATE_OVERRUN
	elif distance <= DANGER_UNITS:
		state = STATE_DANGER
	elif distance <= THREATENED_UNITS:
		state = STATE_THREATENED
	return {"state": state, "distance": distance}

## Roughly how far a projected distance is in kilometers, for the city card.
static func kilometers(distance: float) -> int:
	return roundi(distance / (WorldCoastline.WIDTH / 360.0) * 111.0 / 100.0) * 100

# --- States and tiers -----------------------------------------------------------------------

static func state_label(state: String) -> String:
	match state:
		STATE_CONSUMED: return "CONSUMED"
		STATE_OVERRUN: return "OVERRUN"
		STATE_DANGER: return "IN DANGER"
		STATE_THREATENED: return "THREATENED"
		_: return "SAFE"

## The difficulty word the world map filters by: easy, medium, hard, or "" where there is nothing.
static func difficulty_of(state: String) -> String:
	match state:
		STATE_OVERRUN: return "hard"
		STATE_DANGER: return "medium"
		STATE_THREATENED: return "easy"
		_: return ""

static func difficulty_label(state: String) -> String:
	match state:
		STATE_OVERRUN: return "HARD"
		STATE_DANGER: return "MEDIUM"
		STATE_THREATENED: return "EASY"
		STATE_CONSUMED: return "OUT OF REACH"
		_: return "NO THREAT DETECTED"

## The DifficultyTier a city plays at. A threatened city plays Standard, or Assist when the
## session asks for it; nothing else has a choice. "" means no missions.
static func tier_for(state: String, assist: bool = false) -> String:
	match state:
		STATE_OVERRUN: return DifficultyTier.FULL_RESONANCE
		STATE_DANGER: return DifficultyTier.OPERATOR
		STATE_THREATENED: return DifficultyTier.ASSIST if assist else DifficultyTier.STANDARD
		_: return ""

static func has_missions(state: String) -> bool:
	return tier_for(state) != ""

static func asks(state: String) -> String:
	match state:
		STATE_CONSUMED: return "Behind the front, out of reach. Nothing can be done here until the front is pushed back to it. No city is ever permanently lost."
		STATE_OVERRUN: return "A boss holds this city. Squats under high sweeps, jumps over low ones, side-steps, push-ups on the spent tentacle. Every operation pushes the front back a district."
		STATE_DANGER: return "Shorter tells, faster lunges. Hold the line while Chen's team seals from the pylons. Every hold here keeps the front off the next city."
		STATE_THREATENED: return "Hands, block, dodge. Seal rifts and keep the front far away. Easy on the body; Assist is a session toggle."
		_: return "No threat detected. There is nothing to fight here tonight; the front is far away."

# --- Cities ---------------------------------------------------------------------------------

## Every city with its projected point, state, distance, and difficulty.
static func cities() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw in CITIES:
		var city: Dictionary = (raw as Dictionary).duplicate()
		var point := project(float(city["lon"]), float(city["lat"]))
		var where := state_at(point)
		city["point"] = point
		city["state"] = where["state"]
		city["distance"] = where["distance"]
		city["difficulty"] = difficulty_of(String(where["state"]))
		city["state_label"] = state_label(String(where["state"]))
		city["difficulty_label"] = difficulty_label(String(where["state"]))
		city["playable"] = has_missions(String(where["state"]))
		out.append(city)
	return out

static func city(city_id: String) -> Dictionary:
	for candidate in cities():
		if candidate.get("id", "") == city_id:
			return candidate
	return {}

static func home_city_id() -> String:
	for raw in CITIES:
		if raw.get("home", false):
			return String(raw["id"])
	return String(CITIES[0]["id"])

## Cities with the player's progress folded in: ops_done, liberation, section index, sealed nodes.
static func city_entries(settings: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in cities():
		var progress := progress_for(settings, String(entry["id"]))
		entry["ops_done"] = progress["ops_done"]
		entry["section"] = progress["section"]
		entry["sealed"] = progress["sealed"]
		entry["liberation"] = liberation(entry, int(progress["ops_done"]))
		entry["resistance"] = resistance_label(int(entry.get("ops", 0)))
		entry["liberated"] = entry["liberation"] >= 100 and entry["playable"]
		out.append(entry)
	return out

static func city_entry(settings: Object, city_id: String) -> Dictionary:
	for entry in city_entries(settings):
		if entry.get("id", "") == city_id:
			return entry
	return {}

static func liberation(city_data: Dictionary, ops_done: int) -> int:
	var state := String(city_data.get("state", STATE_SAFE))
	if state == STATE_SAFE:
		return 100
	if state == STATE_CONSUMED:
		return 0
	var ops := int(city_data.get("ops", 0))
	if ops <= 0:
		return 100
	return clampi(roundi(100.0 * ops_done / ops), 0, 100)

static func world_liberation(settings: Object) -> int:
	var entries := city_entries(settings)
	if entries.is_empty():
		return 0
	var total := 0
	for entry in entries:
		total += int(entry["liberation"])
	return roundi(float(total) / entries.size())

static func resistance_label(ops: int) -> String:
	if ops <= 0:
		return "NONE"
	if ops >= 20:
		return "HEAVY"
	if ops >= 10:
		return "MODERATE"
	return "LIGHT"

# --- Sections -------------------------------------------------------------------------------

## One section of a city: three columns of one to three districts, every district linked to at
## least one in the next column. Generated from the city id and section index, so the same
## ground comes back until it is sealed. A lone district is never a Maw and a column is never
## all Maws, so there is always a way around the boss.
static func section(city_id: String, index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [city_id, index])
	var names := DISTRICT_NAMES.duplicate()
	for i in range(names.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: String = names[i]
		names[i] = names[j]
		names[j] = swap
	var columns: Array = []
	var nodes: Array[Dictionary] = []
	var used := 0
	for column in 3:
		var count := rng.randi_range(1, 3)
		var members: Array[Dictionary] = []
		for row in count:
			var kind: String = KINDS[rng.randi_range(0, KINDS.size() - 1)]
			if count == 1 and kind == KIND_MAW:
				kind = KIND_DUAL
			var district: String = names[used % names.size()]
			used += 1
			members.append({
				"id": "s%dn%d" % [index, used],
				"column": column,
				"row": row,
				"name": district,
				"kind": kind,
				"site": site_for(district),
				"point": Vector2(COLUMN_X[column], MAP_SIZE.y * 0.5 + (row - (count - 1) * 0.5) * ROW_STEP),
			})
		if count > 1:
			var all_maw := true
			for member in members:
				if member["kind"] != KIND_MAW:
					all_maw = false
			if all_maw:
				members[0]["kind"] = KIND_SINGLE
		columns.append(members)
		nodes.append_array(members)
	var edges: Array = []
	for column in 2:
		var next: Array = columns[column + 1]
		for member in columns[column]:
			var linked := 0
			for target in next:
				if rng.randf() < 0.6:
					edges.append([member["id"], target["id"]])
					linked += 1
			if linked == 0:
				edges.append([member["id"], next[rng.randi_range(0, next.size() - 1)]["id"]])
		for target in next:
			var reached := false
			for edge in edges:
				if edge[1] == target["id"]:
					reached = true
			if not reached:
				var from: Dictionary = columns[column][rng.randi_range(0, columns[column].size() - 1)]
				edges.append([from["id"], target["id"]])
	var starts: Array[String] = []
	for member in columns[0]:
		starts.append(String(member["id"]))
	return {"city_id": city_id, "index": index, "nodes": nodes, "edges": edges, "starts": starts}

static func node_in(section_data: Dictionary, node_id: String) -> Dictionary:
	for node in section_data.get("nodes", []):
		if node.get("id", "") == node_id:
			return node
	return {}

## Districts a Striker may deploy to now: the first column with nothing sealed, otherwise the
## districts linked from the last seal. Nothing once three are sealed.
static func available_nodes(section_data: Dictionary, sealed: Array) -> Array[String]:
	var out: Array[String] = []
	if sealed.size() >= 3:
		return out
	if sealed.is_empty():
		for start in section_data.get("starts", []):
			out.append(String(start))
		return out
	var last := String(sealed[sealed.size() - 1])
	for edge in section_data.get("edges", []):
		if edge[0] == last:
			out.append(String(edge[1]))
	return out

static func node_status(section_data: Dictionary, sealed: Array, node_id: String) -> String:
	if node_id in sealed:
		return "sealed"
	if node_id in available_nodes(section_data, sealed):
		return "open"
	return "locked"

## The breach-site id for a district name, passed straight to ArenaPresentation.apply_site.
static func site_for(district: String) -> String:
	return district.to_lower().replace(" ", "_")

static func kind_label(kind: String, tier_id: String) -> String:
	match kind:
		KIND_SINGLE: return "SINGLE RIFT"
		KIND_DUAL: return "DUAL RIFT"
		KIND_HOLD: return "HOLD THE LINE"
		KIND_MAW: return "MAW RIFT, BOSS" if DifficultyTier.allows_bosses(tier_id) else "MAW RIFT"
		_: return kind.to_upper()

static func kind_summary(kind: String, tier_id: String) -> String:
	match kind:
		KIND_SINGLE: return "One rift, a steady stream. The plain seal."
		KIND_DUAL: return "Two doors open in one view, out of step. Keep both in front of you."
		KIND_HOLD: return "Chen's team seals from the pylons. Keep them off you for the whole interval."
		KIND_MAW:
			if DifficultyTier.allows_bosses(tier_id):
				return "One vast rift that may tear open into the boss: squats, jumps, push-ups. Take the other district if you do not want it tonight."
			return "One vast rift, a steady flood, and a glimpse of what holds it open. No boss below hard."
		_: return ""

# --- Missions -------------------------------------------------------------------------------

## The mission id for a district, carrying everything results need to credit the seal.
static func mission_id(city_id: String, section_index: int, node_id: String) -> String:
	return "world:%s:%d:%s" % [city_id, section_index, node_id]

static func is_world_mission(mission_id_value: String) -> bool:
	return mission_id_value.begins_with("world:")

## {"city_id", "section", "node_id"} from a world mission id, or {} for anything else.
static func parse_mission_id(mission_id_value: String) -> Dictionary:
	var parts := mission_id_value.split(":")
	if parts.size() != 4 or parts[0] != "world":
		return {}
	return {"city_id": parts[1], "section": int(parts[2]), "node_id": parts[3]}

## Best scores and times are kept per city, district kind, and tier.
static func record_key(city_id: String, kind: String, tier_id: String) -> String:
	return DifficultyTier.record_key("world:%s:%s" % [city_id, kind], tier_id)

## A playable mission for a district at a tier, in MissionCatalog's vocabulary. The round applies
## the tier itself (RoundController.begin_round), so the waves here are at Standard.
static func build_mission(city_data: Dictionary, section_index: int, node: Dictionary, tier_id: String) -> Dictionary:
	var kind := String(node.get("kind", KIND_SINGLE))
	var city_name := String(city_data.get("name", "the city"))
	var district := String(node.get("name", "District"))
	var mission := {
		"id": mission_id(String(city_data.get("id", "")), section_index, String(node.get("id", ""))),
		"codename": "%s • %s" % [city_name.to_upper(), district.to_upper()],
		"title": kind_label(kind, tier_id),
		"summary": kind_summary(kind, tier_id),
		"objective": "SEAL THE DISTRICT",
		"site": node.get("site", DEFAULT_SITE),
		"world": {"city_id": city_data.get("id", ""), "section": section_index, "node_id": node.get("id", ""), "kind": kind},
		"start_line": "CHEN: %s. PUSH THE LINE." % district.to_upper(),
		"pressure_labels": [district.to_upper()],
		"open_barks": [""],
		"seal_lines": [],
		"victory_line": "Chen: %s is sealed. The line moved. Pick the next district when you are ready." % district,
		"defeat_line": "Chen: The failsafe fired. %s held. Rest, then go back in." % district,
	}
	match kind:
		KIND_DUAL:
			mission["expected_minutes"] = [6, 8]
			mission["max_concurrent"] = 2
			mission["cluster_rifts"] = true
			mission["pressure_labels"] = ["PAIR LIVE", "PARTNER"]
			mission["rifts"] = [
				_wave(130, 3.1, 2, 1.1, 0.9, ["yellow", "blue", "green", "pink"]),
				_wave(130, 3.6, 2, 1.1, 0.9, ["blue", "green", "pink", "yellow"]),
			]
		KIND_HOLD:
			mission["expected_minutes"] = [5, 7]
			mission["objective"] = "HOLD THE LINE"
			mission["start_line"] = "CHEN: %s. MY TEAM IS ON THE SEAL. KEEP THEM OFF YOU." % district.to_upper()
			var hold := _wave(360, 3.0, 3, 1.0, 1.0, ["yellow", "blue", "green", "pink"])
			# RiftManager drains the rift on its own over this long; the player's seals shorten it.
			hold["hold_seconds"] = 150.0
			mission["rifts"] = [hold]
		KIND_MAW:
			var maw := MissionCatalog.get_mission("the_maw")
			mission["expected_minutes"] = maw.get("expected_minutes", [4, 6])
			mission["objective"] = "SEAL THE MAW"
			mission["arc_rifts"] = true
			mission["start_line"] = "CHEN: A MAW IN %s. IT DOES NOT STOP FEEDING." % district.to_upper()
			mission["glimpse"] = true
			if maw.has("tier_boss"):
				mission["tier_boss"] = (maw["tier_boss"] as Dictionary).duplicate(true)
			mission["rifts"] = []
			for wave in maw.get("rifts", []):
				mission["rifts"].append((wave as Dictionary).duplicate(true))
		_:
			mission["expected_minutes"] = [4, 6]
			mission["rifts"] = [_wave(180, 3.4, 3, 1.0, 1.0, ["yellow", "blue", "green", "pink"])]
	return mission

static func _wave(health: int, interval: float, max_live: int, speed_scale: float, telegraph_scale: float, pool: Array, scale: float = 1.0) -> Dictionary:
	return {"health": health, "interval": interval, "max_live": max_live, "speed_scale": speed_scale, "telegraph_scale": telegraph_scale, "pool": pool, "scale": scale}

# --- Progress -------------------------------------------------------------------------------

## {"ops_done", "section", "sealed"} for a city, from GameSettings.world_progress plus the seed.
static func progress_for(settings: Object, city_id: String) -> Dictionary:
	var seed_ops := 0
	for raw in CITIES:
		if raw.get("id", "") == city_id:
			seed_ops = int(raw.get("seed_ops", 0))
	var stored: Dictionary = {}
	if settings != null:
		var all: Variant = settings.get("world_progress")
		if all is Dictionary and (all as Dictionary).has(city_id):
			stored = (all as Dictionary)[city_id]
	return {
		"ops_done": seed_ops + int(stored.get("ops_done", 0)),
		"section": int(stored.get("section", 0)),
		"sealed": Array(stored.get("sealed", [])),
	}

## Credits a sealed district. Returns what happened: whether the operation completed and the
## city's new counts. Three seals finish the operation, advance the section, and clear the path.
static func seal_node(settings: Object, city_id: String, node_id: String) -> Dictionary:
	var progress := progress_for(settings, city_id)
	var sealed: Array = progress["sealed"]
	if node_id in sealed:
		return {"operation_complete": false, "ops_done": progress["ops_done"], "section": progress["section"], "sealed": sealed}
	sealed.append(node_id)
	var completed := sealed.size() >= 3
	var stored := {"ops_done": int(progress["ops_done"]) - _seed_ops(city_id), "section": int(progress["section"]), "sealed": sealed}
	if completed:
		stored["ops_done"] += 1
		stored["section"] += 1
		stored["sealed"] = []
	if settings != null and settings.has_method("store_world_progress"):
		settings.call("store_world_progress", city_id, stored)
	return {"operation_complete": completed, "ops_done": stored["ops_done"] + _seed_ops(city_id), "section": stored["section"], "sealed": stored["sealed"]}

static func _seed_ops(city_id: String) -> int:
	for raw in CITIES:
		if raw.get("id", "") == city_id:
			return int(raw.get("seed_ops", 0))
	return 0
