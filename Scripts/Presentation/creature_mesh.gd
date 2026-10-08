class_name CreatureMesh
extends RefCounted

## Builds each phantom creature as one mesh, so one phantom costs one draw call.
## Meshes are built once per shape and shared by every phantom that uses it.
## What each vertex does (fade, solidity, glow, sway, flap) is baked for creature.gdshader.
## Local +Z is the face that travels toward the player. +X is the player's right.

static var _cache: Dictionary = {}

var _st := SurfaceTool.new()
var _style: Dictionary = {}

## How many body forms each species comes in. Every form keeps its species' cue: the
## Angler's lure, the Carapace's two crystal claws, the Spearfin's bill.
const FORMS := 3
const FORM_NAMES := {
	"angler": ["Lantern", "Gulper", "Thornback"],
	"carapace": ["Crab", "Horseshoe", "Mantis"],
	"spearfin": ["Needle", "Sailfish", "Ribbon"],
}
const LANTERN_BODY := [[0, -0.62], [0.06, -0.5], [0.15, -0.3], [0.25, -0.08], [0.29, 0.08], [0.28, 0.2], [0.22, 0.31], [0.12, 0.39], [0, 0.42]]
const NEEDLE_BODY := [[0, -0.52], [0.03, -0.42], [0.07, -0.22], [0.095, -0.04], [0.09, 0.09], [0.065, 0.2], [0.03, 0.27], [0, 0.3]]

## The Angler (yellow and blue). Its lure is the resonance point, so the stalk is
## built to reach wherever the sweet spot sits: out to the side, under the chin, or in front.
## Forms: 0 Lantern (round), 1 Gulper (long, huge jaw, whip tail), 2 Thornback (squat, spined).
static func angler(lure: Vector3, form: int = 0) -> ArrayMesh:
	var key := "angler%d:%s" % [form, lure.snapped(Vector3.ONE * 0.01)]
	if not _cache.has(key):
		_cache[key] = _build_angler(lure, form)
	return _cache[key]

## The Carapace (green). Two crystal claws held forward, one per hand.
## Forms: 0 Crab, 1 Horseshoe (dome shell, tail spike), 2 Mantis (upright, raptor arms).
static func carapace(form: int = 0) -> ArrayMesh:
	var key := "carapace%d" % form
	if not _cache.has(key):
		_cache[key] = _build_carapace(form)
	return _cache[key]

## The Spearfin (pink). A billed fish built to charge.
## Forms: 0 Needle, 1 Sailfish (huge sail, long bill), 2 Ribbon (long eel with a frilled fin).
static func spearfin(form: int = 0) -> ArrayMesh:
	var key := "spearfin%d" % form
	if not _cache.has(key):
		_cache[key] = _build_spearfin(form)
	return _cache[key]

## The Drifter (the unaligned phantom). A jellyfish trailing tentacles.
static func drifter() -> ArrayMesh:
	if not _cache.has("drifter"):
		_cache["drifter"] = _build_drifter()
	return _cache["drifter"]

## Builds every shape up front, so the first spawn of each kind does not hitch on Quest.
static func prewarm() -> void:
	drifter()
	for form in FORMS:
		carapace(form)
		spearfin(form)
		for spot in ResonancePhantom.lure_spots():
			angler(spot, form)

