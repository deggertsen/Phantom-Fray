class_name CreatureMesh
extends RefCounted

## Builds each phantom creature as one mesh, so one phantom costs one draw call.
## Meshes are built once per shape and shared by every phantom that uses it.
## What each vertex does (fade, solidity, glow, sway, flap) is baked for creature.gdshader.
## Local +Z is the face that travels toward the player. +X is the player's right.

static var _cache: Dictionary = {}

var _st := SurfaceTool.new()
var _style: Dictionary = {}

## The Angler (yellow and blue). Its lure is the resonance point, so the stalk is
## built to reach wherever the sweet spot sits: out to the side, under the chin, or in front.
static func angler(lure: Vector3) -> ArrayMesh:
	var key := "angler:%s" % lure.snapped(Vector3.ONE * 0.01)
	if not _cache.has(key):
		_cache[key] = _build_angler(lure)
	return _cache[key]

## The Carapace (green). Two crystal claws held forward, one per hand.
static func carapace() -> ArrayMesh:
	if not _cache.has("carapace"):
		_cache["carapace"] = _build_carapace()
	return _cache["carapace"]

## The Spearfin (pink). A needle-billed fish built to charge.
static func spearfin() -> ArrayMesh:
	if not _cache.has("spearfin"):
		_cache["spearfin"] = _build_spearfin()
	return _cache["spearfin"]

## The Drifter (the unaligned phantom). A jellyfish trailing tentacles.
static func drifter() -> ArrayMesh:
	if not _cache.has("drifter"):
		_cache["drifter"] = _build_drifter()
	return _cache["drifter"]

## Builds every shape up front, so the first spawn of each kind does not hitch on Quest.
static func prewarm() -> void:
	carapace()
	spearfin()
	drifter()
	for spot in ResonancePhantom.lure_spots():
		angler(spot)

static func _build_angler(lure: Vector3) -> ArrayMesh:
	var b := CreatureMesh.new()
	var along_z := _turn(Vector3(PI * 0.5, 0.0, 0.0))
	# Body: a round head forward, a tail that frays and sways behind.
	b.style({"fade_z": Vector2(-0.12, -0.62), "sway_z": Vector3(0.1, -0.62, 0.08)})
	b.lathe(_profile([[0, -0.62], [0.06, -0.5], [0.15, -0.3], [0.25, -0.08], [0.29, 0.08], [0.28, 0.2], [0.22, 0.31], [0.12, 0.39], [0, 0.42]]), 22, along_z, Vector3(1.0, 1.0, 0.88))
	# The maw: a nearly black hollow on the lower front.
	b.style({"solid": 1.0, "bright": 0.06})
	b.lathe(_sphere(0.17, 8), 16, _turn(Vector3(PI * 0.5, 0.0, 0.0), Vector3(0.0, -0.07, 0.36)), Vector3(1.0, 0.35, 0.55))
	# Teeth: upper row hangs down, lower row points up.
	b.style({"solid": 1.0, "glow": 0.85})
	for i in 7:
		var a := lerpf(-1.05, 1.05, float(i) / 6.0)
		for up in [1.0, -1.0]:
			var root := Vector3(sin(a) * 0.15, -0.07 + up * cos(a) * 0.075, 0.41)
			b.lathe(_cone(0.012, 0.05), 5, _turn(Vector3(-up * 0.3, 0.0, PI if up > 0.0 else 0.0), root))
	# Eyes: three pairs, small and white-hot.
	b.style({"solid": 1.0, "glow": 1.0})
	for eye in [[0.09, 0.15, 0.33, 0.024], [0.17, 0.08, 0.28, 0.018], [0.045, 0.22, 0.28, 0.014]]:
		for s in [-1.0, 1.0]:
			b.lathe(_sphere(eye[3], 5), 8, _turn(Vector3.ZERO, Vector3(s * eye[0], eye[1], eye[2])))
	# Pectoral fins, flapping.
	b.style({"solid": 0.15, "fade_u": Vector2(0.2, 1.4), "flap_axis": Vector3.RIGHT, "flap_abs": true, "flap_root": 0.22, "flap_amp": 0.3})
	for s in [-1.0, 1.0]:
		b.fan(0.26, -0.1, 1.0, 8, _mirror(s, Vector3(-PI * 0.5, 0.0, 0.0), Vector3(s * 0.22, -0.04, 0.04)))
	# Tail fin, swaying with the tail.
	b.style({"solid": 0.1, "fade_u": Vector2(0.2, 1.5), "sway_z": Vector3(0.1, -0.62, 0.08)})
	b.fan(0.3, -0.6, 1.2, 8, _turn(Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, 0.0, -0.55)))
	# Filaments trailing from the belly.
	b.style({"fade_u": Vector2(0.15, 1.0), "sway_u": 0.07, "lift_u": 0.03})
	for f in [[-0.1, -0.18, 0.1], [0.1, -0.18, 0.1], [0.0, -0.22, -0.08], [-0.06, -0.16, -0.26], [0.06, -0.16, -0.26]]:
		var o := Vector3(f[0], f[1], f[2])
		b.tube([o, o + Vector3(f[0] * 0.5, -0.2, -0.12), o + Vector3(f[0] * 0.8, -0.4, -0.32), o + Vector3(f[0], -0.55, -0.6)], 0.008, 0.002, 4, 10)
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

