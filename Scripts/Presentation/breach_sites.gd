class_name BreachSites
extends RefCounted

## The places a mission can play. Every site keeps the RSF deployment pad, the pylon ring, and
## the hex floor with its corruption veins exactly as they are; a site changes only the sky, the
## light and fog, the ground past the pad, and one merged set-dressing mesh (SiteDressing).
## Sites carry no in-world place names, so one site can stand in for many places on the map.
##
## A world-map district names its site through DISTRICTS. ArenaPresentation.apply_site takes
## either kind of id; anything unknown plays at the Dead City.

const DEFAULT := "dead_city"

## Each site's look. Sky colours feed breach_sky.gdshader, ground colours arena_floor.gdshader.
## `outer_from` is where the site's own ground takes over from the pad's concrete, in metres.
## Ground patterns are 0 (off) to 1: `stripes` (period `stripe_period`, along world X),
## `shimmer` (water), `crust` (salt polygons), `pitch` (painted football pitch lines).
const SITES := {
	"dead_city": {
		"sky_horizon": Color(0.09, 0.055, 0.16), "sky_zenith": Color(0.008, 0.01, 0.03), "sky_breach": Color(0.45, 0.15, 0.9),
		"fog": Color(0.09, 0.055, 0.16), "fog_density": 0.012,
		"ambient": Color(0.3, 0.26, 0.48), "ambient_energy": 0.55,
		"sun": Color(0.62, 0.55, 1.0), "sun_energy": 0.45,
		"outer": Color(0.022, 0.026, 0.04), "outer_from": 9.0,
	},
	"harbor": {
		"sky_horizon": Color(0.05, 0.09, 0.13), "sky_zenith": Color(0.005, 0.01, 0.02), "sky_breach": Color(0.3, 0.2, 0.75),
		"fog": Color(0.05, 0.085, 0.115), "fog_density": 0.011,
		"ambient": Color(0.24, 0.32, 0.44), "ambient_energy": 0.55,
		"sun": Color(0.6, 0.72, 0.95), "sun_energy": 0.4,
		"outer": Color(0.012, 0.032, 0.048), "outer_from": 9.5, "shimmer": 1.0,
	},
	"summit": {
		"sky_horizon": Color(0.06, 0.08, 0.14), "sky_zenith": Color(0.004, 0.008, 0.02), "sky_breach": Color(0.35, 0.2, 0.85),
		"fog": Color(0.06, 0.08, 0.13), "fog_density": 0.007,
		"ambient": Color(0.3, 0.34, 0.52), "ambient_energy": 0.6,
		"sun": Color(0.7, 0.76, 1.0), "sun_energy": 0.5,
		"outer": Color(0.065, 0.075, 0.1), "outer_from": 9.0,
	},
	"stadium": {
		"sky_horizon": Color(0.07, 0.05, 0.12), "sky_zenith": Color(0.006, 0.008, 0.025), "sky_breach": Color(0.45, 0.15, 0.9),
		"fog": Color(0.07, 0.06, 0.11), "fog_density": 0.008,
		"ambient": Color(0.36, 0.36, 0.5), "ambient_energy": 0.6,
		"sun": Color(0.85, 0.88, 1.0), "sun_energy": 0.55,
		"outer": Color(0.012, 0.028, 0.022), "outer_from": 9.0, "stripes": 1.0, "stripe_period": 5.0, "pitch": 1.0,
	},
	"salt_flat": {
		"sky_horizon": Color(0.15, 0.1, 0.12), "sky_zenith": Color(0.01, 0.012, 0.03), "sky_breach": Color(0.4, 0.2, 0.75),
		"fog": Color(0.13, 0.09, 0.12), "fog_density": 0.007,
		"ambient": Color(0.4, 0.32, 0.42), "ambient_energy": 0.6,
		"sun": Color(0.9, 0.66, 0.6), "sun_energy": 0.45,
		"outer": Color(0.06, 0.052, 0.068), "outer_from": 9.0, "crust": 1.0,
	},
	"small_town": {
		"sky_horizon": Color(0.08, 0.06, 0.15), "sky_zenith": Color(0.006, 0.008, 0.025), "sky_breach": Color(0.45, 0.15, 0.9),
		"fog": Color(0.08, 0.06, 0.14), "fog_density": 0.009,
		"ambient": Color(0.3, 0.28, 0.46), "ambient_energy": 0.55,
		"sun": Color(0.62, 0.58, 1.0), "sun_energy": 0.45,
		"outer": Color(0.018, 0.02, 0.028), "outer_from": 9.0,
	},
	"farmland": {
		"sky_horizon": Color(0.08, 0.09, 0.16), "sky_zenith": Color(0.005, 0.008, 0.024), "sky_breach": Color(0.4, 0.18, 0.85),
		"fog": Color(0.07, 0.08, 0.13), "fog_density": 0.008,
		"ambient": Color(0.28, 0.3, 0.46), "ambient_energy": 0.55,
		"sun": Color(0.7, 0.75, 1.0), "sun_energy": 0.5,
		"outer": Color(0.026, 0.024, 0.022), "outer_from": 9.0, "stripes": 0.6, "stripe_period": 1.2,
	},
}

## World-map district -> the site it plays at. Districts without a site of their own borrow the
## closest one: industry and city districts the Dead City, water districts the harbor, high
## rocky ground the summit, the airfield the open salt flat, the old town and campus the town.
const DISTRICTS := {
	"harbor": "harbor",
	"docks": "harbor",
	"reservoir": "harbor",
	"riverside": "harbor",
	"stadium": "stadium",
	"old_town": "small_town",
	"university": "small_town",
	"airport": "salt_flat",
	"bluffs": "summit",
	"quarry": "summit",
	"rail_yards": "dead_city",
	"junction": "dead_city",
	"civic_ring": "dead_city",
	"foundry": "dead_city",
	"northgate": "dead_city",
	"eastbank": "dead_city",
}

## Every id apply_site accepts: the sites and the world-map districts, sorted.
static func ids() -> PackedStringArray:
	var all := {}
	for id in SITES:
		all[id] = true
	for id in DISTRICTS:
		all[id] = true
	var sorted := PackedStringArray(all.keys())
	sorted.sort()
	return sorted

## The sites that have a look and dressing of their own.
static func site_ids() -> PackedStringArray:
	return PackedStringArray(SITES.keys())

## The site a site or district id plays at. Unknown ids play at the Dead City.
static func resolve(id: String) -> String:
	if SITES.has(id):
		return id
	return String(DISTRICTS.get(id, DEFAULT))

## A site's look, with every ground pattern filled in so callers never need defaults.
static func look(id: String) -> Dictionary:
	var result := {"stripes": 0.0, "stripe_period": 4.0, "shimmer": 0.0, "crust": 0.0, "pitch": 0.0}
	result.merge(SITES[resolve(id)], true)
	return result