static func _build_angler(lure: Vector3, form: int) -> ArrayMesh:
	var b := CreatureMesh.new()
	var along_z := _turn(Vector3(PI * 0.5, 0.0, 0.0))
	match form:
		1:
			# Gulper: a long eel body behind an enormous jaw, ending in a whip.
			b.style({"fade_z": Vector2(-0.35, -0.95), "sway_z": Vector3(0.05, -0.95, 0.12)})
			b.lathe(_profile([[0, -0.95], [0.04, -0.8], [0.09, -0.55], [0.15, -0.28], [0.22, -0.02], [0.27, 0.16], [0.26, 0.29], [0.2, 0.37], [0.1, 0.42], [0, 0.44]]), 22, along_z, Vector3(0.9, 1.0, 0.9))
			b._maw(Vector3(0.0, -0.06, 0.37), 0.2, Vector3(1.1, 0.35, 0.8), 9, 1.25, Vector2(0.014, 0.075))
			b._eyes([[0.08, 0.18, 0.36, 0.016]])
			b._pectorals(0.17, Vector3(0.21, -0.05, 0.02))
			b.style({"solid": 0.4, "fade_u": Vector2(0.0, 1.0), "sway_u": 0.16, "lift_u": 0.02})
			b.tube([Vector3(0.0, 0.0, -0.9), Vector3(0.0, 0.03, -1.15), Vector3(0.0, -0.02, -1.4), Vector3(0.0, 0.04, -1.6)], 0.012, 0.002, 4, 14)
			for f in [[-0.08, -0.17, 0.12], [0.08, -0.17, 0.12]]:
				b._filament(Vector3(f[0], f[1], f[2]))
		2:
			# Thornback: squat and armored, spines down its back and out of its cheeks.
			var stretch := Vector3(1.22, 0.92, 0.76)
			b.style({"fade_z": Vector2(-0.12, -0.6), "sway_z": Vector3(0.1, -0.6, 0.06)})
			b.lathe(_profile(LANTERN_BODY), 22, along_z, stretch)
			b._maw(Vector3(0.0, -0.06, 0.34), 0.19, Vector3(1.15, 0.35, 0.5), 5, 0.95, Vector2(0.018, 0.07))
			b._eyes([[0.12, 0.13, 0.31, 0.022], [0.2, 0.06, 0.27, 0.016]])
			b.style({"solid": 0.85, "sway_z": Vector3(0.1, -0.6, 0.06)})
			for i in 6:
				var z := 0.2 - float(i) * 0.12
				var top := _radius_at(LANTERN_BODY, z / stretch.y) * stretch.z
				b.lathe(_cone(0.028, 0.14 - float(i) * 0.016), 5, _turn(Vector3(-0.55, 0.0, 0.0), Vector3(0.0, top - 0.01, z)))
			for s in [-1.0, 1.0]:
				for cheek in [[0.0, 0.2, 0.12], [-0.08, 0.1, 0.09]]:
					b.lathe(_cone(0.022, cheek[2]), 5, _turn(Vector3(0.0, s * 0.6, -s * PI * 0.5), Vector3(s * 0.31, cheek[0], cheek[1])))
			b._pectorals(0.24, Vector3(0.28, -0.05, 0.04))
			b.style({"solid": 0.15, "fade_u": Vector2(0.2, 1.5), "sway_z": Vector3(0.1, -0.6, 0.06)})
			b.fan(0.34, -0.75, 1.5, 8, _turn(Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, 0.0, -0.52)))
			for f in [[-0.1, -0.16, 0.06], [0.1, -0.16, 0.06]]:
				b._filament(Vector3(f[0], f[1], f[2]))
		_:
			# Lantern: a round head forward, a tail that frays and sways behind.
			b.style({"fade_z": Vector2(-0.12, -0.62), "sway_z": Vector3(0.1, -0.62, 0.08)})
			b.lathe(_profile(LANTERN_BODY), 22, along_z, Vector3(1.0, 1.0, 0.88))
			b._maw(Vector3(0.0, -0.07, 0.36), 0.17, Vector3(1.0, 0.35, 0.55), 7, 1.05, Vector2(0.012, 0.05))
			b._eyes([[0.09, 0.15, 0.33, 0.024], [0.17, 0.08, 0.28, 0.018], [0.045, 0.22, 0.28, 0.014]])
			b._pectorals(0.26, Vector3(0.22, -0.04, 0.04))
			b.style({"solid": 0.1, "fade_u": Vector2(0.2, 1.5), "sway_z": Vector3(0.1, -0.62, 0.08)})
			b.fan(0.3, -0.6, 1.2, 8, _turn(Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, 0.0, -0.55)))
			for f in [[-0.1, -0.18, 0.1], [0.1, -0.18, 0.1], [0.0, -0.22, -0.08], [-0.06, -0.16, -0.26], [0.06, -0.16, -0.26]]:
				b._filament(Vector3(f[0], f[1], f[2]))
	# The lure stalk. The glowing orb itself is the SweetSpotVisual node.
	b.style({"solid": 0.6, "glow": 0.25})
	b.tube(_lure_path(lure), 0.011, 0.007, 5, 12)
	return b._commit()