static func _build_carapace() -> ArrayMesh:
	var b := CreatureMesh.new()
	# Shell: a broad, low dome.
	b.style({"solid": 0.3})
	b.lathe(_profile([[0, -0.2], [0.24, -0.17], [0.36, -0.06], [0.38, 0.03], [0.33, 0.14], [0.21, 0.23], [0, 0.26]]), 20, Transform3D.IDENTITY, Vector3(1.2, 1.0, 0.95))
	# Dorsal spines.
	b.style({"solid": 0.8})
	for spine in [[0.0, 0.24, 0.0, 0.13], [0.0, 0.22, -0.17, 0.1], [0.0, 0.23, 0.15, 0.09], [-0.27, 0.15, -0.04, 0.08], [0.27, 0.15, -0.04, 0.08]]:
		b.lathe(_cone(0.035, spine[3]), 5, _turn(Vector3(-0.35, 0.0, -spine[0] * 1.4), Vector3(spine[0], spine[1], spine[2])))
	# Eyes on stalks, and a row of small ones.
	b.style({"solid": 0.5})
	for s in [-1.0, 1.0]:
		b.tube([Vector3(s * 0.08, 0.14, 0.3), Vector3(s * 0.1, 0.24, 0.33), Vector3(s * 0.13, 0.33, 0.34)], 0.011, 0.008, 5, 6)
	b.style({"solid": 1.0, "glow": 1.0})
	for s in [-1.0, 1.0]:
		b.lathe(_sphere(0.026, 5), 8, _turn(Vector3.ZERO, Vector3(s * 0.13, 0.35, 0.34)))
	for x in [-0.05, 0.0, 0.05]:
		b.lathe(_sphere(0.012, 4), 6, _turn(Vector3.ZERO, Vector3(x, 0.09, 0.36)))
	# Claws: an arm, a hexagonal crystal plate, and two pincers that snap.
	for s in [-1.0, 1.0]:
		b.style({"solid": 0.5})
		b.tube([Vector3(s * 0.32, 0.0, 0.1), Vector3(s * 0.5, 0.04, 0.22), Vector3(s * 0.38, 0.05, 0.38)], 0.035, 0.03, 6, 8)
		var claw := _turn(Vector3(0.0, -s * 0.35, 0.0), Vector3(s * 0.36, 0.05, 0.44))
		b.style({"solid": 1.0, "glow": 0.15})
		b.lathe(_profile([[0, -0.014], [0.15, -0.014], [0.15, 0.014], [0, 0.014]]), 6, claw * _turn(Vector3(PI * 0.5, 0.0, 0.0)))
		for up in [1.0, -1.0]:
			b.style({"solid": 1.0, "glow": 0.1, "flap_axis": Vector3.BACK, "flap_root": 0.46, "flap_amp": 0.35 * up})
			b.lathe(_cone(0.045, 0.24), 5, claw * _turn(Vector3(PI * 0.5 - up * 0.15, 0.0, 0.0), Vector3(0.0, up * 0.09, 0.01)))
	# Six legs, dangling and paddling.
	b.style({"solid": 0.3, "fade_u": Vector2(0.3, 1.1), "sway_u": 0.04, "lift_u": 0.04})
	for i in 6:
		var s := -1.0 if i < 3 else 1.0
		var z := 0.12 - float(i % 3) * 0.14
		b.tube([Vector3(s * 0.3, -0.1, z), Vector3(s * 0.5, 0.0, z - 0.02), Vector3(s * 0.6, -0.28, z - 0.06), Vector3(s * 0.55, -0.55, z - 0.1)], 0.018, 0.006, 5, 10)
	return b._commit()

static func _build_spearfin() -> ArrayMesh:
	var b := CreatureMesh.new()
	var along_z := _turn(Vector3(PI * 0.5, 0.0, 0.0))
	# Body: slim, taller than wide.
	b.style({"fade_z": Vector2(-0.1, -0.52), "sway_z": Vector3(0.0, -0.52, 0.06)})
	b.lathe(_profile([[0, -0.52], [0.03, -0.42], [0.07, -0.22], [0.095, -0.04], [0.09, 0.09], [0.065, 0.2], [0.03, 0.27], [0, 0.3]]), 16, along_z, Vector3(0.8, 1.0, 1.15))
	# The bill.
	b.style({"solid": 1.0, "glow": 0.3})
	b.lathe(_cone(0.02, 0.46), 6, _turn(Vector3(PI * 0.5, 0.0, 0.0), Vector3(0.0, 0.0, 0.27)))
	# Sail fin on the back.
	b.style({"solid": 0.2, "fade_u": Vector2(0.2, 1.4)})
	b.fan(0.3, 0.2, 1.0, 8, _turn(Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, 0.07, 0.1)))
	# Forked tail.
	b.style({"solid": 0.2, "fade_u": Vector2(0.2, 1.4), "sway_z": Vector3(0.0, -0.52, 0.06)})
	for lobe in [[0.25, 0.4], [-0.65, 0.4]]:
		b.fan(0.3, lobe[0], lobe[1], 6, _turn(Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, 0.0, -0.45)))
	# Pectoral fins.
	b.style({"solid": 0.2, "fade_u": Vector2(0.2, 1.4), "flap_axis": Vector3.RIGHT, "flap_abs": true, "flap_root": 0.07, "flap_amp": 0.25})
	for s in [-1.0, 1.0]:
		b.fan(0.16, 0.2, 0.7, 6, _mirror(s, Vector3(-PI * 0.5, 0.0, 0.0), Vector3(s * 0.07, -0.03, 0.08)))
	# Eyes, and the lock-on glow at the root of the bill.
	b.style({"solid": 1.0, "glow": 1.0})
	for s in [-1.0, 1.0]:
		b.lathe(_sphere(0.016, 4), 6, _turn(Vector3.ZERO, Vector3(s * 0.055, 0.035, 0.2)))
	b.lathe(_sphere(0.03, 5), 8, _turn(Vector3.ZERO, Vector3(0.0, 0.0, 0.29)))
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
