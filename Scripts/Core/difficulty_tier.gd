extends RefCounted
class_name DifficultyTier

## The four difficulties. A mission is authored once, at Standard, in MissionCatalog; a tier is a
## transform applied to a copy of it when the round begins (RoundController.begin_round), so the
## catalog stays the only source of base numbers and Standard plays exactly as authored.
##
## Each tier multiplies the wave fields (speed_scale, telegraph_scale, health, interval) and sets
## contact_scale, which RiftManager applies to every phantom's and hazard's contact damage. Flags
## say what the tier asks of the body: sweeps at duck depth only, or squats, jumps, and push-ups,
## and whether a boss can come through. Only Full Resonance has bosses (decision 17).
## The war map will take the choice over from the Operations screen; nothing here assumes a menu.
## See development/Exercise_Mechanics_Exploration.md, section 4.

const ASSIST := "assist"
const STANDARD := "standard"
const OPERATOR := "operator"
const FULL_RESONANCE := "full_resonance"
const ORDER: Array[String] = [ASSIST, STANDARD, OPERATOR, FULL_RESONANCE]
const DEFAULT := STANDARD
## A sweep's head drop as a share of standing height: a duck, which a bend also clears, or a squat.
const DUCK_DEPTH := 0.12
const SQUAT_DEPTH := 0.20

const TIERS := {
	ASSIST: {
		"label": "ASSIST",
		"blurb": "Slower phantoms, longer tells, softer hits.",
		"speed": 0.85,
		"telegraph": 1.25,
		"health": 0.8,
		"interval": 1.15,
		"contact": 0.6,
		"duck_only": true,
		"squats": false,
		"jumps": false,
		"push_ups": false,
		"bosses": false,
	},
	STANDARD: {
		"label": "STANDARD",
		"blurb": "The operations as Dr. Chen tuned them.",
		"speed": 1.0,
		"telegraph": 1.0,
		"health": 1.0,
		"interval": 1.0,
		"contact": 1.0,
		"duck_only": true,
		"squats": false,
		"jumps": false,
		"push_ups": false,
		"bosses": false,
	},
	OPERATOR: {
		"label": "OPERATOR",
		"blurb": "Faster lunges, shorter tells, harder hits.",
		"speed": 1.12,
		"telegraph": 0.85,
		"health": 1.15,
		"interval": 0.9,
		"contact": 1.25,
		"duck_only": true,
		"squats": false,
		"jumps": false,
		"push_ups": false,
		"bosses": false,
	},
	# The movement difficulty: an intensity, not a harder Operator. Speed and tells stay at
	# Standard so the extra work is the body, not reaction time. Assumes the player can jump.
	FULL_RESONANCE: {
		"label": "FULL RESONANCE",
		"blurb": "Squats, jumps, and push-ups. Clear your space; you will jump.",
		"speed": 1.0,
		"telegraph": 1.0,
		"health": 1.1,
		"interval": 1.0,
		"contact": 1.0,
		"duck_only": false,
		"squats": true,
		"jumps": true,
		"push_ups": true,
		"bosses": true,
		# A squat-depth sweep joins every wave's pool, and the rift never lights one sooner than
		# this many seconds after its last: at most 7.5 squat demands a minute, inside the budget
		# of about 12 with rests (section 3, "Squats").
		"sweep_min_gap": 8.0,
		# Chen's line in the countdown.
		"deploy_event": "deploy_full_resonance",
	},
}

static func is_valid(tier_id: String) -> bool:
	return TIERS.has(tier_id)

## A known tier id, or Standard.
static func resolve(tier_id: String) -> String:
	return tier_id if is_valid(tier_id) else DEFAULT

static func info(tier_id: String) -> Dictionary:
	return TIERS[resolve(tier_id)]

static func label(tier_id: String) -> String:
	return String(info(tier_id).get("label", "STANDARD"))

static func blurb(tier_id: String) -> String:
	return String(info(tier_id).get("blurb", ""))

static func allows_bosses(tier_id: String) -> bool:
	return bool(info(tier_id).get("bosses", false))

static func asks_for_movement(tier_id: String) -> bool:
	var tier := info(tier_id)
	return bool(tier.get("squats", false)) or bool(tier.get("jumps", false)) or bool(tier.get("push_ups", false))

## The event Chen says in the countdown at this tier, or "" for none.
static func deploy_event(tier_id: String) -> String:
	return String(info(tier_id).get("deploy_event", ""))

## Where best scores and best times are kept. Standard keeps the bare mission id, so records
## saved before tiers existed (all at Standard) stay where they were.
static func record_key(mission_id: String, tier_id: String) -> String:
	var tier := resolve(tier_id)
	return mission_id if tier == STANDARD else "%s@%s" % [mission_id, tier]

## A copy of the mission at this tier. Every wave goes through apply_wave. A mission's
## "tier_boss" block becomes its "boss" only where the tier allows bosses, and then replaces the
## glimpse; anywhere else it is dropped and the mission ends as authored. The result carries
## "tier", and applying again returns it unchanged.
static func apply_mission(mission: Dictionary, tier_id: String) -> Dictionary:
	if mission.has("tier"):
		return mission
	var tier := resolve(tier_id)
	var tiered := mission.duplicate(true)
	tiered["tier"] = tier
	var waves: Array = []
	for wave in mission.get("rifts", []):
		waves.append(apply_wave(wave, tier))
	if mission.has("rifts"):
		tiered["rifts"] = waves
	var boss: Dictionary = tiered.get("tier_boss", {})
	tiered.erase("tier_boss")
	if not boss.is_empty() and allows_bosses(tier):
		tiered.erase("glimpse")
		tiered["boss"] = boss
		if boss.has("expected_minutes"):
			tiered["expected_minutes"] = boss["expected_minutes"]
	return tiered

## One wave at this tier. Standard returns an identical copy. Fields a wave does not have stay
## absent unless the tier changes them, so a Standard wave compares equal to the catalog's.
static func apply_wave(wave: Dictionary, tier_id: String) -> Dictionary:
	var tier := info(tier_id)
	var out := wave.duplicate(true)
	out["speed_scale"] = float(wave.get("speed_scale", 1.0)) * float(tier["speed"])
	out["telegraph_scale"] = float(wave.get("telegraph_scale", 1.0)) * float(tier["telegraph"])
	if wave.has("health"):
		out["health"] = maxi(int(round(float(wave["health"]) * float(tier["health"]))), 1)
	if wave.has("interval"):
		out["interval"] = float(wave["interval"]) * float(tier["interval"])
	if not is_equal_approx(float(tier["contact"]), 1.0):
		out["contact_scale"] = float(wave.get("contact_scale", 1.0)) * float(tier["contact"])
	if bool(tier["duck_only"]):
		# Decision 2: below the movement difficulty, a sweep never asks for more than a duck.
		if wave.has("squat_depth"):
			out["squat_depth"] = minf(float(wave["squat_depth"]), DUCK_DEPTH)
	else:
		out["squat_depth"] = maxf(float(wave.get("squat_depth", SQUAT_DEPTH)), SQUAT_DEPTH)
	if bool(tier["squats"]):
		var pool: Array = out.get("pool", [])
		if not pool.is_empty() and not pool.has("sweep"):
			pool.append("sweep")
		out["sweep_min_gap"] = float(tier.get("sweep_min_gap", 0.0))
	return out