static func _lure_path(lure: Vector3) -> Array:
	var end := lure + Vector3(0.0, 0.05, 0.0)
	if lure.y < -0.2:
		# Uppercut: a barbel hanging from the chin.
		return [Vector3(0.0, -0.15, 0.3), Vector3(lure.x * 0.5, -0.24, 0.28), end]
	var crown := Vector3(0.0, 0.24, 0.16)
	return [crown, Vector3(lure.x * 0.3, 0.44, (0.16 + lure.z) * 0.5), Vector3(lure.x * 0.85, maxf(lure.y + 0.28, 0.3), lure.z * 0.95), end]

static func _build_carapace(form: int) -> ArrayMesh:
	var b := CreatureMesh.new()
	match form:
		1:
			# Horseshoe: a smooth dome shell, claws reaching out from under its rim, a tail spike.
			b.style({"solid": 0.35})
			b.lathe(_profile([[0, -0.06], [0.3, -0.07], [0.4, -0.03], [0.39, 0.06], [0.3, 0.15], [0.16, 0.21], [0, 0.22]]), 20, Transform3D.IDENTITY, Vector3(1.0, 1.0, 1.25))
			b.style({"solid": 0.8})
			for ridge in [[0.3, 0.06], [0.12, 0.08], [-0.08, 0.07], [-0.26, 0.05]]:
				b.lathe(_cone(0.025, ridge[1]), 5, _turn(Vector3(-0.4, 0.0, 0.0), Vector3(0.0, 0.2 - absf(ridge[0]) * 0.18, ridge[0])))
			b._eyes([[0.15, 0.16, 0.24, 0.022], [0.05, 0.21, 0.06, 0.012]])
			b.style({"solid": 0.8, "sway_z": Vector3(-0.3, -1.1, 0.08)})
			b.lathe(_cone(0.045, 0.7), 6, _turn(Vector3(-1.45, 0.0, 0.0), Vector3(0.0, 0.0, -0.42)))
			for s in [-1.0, 1.0]:
				b.style({"solid": 0.5})
				b.tube([Vector3(s * 0.22, -0.06, 0.25), Vector3(s * 0.32, -0.04, 0.4), Vector3(s * 0.32, 0.0, 0.48)], 0.032, 0.028, 6, 8)
				b._claw(s, Vector3(s * 0.32, 0.02, 0.56))
			for i in 6:
				b._leg(-1.0 if i < 3 else 1.0, Vector3(0.0, -0.08, 0.12 - float(i % 3) * 0.14), 0.22, 0.75)
		2:
			# Mantis: upright, a segmented thorax, a wide head with big eyes, raptor arms.
			b.style({"solid": 0.2, "fade_u": Vector2(0.4, 1.1), "sway_u": 0.05})
			b.tube([Vector3(0.0, -0.05, -0.05), Vector3(0.0, -0.1, -0.25), Vector3(0.0, -0.2, -0.45), Vector3(0.0, -0.32, -0.62)], 0.13, 0.03, 8, 10)
			b.style({"solid": 0.3})
			b.lathe(_sphere(0.13, 7), 12, _turn(Vector3.ZERO, Vector3(0.0, 0.02, 0.05)), Vector3(1.0, 1.5, 1.0))
			b.lathe(_sphere(0.09, 6), 12, _turn(Vector3(0.35, 0.0, 0.0), Vector3(0.0, 0.24, 0.12)), Vector3(1.0, 1.3, 1.0))
			b.lathe(_sphere(0.1, 6), 14, _turn(Vector3.ZERO, Vector3(0.0, 0.4, 0.2)), Vector3(1.5, 0.85, 0.9))
			b._eyes([[0.13, 0.42, 0.22, 0.035], [0.05, 0.47, 0.27, 0.014]])
			b.style({"solid": 0.5, "fade_u": Vector2(0.3, 1.0)})
			for s in [-1.0, 1.0]:
				b.tube([Vector3(s * 0.04, 0.47, 0.25), Vector3(s * 0.1, 0.62, 0.35), Vector3(s * 0.2, 0.66, 0.3)], 0.006, 0.002, 4, 8)
			for s in [-1.0, 1.0]:
				b.style({"solid": 0.5})
				b.tube([Vector3(s * 0.1, 0.22, 0.15), Vector3(s * 0.26, 0.32, 0.3), Vector3(s * 0.33, 0.18, 0.42)], 0.03, 0.025, 6, 8)
				b._claw(s, Vector3(s * 0.34, 0.12, 0.5))
			for i in 4:
				b._leg(-1.0 if i < 2 else 1.0, Vector3(0.0, -0.05, 0.02 - float(i % 2) * 0.14), 0.1, 1.15)
		_:
			# Crab: a broad, low dome with spines, eyes on stalks.
			b.style({"solid": 0.3})
			b.lathe(_profile([[0, -0.2], [0.24, -0.17], [0.36, -0.06], [0.38, 0.03], [0.33, 0.14], [0.21, 0.23], [0, 0.26]]), 20, Transform3D.IDENTITY, Vector3(1.2, 1.0, 0.95))
			b.style({"solid": 0.8})
			for spine in [[0.0, 0.24, 0.0, 0.13], [0.0, 0.22, -0.17, 0.1], [0.0, 0.23, 0.15, 0.09], [-0.27, 0.15, -0.04, 0.08], [0.27, 0.15, -0.04, 0.08]]:
				b.lathe(_cone(0.035, spine[3]), 5, _turn(Vector3(-0.35, 0.0, -spine[0] * 1.4), Vector3(spine[0], spine[1], spine[2])))
			b.style({"solid": 0.5})
			for s in [-1.0, 1.0]:
				b.tube([Vector3(s * 0.08, 0.14, 0.3), Vector3(s * 0.1, 0.24, 0.33), Vector3(s * 0.13, 0.33, 0.34)], 0.011, 0.008, 5, 6)
			b._eyes([[0.13, 0.35, 0.34, 0.026], [0.05, 0.09, 0.36, 0.012]])
			b.style({"solid": 1.0, "glow": 1.0})
			b.lathe(_sphere(0.012, 4), 6, _turn(Vector3.ZERO, Vector3(0.0, 0.09, 0.36)))
			for s in [-1.0, 1.0]:
				b.style({"solid": 0.5})
				b.tube([Vector3(s * 0.32, 0.0, 0.1), Vector3(s * 0.5, 0.04, 0.22), Vector3(s * 0.38, 0.05, 0.38)], 0.035, 0.03, 6, 8)
				b._claw(s, Vector3(s * 0.36, 0.05, 0.44))
			for i in 6:
				b._leg(-1.0 if i < 3 else 1.0, Vector3(0.0, -0.1, 0.12 - float(i % 3) * 0.14), 0.3, 1.0)
	return b._commit()

static func _build_spearfin(form: int) -> ArrayMesh:
	var b := CreatureMesh.new()
	var along_z := _turn(Vector3(PI * 0.5, 0.0, 0.0))
	match form:
		1:
			# Sailfish: heavier, with a towering sail and a longer bill.
			b.style({"fade_z": Vector2(-0.12, -0.62), "sway_z": Vector3(0.0, -0.62, 0.06)})
			b.lathe(_profile(NEEDLE_BODY), 16, along_z, Vector3(0.95, 1.2, 1.3))
			b._bill(0.022, 0.62, 0.33)
			b.style({"solid": 0.3, "glow": 0.18, "fade_u": Vector2(0.4, 1.3)})
			b.fan(0.5, 0.05, 1.35, 10, _turn(Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, 0.09, 0.2)))
			b._tail(0.36, -0.55, Vector3(0.0, -0.62, 0.06))
			b._spear_pectorals(0.2, 0.09)
			b._spear_eyes(0.07, 0.24, 0.34)
		2:
			# Ribbon: a long eel that undulates, frilled above and below.
			var sway := Vector3(0.15, -0.95, 0.15)
			b.style({"fade_z": Vector2(-0.45, -0.95), "sway_z": sway})
			b.lathe(_profile([[0, -0.95], [0.022, -0.8], [0.045, -0.45], [0.062, -0.1], [0.06, 0.1], [0.042, 0.22], [0.015, 0.29], [0, 0.31]]), 14, along_z, Vector3(0.75, 1.0, 1.15))
			b._bill(0.016, 0.36, 0.28)
			b.style({"solid": 0.3, "glow": 0.18, "fade_u": Vector2(0.3, 1.3), "sway_z": sway})
			for i in 8:
				var z := 0.15 - float(i) * 0.12
				var size := 0.08 - float(i) * 0.005
				b.fan(size, 0.3, 1.2, 4, _turn(Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, 0.05, z)))
				b.fan(size * 0.7, -1.5, 1.2, 4, _turn(Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, -0.05, z)))
			b._spear_pectorals(0.1, 0.05)
			b._spear_eyes(0.04, 0.18, 0.28)
		_:
			# Needle: slim, taller than wide, a sail fin and a forked tail.
			b.style({"fade_z": Vector2(-0.1, -0.52), "sway_z": Vector3(0.0, -0.52, 0.06)})
			b.lathe(_profile(NEEDLE_BODY), 16, along_z, Vector3(0.8, 1.0, 1.15))
			b._bill(0.02, 0.46, 0.27)
			b.style({"solid": 0.25, "glow": 0.14, "fade_u": Vector2(0.3, 1.4)})
			b.fan(0.3, 0.2, 1.0, 8, _turn(Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, 0.07, 0.1)))
			b._tail(0.3, -0.45, Vector3(0.0, -0.52, 0.06))
			b._spear_pectorals(0.16, 0.07)
			b._spear_eyes(0.055, 0.2, 0.29)
	return b._commit()

static func _build_drifter() -> ArrayMesh:
	var b := CreatureMesh.new()
	# Bell, open underneath.
	b.style({"solid": 0.1})
	b.lathe(_profile([[0.2, -0.08], [0.26, -0.02], [0.27, 0.06], [0.22, 0.16], [0.12, 0.22], [0, 0.24]]), 20, Transform3D.IDENTITY)
	b.style({"solid": 1.0, "glow": 0.6})
	b.lathe(_sphere(0.07, 6), 10, _turn(Vector3.ZERO, Vector3(0.0, 0.08, 0.0)))
	# Tentacles trailing back as it swims.
	b.style({"fade_u": Vector2(0.1, 1.0), "sway_u": 0.09, "lift_u": 0.02})
	for i in 8:
		var a := TAU * float(i) / 8.0
		var rim := Vector3(cos(a) * 0.2, -0.06, sin(a) * 0.2)
		b.tube([rim, rim + Vector3(0.0, -0.2, -0.08), rim * Vector3(0.7, 1.0, 0.7) + Vector3(0.0, -0.42, -0.25), rim * Vector3(0.5, 1.0, 0.5) + Vector3(0.0, -0.6, -0.45)], 0.01, 0.003, 4, 10)
	return b._commit()

# --- Body parts shared between forms --------------------------------------------

## A nearly black maw on the lower front, rimmed with white-hot teeth.
func _maw(center: Vector3, radius: float, stretch: Vector3, teeth: int, spread: float, tooth: Vector2) -> void:
	style({"solid": 1.0, "bright": 0.06})
	lathe(_sphere(radius, 8), 16, _turn(Vector3(PI * 0.5, 0.0, 0.0), center), stretch)
	style({"solid": 1.0, "glow": 0.85})
	var half_width := radius * stretch.x * 0.88
	var half_height := radius * stretch.z * 0.8
	for i in teeth:
		var a := lerpf(-spread, spread, float(i) / float(maxi(teeth - 1, 1)))
		for up in [1.0, -1.0]:
			var root := center + Vector3(sin(a) * half_width, up * cos(a) * half_height, radius * stretch.y * 0.9)
			lathe(_cone(tooth.x, tooth.y), 5, _turn(Vector3(-up * 0.3, 0.0, PI if up > 0.0 else 0.0), root))

## Mirrored pairs of white-hot eyes: [x, y, z, radius] each.
func _eyes(pairs: Array) -> void:
	style({"solid": 1.0, "glow": 1.0})
	for eye in pairs:
		for s in [-1.0, 1.0]:
			lathe(_sphere(eye[3], 5), 8, _turn(Vector3.ZERO, Vector3(s * eye[0], eye[1], eye[2])))

## Flapping side fins, hinged at `root.x` out from the center.
func _pectorals(radius: float, root: Vector3) -> void:
	style({"solid": 0.2, "glow": 0.1, "fade_u": Vector2(0.2, 1.4), "flap_axis": Vector3.RIGHT, "flap_abs": true, "flap_root": root.x, "flap_amp": 0.3})
	for s in [-1.0, 1.0]:
		fan(radius, -0.1, 1.0, 8, _mirror(s, Vector3(-PI * 0.5, 0.0, 0.0), Vector3(s * root.x, root.y, root.z)))

## A fine filament trailing down and back from the belly.
func _filament(origin: Vector3) -> void:
	style({"fade_u": Vector2(0.15, 1.0), "sway_u": 0.07, "lift_u": 0.03})
	tube([origin, origin + Vector3(origin.x * 0.5, -0.2, -0.12), origin + Vector3(origin.x * 0.8, -0.4, -0.32), origin + Vector3(origin.x, -0.55, -0.6)], 0.008, 0.002, 4, 10)

## One crystal claw: a hexagonal plate facing forward and two pincers that snap.
func _claw(side: float, at: Vector3) -> void:
	var claw := _turn(Vector3(0.0, -side * 0.35, 0.0), at)
	style({"solid": 1.0, "glow": 0.15})
	lathe(_profile([[0, -0.014], [0.15, -0.014], [0.15, 0.014], [0, 0.014]]), 6, claw * _turn(Vector3(PI * 0.5, 0.0, 0.0)))
	for up in [1.0, -1.0]:
		style({"solid": 1.0, "glow": 0.1, "flap_axis": Vector3.BACK, "flap_root": at.z + 0.02, "flap_amp": 0.35 * up})
		lathe(_cone(0.045, 0.24), 5, claw * _turn(Vector3(PI * 0.5 - up * 0.15, 0.0, 0.0), Vector3(0.0, up * 0.09, 0.01)))

## A jointed leg dangling from `hip`, mirrored to `side`, paddling as it swims.
func _leg(side: float, hip: Vector3, out: float, length: float) -> void:
	style({"solid": 0.3, "fade_u": Vector2(0.3, 1.1), "sway_u": 0.04, "lift_u": 0.04})
	var start := Vector3(side * out, hip.y, hip.z)
	tube([start, start + Vector3(side * 0.2, 0.1, -0.02) * length, start + Vector3(side * 0.3, -0.18, -0.06) * length, start + Vector3(side * 0.25, -0.45, -0.1) * length], 0.018, 0.006, 5, 10)

## The Spearfin's bill, from `root_z` forward.
func _bill(radius: float, length: float, root_z: float) -> void:
	style({"solid": 1.0, "glow": 0.3})
	lathe(_cone(radius, length), 6, _turn(Vector3(PI * 0.5, 0.0, 0.0), Vector3(0.0, 0.0, root_z)))

## A forked tail, swaying with the body.
func _tail(radius: float, at_z: float, sway: Vector3) -> void:
	style({"solid": 0.25, "glow": 0.14, "fade_u": Vector2(0.3, 1.4), "sway_z": sway})
	for lobe in [[0.25, 0.4], [-0.65, 0.4]]:
		fan(radius, lobe[0], lobe[1], 6, _turn(Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, 0.0, at_z)))

func _spear_pectorals(radius: float, root_x: float) -> void:
	style({"solid": 0.25, "glow": 0.14, "fade_u": Vector2(0.3, 1.4), "flap_axis": Vector3.RIGHT, "flap_abs": true, "flap_root": root_x, "flap_amp": 0.25})
	for s in [-1.0, 1.0]:
		fan(radius, 0.2, 0.7, 6, _mirror(s, Vector3(-PI * 0.5, 0.0, 0.0), Vector3(s * root_x, -0.03, 0.08)))

## Two small eyes, and the lock-on glow at the root of the bill.
func _spear_eyes(x: float, z: float, bill_root: float) -> void:
	style({"solid": 1.0, "glow": 1.0})
	for s in [-1.0, 1.0]:
		lathe(_sphere(0.016, 4), 6, _turn(Vector3.ZERO, Vector3(s * x, 0.035, z)))
	lathe(_sphere(0.03, 5), 8, _turn(Vector3.ZERO, Vector3(0.0, 0.0, bill_root + 0.02)))

## The radius of a lathe profile at height `h`, read between its points.
static func _radius_at(profile: Array, h: float) -> float:
	for i in profile.size() - 1:
		var a: Array = profile[i]
		var b: Array = profile[i + 1]
		if h >= float(a[1]) and h <= float(b[1]):
			return lerpf(float(a[0]), float(b[0]), inverse_lerp(float(a[1]), float(b[1]), h))
	return 0.0

# --- Building blocks -------------------------------------------------------

func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)

func _commit() -> ArrayMesh:
	_st.index()
	return _st.commit()

## Sets what the next parts do. Keys:
##   solid, glow, bright: straight into the vertex color.
##   fade_z (full, zero): opacity along local Z.  fade_u (full, zero): along the part.
##   sway_z (still_z, full_z, amount): sideways sway, growing toward the tail.
##   sway_u, lift_u: sway or lift growing along the part (tentacles, legs).
##   flap_axis, flap_root, flap_amp, flap_abs: up-down motion past a hinge.
func style(values: Dictionary) -> void:
	_style = values

## Surface of revolution around local Y. `profile` is (radius, height), bottom to top.
func lathe(profile: PackedVector2Array, segments: int, xform: Transform3D, stretch := Vector3.ONE) -> void:
	var rings: Array = []
	var count := profile.size()
	for i in count:
		var tangent := (profile[mini(i + 1, count - 1)] - profile[maxi(i - 1, 0)]).normalized()
		var outward := Vector2(tangent.y, -tangent.x)
		var ring: Array = []
		for j in segments + 1:
			var angle := TAU * float(j) / float(segments)
			var local := Vector3(cos(angle) * profile[i].x, profile[i].y, sin(angle) * profile[i].x) * stretch
			var local_normal := Vector3(cos(angle) * outward.x, outward.y, sin(angle) * outward.x) / stretch
			var uv := Vector2(float(j) / float(segments), float(i) / float(count - 1))
			ring.append([xform * local, (xform.basis * local_normal).normalized(), uv, uv.y])
		rings.append(ring)
	for i in count - 1:
		for j in segments:
			_quad(rings[i][j], rings[i + 1][j], rings[i + 1][j + 1], rings[i][j + 1])

## A tube along a smooth curve through `points`, tapering from r0 to r1.
func tube(points: Array, r0: float, r1: float, sides: int, steps: int) -> void:
	var spans := points.size() - 1
	var samples: Array[Vector3] = []
	for k in steps + 1:
		var f := float(k) / float(steps) * spans
		var i := mini(int(f), spans - 1)
		var p0: Vector3 = points[maxi(i - 1, 0)]
		var p3: Vector3 = points[mini(i + 2, spans)]
		samples.append((points[i] as Vector3).cubic_interpolate(points[i + 1], p0, p3, f - i))
	var rings: Array = []
	for k in samples.size():
		var tangent := (samples[mini(k + 1, steps)] - samples[maxi(k - 1, 0)]).normalized()
		var reference := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var side := reference.cross(tangent).normalized()
		var up := tangent.cross(side)
		var t := float(k) / float(steps)
		var radius := lerpf(r0, r1, t)
		var ring: Array = []
		for j in sides + 1:
			var angle := TAU * float(j) / float(sides)
			var normal := side * cos(angle) + up * sin(angle)
			ring.append([samples[k] + normal * radius, normal, Vector2(t, float(j) / float(sides)), t])
		rings.append(ring)
	for k in steps:
		for j in sides:
			_quad(rings[k][j], rings[k + 1][j], rings[k + 1][j + 1], rings[k][j + 1])

## A flat fin: a sector in the local XY plane, drawn on both sides.
func fan(radius: float, start: float, length: float, segments: int, xform: Transform3D) -> void:
	var normal := (xform.basis * Vector3.BACK).normalized()
	var center := xform * Vector3.ZERO
	for face: Vector3 in [normal, -normal]:
		var hub := [center, face, Vector2(0.5, 0.0), 0.0]
		for k in segments:
			var a0 := start + length * float(k) / float(segments)
			var a1 := start + length * float(k + 1) / float(segments)
			_tri(hub,
				[xform * (Vector3(cos(a0), sin(a0), 0.0) * radius), face, Vector2(float(k) / segments, 1.0), 1.0],
				[xform * (Vector3(cos(a1), sin(a1), 0.0) * radius), face, Vector2(float(k + 1) / segments, 1.0), 1.0])

func _quad(a: Array, b: Array, c: Array, d: Array) -> void:
	_tri(a, b, c)
	_tri(a, c, d)

## Each corner is [position, normal, uv, progress along the part].
## Godot draws clockwise triangles as front faces, so wind every triangle to face along its normals.
func _tri(a: Array, b: Array, c: Array) -> void:
	var face: Vector3 = (b[0] - a[0]).cross(c[0] - a[0])
	var wanted: Vector3 = a[1] + b[1] + c[1]
	if face.dot(wanted) > 0.0:
		var swap := b
		b = c
		c = swap
	for corner in [a, b, c]:
		_vertex(corner[0], corner[1], corner[2], corner[3])

func _vertex(p: Vector3, normal: Vector3, uv: Vector2, along: float) -> void:
	var opacity: float = _style.get("opacity", 1.0)
	if _style.has("fade_z"):
		var fz: Vector2 = _style["fade_z"]
		opacity *= _ramp(fz.y, fz.x, p.z)
	if _style.has("fade_u"):
		var fu: Vector2 = _style["fade_u"]
		opacity *= _ramp(fu.y, fu.x, along)
	var sway: float = float(_style.get("sway_u", 0.0)) * along
	if _style.has("sway_z"):
		var sz: Vector3 = _style["sway_z"]
		sway += sz.z * clampf(inverse_lerp(sz.x, sz.y, p.z), 0.0, 1.0)
	var lift: float = float(_style.get("lift_u", 0.0)) * along
	if _style.has("flap_axis"):
		var reach: float = p.dot(_style["flap_axis"])
		if _style.get("flap_abs", false):
			reach = absf(reach)
		lift += float(_style.get("flap_amp", 0.0)) * maxf(reach - float(_style.get("flap_root", 0.0)), 0.0)
	_st.set_color(Color(opacity, _style.get("solid", 0.0), _style.get("glow", 0.0), _style.get("bright", 1.0)))
	_st.set_uv2(Vector2(sway, lift))
	_st.set_uv(uv)
	_st.set_normal(normal)
	_st.add_vertex(p)

## 0 at `zero`, 1 at `full`, smooth in between. Works in either direction.
static func _ramp(zero: float, full: float, x: float) -> float:
	var s := clampf((x - zero) / (full - zero), 0.0, 1.0)
	return s * s * (3.0 - 2.0 * s)

static func _turn(euler: Vector3, origin := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(euler), origin)

## The same part on the other side: mirrored across X when `side` is negative.
static func _mirror(side: float, euler: Vector3, origin: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(side, 1.0, 1.0)) * Basis.from_euler(euler), origin)

static func _profile(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p[0], p[1]))
	return out

static func _sphere(radius: float, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps + 1:
		var a := PI * float(i) / float(steps)
		out.append(Vector2(sin(a) * radius, -cos(a) * radius))
	return out

static func _cone(radius: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.0, 0.0), Vector2(radius, 0.0), Vector2(0.0, height)])
