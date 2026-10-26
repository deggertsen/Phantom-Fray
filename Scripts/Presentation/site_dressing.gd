class_name SiteDressing
extends RefCounted

## The set dressing for each breach site, built from seeds so every visit looks the same.
## The rules every site keeps:
## - Nothing between waist height (1.5 m) and 20 m up stands inside 20 m: rifts open 10 to
##   16 m out at any bearing, and the pad, pylons and veins must read the same everywhere.
## - Dark, low-saturation surroundings, so blue, green, pink and yellow phantoms stand out.
## - Toward -Z (the front arc, where The Maw opens) the skyline stays low and broken, so the
##   burning sky there shows.
## - One merged mesh per site (SiteKit), no real lights, no shadows.

const SOLID := SiteKit.SOLID
const LIT := SiteKit.LIT

const CONCRETE := Color(0.05, 0.054, 0.068)
const STEEL := Color(0.04, 0.046, 0.062)
const DARK := Color(0.022, 0.024, 0.034)
const WARM_LAMP := Color(1.0, 0.68, 0.36)
const COOL_LAMP := Color(0.8, 0.9, 1.0)
const RSF_CYAN := Color(0.08, 0.6, 0.9)
const WARNING_RED := Color(0.9, 0.1, 0.1)

## The dressing for a site id from BreachSites. Unknown ids get the Dead City.
static func build(site_id: String) -> Node3D:
	match BreachSites.resolve(site_id):
		"harbor":
			return harbor()
		"summit":
			return summit()
		"stadium":
			return stadium()
		"salt_flat":
			return salt_flat()
		"small_town":
			return small_town()
		"farmland":
			return farmland()
	return dead_city()

## The original breach site: a ring of dead towers and broken concrete.
static func dead_city() -> Node3D:
	var root := Node3D.new()
	root.name = "DeadCitySite"
	root.add_child(BreachCity.city())
	root.add_child(BreachCity.rubble())
	return root

## A container port at low tide. The pad sits on the pier head; water from 9.5 m.
static func harbor() -> Node3D:
	var kit := SiteKit.new()
	var rng := _rng(21)
	# The pier runs out to sea ahead, low enough for rifts to hang over it.
	kit.box(SOLID, Vector3(0.0, 0.05, -30.0), Vector3(5.0, 0.3, 42.0), CONCRETE)
	for z in range(-14, -50, -6):
		for x in [-2.2, 2.2]:
			kit.cylinder(SOLID, Vector3(x, 0.0, z), 0.18, 0.5, STEEL)
	# A low quay lip round the pier head, open where the pier leaves.
	for i in 28:
		var angle := TAU * (float(i) + 0.5) / 28.0
		if absf(wrapf(angle - PI, -PI, PI)) < 0.3:
			continue
		var at := Vector3(sin(angle), 0.0, cos(angle)) * 9.7
		kit.box(SOLID, at + Vector3.UP * 0.1, Vector3(2.1, 0.25, 0.5), CONCRETE, angle)
	# The container yard to the west, stacked one to four high.
	var palette := [Color(0.09, 0.035, 0.025), Color(0.02, 0.06, 0.065), Color(0.025, 0.035, 0.08), Color(0.05, 0.05, 0.056), Color(0.07, 0.02, 0.03)]
	for row in 6:
		for col in 8:
			var base := Vector3(-42.0 - row * 6.5, 0.0, -30.0 + col * 8.0)
			for level in rng.randi_range(0, 4):
				kit.block(SOLID, base + Vector3.UP * level * 2.6, Vector3(2.44, 2.55, 6.1), palette[rng.randi() % palette.size()])
	# Two ship-to-shore cranes, booms reaching out over the water high above the fight.
	for z in [-14.0, 16.0]:
		_crane(kit, z)
	# A capsized ship in the outer harbour.
	var hull := Basis(Vector3.UP, 0.25) * Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(12.0, 58.0, 12.0))
	kit.shape(SOLID, &"cyl_12_100", Transform3D(hull, Vector3(-22.0, -2.0, -88.0)), Color(0.06, 0.03, 0.035))
	kit.box(SOLID, Vector3(-22.0, 4.2, -88.0), Vector3(54.0, 0.7, 1.0), Color(0.08, 0.04, 0.03), 0.25)
	# The breakwater and its lighthouse, off to the right.
	kit.box(SOLID, Vector3(52.0, 0.6, -46.0), Vector3(64.0, 1.8, 6.0), CONCRETE, -0.35)
	var light := Vector3(70.0, 1.2, -58.0)
	kit.cylinder(SOLID, light, 2.6, 22.0, Color(0.12, 0.12, 0.14), 0.72, 12)
	kit.cylinder(LIT, light + Vector3.UP * 22.0, 1.3, 2.2, WARM_LAMP * 0.85, 1.0, 12)
	kit.cylinder(SOLID, light + Vector3.UP * 24.2, 1.8, 2.0, DARK, 0.0, 12)
	kit.halo(light + Vector3.UP * 23.1, WARM_LAMP, 10.0)
	# The far shore: a dead city behind the player, across the water.
	_skyline(kit, rng, 30, 80.0, 124.0, 10.0, 34.0, 0.0, 1.7)
	kit.ridge(150.0, 0.5, 4.0, Color(0.02, 0.03, 0.04), Color(0.035, 0.05, 0.06), 4)
	return kit.build("HarborSite")

## The RSF listening post on a mountain ridge, snow past the pad.
static func summit() -> Node3D:
	var kit := SiteKit.new()
	var rng := _rng(3)
	kit.ridge(150.0, 0.0, 10.0, Color(0.03, 0.036, 0.052), Color(0.1, 0.11, 0.15), 8, 56)
	kit.ridge(172.0, 4.0, 28.0, Color(0.035, 0.04, 0.06), Color(0.2, 0.22, 0.28), 3, 72)
	# The relay dish on its lattice, behind and to the left, turned to the sky.
	var dish := Vector3(-28.0, 0.0, 22.0)
	_lattice(kit, dish, 2.2, 0.9, 12.0, STEEL)
	var tilt := Basis(Vector3.RIGHT, -0.8)
	kit.shape(SOLID, &"sphere", Transform3D(tilt * Basis.from_scale(Vector3(11.0, 2.4, 11.0)), dish + Vector3.UP * 15.0), Color(0.07, 0.075, 0.09))
	var feed := dish + Vector3.UP * 15.0 + tilt * Vector3.UP * 5.0
	kit.beam(SOLID, dish + Vector3.UP * 15.0, feed, 0.25, STEEL)
	kit.halo(feed, RSF_CYAN, 1.6)
	# The comms mast ahead and right, guyed against the wind.
	var mast := Vector3(30.0, 0.0, -34.0)
	kit.cylinder(SOLID, mast, 0.35, 42.0, STEEL, 0.4, 6)
	for i in 3:
		var angle := TAU * float(i) / 3.0 + 0.4
		kit.beam(SOLID, mast + Vector3.UP * 38.0, mast + Vector3(sin(angle), 0.0, cos(angle)) * 14.0, 0.06, STEEL)
	kit.halo(mast + Vector3.UP * 42.2, WARNING_RED, 2.4)
	kit.halo(mast + Vector3.UP * 22.0, WARNING_RED, 1.6)
	# The RSF hut: a lit window and a whip antenna.
	var hut := Vector3(20.0, 0.0, 24.0)
	kit.block(SOLID, hut, Vector3(6.0, 2.8, 3.0), STEEL)
	kit.box(LIT, hut + Vector3(-1.2, 1.6, -1.52), Vector3(1.6, 0.7, 0.05), RSF_CYAN * 0.8)
	kit.beam(SOLID, hut + Vector3(2.4, 2.8, 0.0), hut + Vector3(2.4, 7.0, 0.0), 0.05, STEEL)
	# Drifts and rock, kept low.
	for i in 34:
		var at := _ring_point(rng, 10.5, 42.0)
		kit.lump(SOLID, at, Vector3(rng.randf_range(2.0, 6.0), rng.randf_range(0.3, 0.7), rng.randf_range(1.5, 4.0)), Color(0.06, 0.068, 0.092), rng.randf() * PI)
	for i in 14:
		var at := _ring_point(rng, 12.0, 45.0)
		kit.lump(SOLID, at, Vector3.ONE * rng.randf_range(0.6, 1.6) * Vector3(1.4, 0.7, 1.2), Color(0.025, 0.028, 0.036), rng.randf() * PI)
	return kit.build("SummitSite")

## A stadium turned evacuation shelter: the pad on the centre circle, stands all round.
static func stadium() -> Node3D:
	var kit := SiteKit.new()
	var seat := Color(0.04, 0.045, 0.066)
	var seat_alt := Color(0.03, 0.034, 0.05)
	# Raked stands behind both touchlines and both goal lines; the corners stay open.
	for side in [-1.0, 1.0]:
		for row in 16:
			var rise := 0.6 + row * 1.1
			var color: Color = seat if row % 2 == 0 else seat_alt
			kit.block(SOLID, Vector3(0.0, 0.0, side * (41.1 + row * 2.2)), Vector3(108.0, rise, 2.2), color)
			kit.block(SOLID, Vector3(side * (61.1 + row * 2.2), 0.0, 0.0), Vector3(2.2, rise, 74.0), color)
		kit.block(SOLID, Vector3(0.0, 0.0, side * 77.5), Vector3(108.0, 21.0, 1.0), DARK)
		kit.block(SOLID, Vector3(side * 97.5, 0.0, 0.0), Vector3(1.0, 21.0, 74.0), DARK)
		# Roofs over the long stands, a strip of work lights along the front edge.
		kit.box(SOLID, Vector3(0.0, 23.0, side * 62.0), Vector3(110.0, 0.6, 32.0), DARK)
		kit.box(LIT, Vector3(0.0, 22.6, side * 46.2), Vector3(110.0, 0.2, 0.3), COOL_LAMP * 0.6)
		# Goal frames.
		for post in [-3.66, 3.66]:
			kit.beam(LIT, Vector3(side * 52.5, 0.0, post), Vector3(side * 52.5, 2.44, post), 0.12, Color(0.5, 0.52, 0.56))
		kit.beam(LIT, Vector3(side * 52.5, 2.44, -3.66), Vector3(side * 52.5, 2.44, 3.66), 0.12, Color(0.5, 0.52, 0.56))
		# Shelter tents in rows along each touchline.
		for x in range(-40, 41, 8):
			var tent := Vector3(float(x), 0.0, side * 29.0)
			kit.roof(SOLID, tent, Vector3(4.0, 2.3, 5.0), Color(0.15, 0.16, 0.18), PI * 0.5)
			kit.box(LIT, tent + Vector3(0.0, 0.5, -side * 2.52), Vector3(3.0, 0.15, 0.04), RSF_CYAN * 0.7)
	# Floodlight towers in the open corners, every head facing the pitch.
	for corner: Vector3 in [Vector3(-64, 0, -50), Vector3(64, 0, -50), Vector3(-64, 0, 50), Vector3(64, 0, 50)]:
		kit.cylinder(SOLID, corner, 0.7, 46.0, STEEL, 0.6, 6)
		var head := corner + Vector3.UP * 47.0
		var yaw := atan2(corner.x, corner.z)
		kit.box(SOLID, head, Vector3(6.0, 3.6, 0.6), DARK, yaw)
		kit.box(LIT, head - corner.normalized() * 0.32, Vector3(5.4, 3.0, 0.05), Color(0.95, 0.97, 1.0), yaw)
		kit.halo(head - corner.normalized() * 1.5, Color(0.9, 0.94, 1.0), 16.0)
	# A dark scoreboard on the back wall of the west stand, framed in RSF cyan. No text: it could be anywhere.
	var board := Vector3(-98.2, 25.0, 0.0)
	kit.box(SOLID, board, Vector3(0.8, 7.0, 16.0), Color(0.012, 0.014, 0.02))
	for z in [-8.0, 8.0]:
		kit.box(LIT, board + Vector3(0.45, 0.0, z), Vector3(0.05, 7.0, 0.2), RSF_CYAN * 0.8)
	for y in [-3.5, 3.5]:
		kit.box(LIT, board + Vector3(0.45, y, 0.0), Vector3(0.05, 0.2, 16.0), RSF_CYAN * 0.8)
	return kit.build("StadiumSite")

## A radio telescope array on a salt flat at dusk: three arms of dishes, all turned one way.
static func salt_flat() -> Node3D:
	var kit := SiteKit.new()
	var rng := _rng(5)
	kit.ridge(150.0, 1.0, 9.0, Color(0.06, 0.045, 0.06), Color(0.11, 0.08, 0.1), 5)
	var pale := Color(0.13, 0.12, 0.14)
	# Two arms reach out to the front diagonals and one straight back, so no dish stands
	# behind a rift opening straight ahead.
	for arm in [TAU / 3.0, -TAU / 3.0, 0.0]:
		var out := Vector3(sin(arm), 0.0, cos(arm))
		var across := out.cross(Vector3.UP)
		for rail in [-0.75, 0.75]:
			kit.beam(SOLID, out * 22.0 + across * rail + Vector3.UP * 0.05, out * 126.0 + across * rail + Vector3.UP * 0.05, 0.12, STEEL)
		for r in [34.0, 54.0, 76.0, 100.0, 124.0]:
			_dish(kit, out * r, pale)
	# The array's control building, behind and to the left, its windows still lit.
	var hall := Vector3(-34.0, 0.0, 26.0)
	kit.block(SOLID, hall, Vector3(14.0, 4.0, 8.0), Color(0.06, 0.055, 0.065))
	kit.box(LIT, hall + Vector3(-3.0, 2.2, -4.03), Vector3(4.0, 0.8, 0.05), WARM_LAMP * 0.6)
	kit.box(LIT, hall + Vector3(3.5, 2.2, -4.03), Vector3(2.0, 0.8, 0.05), RSF_CYAN * 0.6)
	for i in 10:
		var at := _ring_point(rng, 14.0, 60.0)
		kit.lump(SOLID, at, Vector3(rng.randf_range(0.6, 1.4), 0.4, rng.randf_range(0.6, 1.4)), Color(0.05, 0.042, 0.05), rng.randf() * PI)
	return kit.build("SaltFlatSite")

## A small town's square, emptied in an hour. Main street runs north and south of it, a
## church closes the north end, and a water tower stands over the roofs. No names anywhere.
static func small_town() -> Node3D:
	var kit := SiteKit.new()
	var rng := _rng(31)
	var city := kit.city_tool()
	var awnings := [Color(0.06, 0.028, 0.03), Color(0.02, 0.04, 0.05), Color(0.05, 0.045, 0.03)]
	# The square: shops on all four sides, open where the main street leaves north and south.
	for side in [-1.0, 1.0]:
		for x in [-28.0, -15.0, 15.0, 28.0]:
			var width := 12.0 if absf(x) > 20.0 else 11.0
			_shop(kit, city, rng, Vector3(x, 0.0, side * 28.0), Vector3(width, rng.randf_range(7.0, 11.0), 12.0), Vector3(0.0, 0.0, -side), awnings)
		for z in [-14.0, 0.0, 14.0]:
			_shop(kit, city, rng, Vector3(side * 28.0, 0.0, z), Vector3(12.0, rng.randf_range(7.0, 10.0), 12.0), Vector3(-side, 0.0, 0.0), awnings)
		# Main street, both ways out of the square.
		var along := 40.0
		while along < 86.0:
			var length := rng.randf_range(9.0, 14.0)
			for x in [-14.0, 14.0]:
				_shop(kit, city, rng, Vector3(x, 0.0, side * (along + length * 0.5)), Vector3(12.0, rng.randf_range(6.0, 12.0), length), Vector3(-signf(x), 0.0, 0.0), awnings)
			along += length + rng.randf_range(1.0, 3.0)
	# The church at the north end of the street, its steeple the landmark straight ahead.
	var church := Vector3(0.0, 0.0, -104.0)
	var stone := Color(0.045, 0.04, 0.052)
	kit.block(SOLID, church, Vector3(11.0, 9.0, 18.0), stone)
	kit.roof(SOLID, church + Vector3.UP * 9.0, Vector3(11.6, 6.0, 18.4), DARK)
	kit.block(SOLID, church + Vector3(0.0, 0.0, 11.0), Vector3(4.6, 18.0, 4.6), stone)
	kit.cylinder(SOLID, church + Vector3(0.0, 18.0, 11.0), 3.2, 11.0, DARK, 0.0, 4)
	kit.box(LIT, church + Vector3(0.0, 13.0, 13.33), Vector3(1.2, 1.2, 0.05), WARM_LAMP * 0.35)
	# The water tower over the roofs to the north-west. Blank: no town name.
	var tower := Vector3(-38.0, 0.0, -52.0)
	_lattice(kit, tower, 3.0, 2.2, 17.0, STEEL)
	kit.cylinder(SOLID, tower + Vector3.UP * 17.0, 4.5, 5.5, Color(0.06, 0.064, 0.078), 1.0, 12)
	kit.cylinder(SOLID, tower + Vector3.UP * 22.5, 4.7, 2.2, DARK, 0.0, 12)
	# Poles and sagging wires down both sides of the street, one streetlamp still working.
	for side in [-1.0, 1.0]:
		var previous := Vector3.ZERO
		for z in [36.0, 58.0, 80.0]:
			for x in [-7.0, 7.0]:
				var pole := Vector3(x, 0.0, side * z)
				kit.cylinder(SOLID, pole, 0.15, 9.0, DARK, 0.8, 5)
				kit.beam(SOLID, pole + Vector3(-1.2, 8.6, 0.0), pole + Vector3(1.2, 8.6, 0.0), 0.12, DARK)
			if previous != Vector3.ZERO:
				for x in [-7.0, 7.0]:
					kit.beam(SOLID, Vector3(x, 8.5, previous.z), Vector3(x, 8.5, side * z), 0.04, DARK)
			previous = Vector3(0.0, 0.0, side * z)
	var lamp := Vector3(6.4, 0.0, -48.0)
	kit.cylinder(SOLID, lamp, 0.1, 6.0, DARK, 1.0, 5)
	kit.box(LIT, lamp + Vector3(-0.8, 5.9, 0.0), Vector3(0.6, 0.15, 0.3), COOL_LAMP * 0.8)
	kit.halo(lamp + Vector3(-0.8, 5.7, 0.0), COOL_LAMP, 2.6)
	# Two cars left where they stopped.
	for car in [[Vector3(-3.0, 0.0, -46.0), 0.2], [Vector3(3.2, 0.0, 60.0), -0.1]]:
		kit.block(SOLID, (car[0] as Vector3) + Vector3.UP * 0.3, Vector3(1.9, 0.8, 4.4), Color(0.04, 0.045, 0.06), car[1])
		kit.block(SOLID, (car[0] as Vector3) + Vector3.UP * 1.1, Vector3(1.7, 0.6, 2.2), Color(0.02, 0.022, 0.03), car[1])
	# Houses spread out past the centre, a few windows still lit.
	var placed := 0
	while placed < 46:
		var at := _ring_point(rng, 46.0, 104.0)
		if absf(at.x) < 22.0:
			continue
		placed += 1
		var yaw := atan2(at.x, at.z)
		var size := Vector3(rng.randf_range(7.0, 10.0), rng.randf_range(4.0, 6.0), rng.randf_range(7.0, 10.0))
		kit.block(SOLID, at, size, Color(0.04, 0.04, 0.05).lerp(Color(0.05, 0.035, 0.035), rng.randf()), yaw)
		kit.roof(SOLID, at + Vector3.UP * size.y, Vector3(size.x + 0.6, 3.0, size.z + 0.6), DARK, yaw)
		if rng.randf() < 0.25:
			var front := Basis(Vector3.UP, yaw) * Vector3(0.0, 2.2, -size.z * 0.5 - 0.03)
			kit.box(LIT, at + front, Vector3(1.2, 1.0, 0.05), WARM_LAMP * 0.7, yaw)
	return kit.build("SmallTownSite")

## Farmland at night: ploughed fields past the pad, a farmhouse with its porch light on.
static func farmland() -> Node3D:
	var kit := SiteKit.new()
	var rng := _rng(13)
	kit.ridge(150.0, 3.0, 16.0, Color(0.02, 0.028, 0.032), Color(0.035, 0.045, 0.055), 13)
	kit.ridge(105.0, 0.0, 4.0, Color(0.02, 0.024, 0.022), Color(0.03, 0.034, 0.03), 17, 48)
	# Tree lines along the field edges, left and right.
	for i in 80:
		var arc := rng.randf_range(1.75, 2.75) * (1.0 if i % 2 == 0 else -1.0)
		var at := Vector3(sin(arc), 0.0, cos(arc)) * rng.randf_range(68.0, 92.0)
		var size := Vector3(rng.randf_range(5.0, 9.0), rng.randf_range(6.0, 11.0), rng.randf_range(5.0, 9.0))
		kit.lump(SOLID, at + Vector3.UP * size.y * 0.45, size, Color(0.014, 0.024, 0.02), rng.randf() * PI)
	# The farmhouse, its lit window and porch light facing the field.
	var house := Vector3(40.0, 0.0, -48.0)
	kit.block(SOLID, house, Vector3(11.0, 6.0, 8.0), Color(0.07, 0.065, 0.07))
	kit.roof(SOLID, house + Vector3.UP * 6.0, Vector3(8.6, 4.0, 11.6), DARK, PI * 0.5)
	kit.block(SOLID, house + Vector3(-3.5, 6.0, 0.0), Vector3(1.0, 4.5, 1.0), DARK)
	kit.box(LIT, house + Vector3(-2.5, 2.4, 4.03), Vector3(1.3, 1.1, 0.05), WARM_LAMP * 0.9)
	kit.box(SOLID, house + Vector3(2.0, 2.9, 5.0), Vector3(4.0, 0.2, 2.0), DARK)
	kit.halo(house + Vector3(2.0, 2.6, 4.6), Color(1.0, 0.78, 0.5), 2.6)
	# The barn and silo beyond it.
	var barn := Vector3(60.0, 0.0, -34.0)
	kit.block(SOLID, barn, Vector3(12.0, 7.0, 18.0), Color(0.07, 0.02, 0.025))
	kit.roof(SOLID, barn + Vector3.UP * 7.0, Vector3(12.6, 5.0, 18.6), Color(0.03, 0.03, 0.035))
	kit.box(SOLID, barn + Vector3(-6.03, 2.6, 0.0), Vector3(0.05, 5.0, 5.0), Color(0.1, 0.09, 0.085))
	var silo := Vector3(72.0, 0.0, -50.0)
	kit.cylinder(SOLID, silo, 3.0, 15.0, Color(0.08, 0.085, 0.095), 1.0, 12)
	kit.lump(SOLID, silo + Vector3.UP * 15.0, Vector3(6.2, 3.0, 6.2), Color(0.06, 0.064, 0.072))
	# A windpump to the left.
	var pump := Vector3(-36.0, 0.0, -26.0)
	_lattice(kit, pump, 1.8, 0.4, 11.0, DARK)
	var hub := pump + Vector3(0.0, 11.5, -0.6)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		kit.beam(SOLID, hub, hub + Vector3(cos(angle), sin(angle), 0.0) * 2.6, 0.22, DARK)
	kit.box(SOLID, pump + Vector3(0.0, 11.5, 1.6), Vector3(0.1, 1.4, 3.0), DARK)
	# Fences along the field edges, all well clear of the fight.
	for line in [[Vector3(-60, 0, -21), Vector3(-21, 0, -21)], [Vector3(24, 0, -20), Vector3(24, 0, -80)], [Vector3(-26, 0, 25), Vector3(40, 0, 25)]]:
		_fence(kit, line[0], line[1])
	# Round bales left in the field.
	for i in 11:
		var at := _ring_point(rng, 22.0, 46.0)
		var lying := Basis(Vector3.UP, rng.randf() * PI) * Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(1.6, 1.4, 1.6))
		kit.shape(SOLID, &"cyl_10_100", Transform3D(lying, at + Vector3.UP * 0.8), Color(0.09, 0.075, 0.04))
	# Wind turbines on the far fields, warning lights on every nacelle.
	for arc in [2.45, 2.85, -2.6]:
		_turbine(kit, Vector3(sin(arc), 0.0, cos(arc)) * 124.0, arc * 2.0)
	return kit.build("FarmlandSite")

static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

## A random ground point between two radii.
static func _ring_point(rng: RandomNumberGenerator, near: float, far: float) -> Vector3:
	var angle := rng.randf() * TAU
	return Vector3(sin(angle), 0.0, cos(angle)) * rng.randf_range(near, far)

## Facade towers in BreachCity's format, spread over an arc centred on `arc_center`.
static func _skyline(kit: SiteKit, rng: RandomNumberGenerator, count: int, near: float, far: float, low: float, high: float, arc_center: float, arc_half: float) -> void:
	for _i in count:
		var angle := arc_center + rng.randf_range(-arc_half, arc_half)
		var center := Vector3(sin(angle), 0.0, cos(angle)) * rng.randf_range(near, far) + Vector3.DOWN * 0.5
		var size := Vector3(rng.randf_range(6.0, 14.0), rng.randf_range(low, high), rng.randf_range(6.0, 14.0))
		BreachCity.tower(kit.city_tool(), Transform3D(Basis(Vector3.UP, rng.randf() * PI), center), size, rng.randf())

## A town shop: a facade building, plus an awning over its front when it faces the square.
static func _shop(kit: SiteKit, city: SurfaceTool, rng: RandomNumberGenerator, center: Vector3, size: Vector3, front: Vector3, awnings: Array) -> void:
	BreachCity.tower(city, Transform3D(Basis(), center + Vector3.DOWN * 0.3), size, rng.randf())
	if rng.randf() < 0.6:
		var depth := size.z if absf(front.z) > 0.5 else size.x
		var width := size.x if absf(front.z) > 0.5 else size.z
		var at := center + front * (depth * 0.5 + 0.6) + Vector3.UP * 3.2
		var awning := Vector3(width - 1.5, 0.15, 1.2) if absf(front.z) > 0.5 else Vector3(1.2, 0.15, width - 1.5)
		kit.box(SOLID, at, awning, awnings[rng.randi() % awnings.size()])

## A ship-to-shore gantry crane straddling the quay at `z`, its boom out over the water.
static func _crane(kit: SiteKit, z: float) -> void:
	var color := Color(0.05, 0.06, 0.08)
	for x in [-34.0, -52.0]:
		for dz in [-7.0, 7.0]:
			kit.beam(SOLID, Vector3(x, 0.0, z + dz), Vector3(x, 34.0, z + dz), 1.0, color)
		kit.beam(SOLID, Vector3(x, 34.0, z - 7.0), Vector3(x, 34.0, z + 7.0), 0.9, color)
	for dz in [-7.0, 7.0]:
		kit.beam(SOLID, Vector3(-52.0, 34.0, z + dz), Vector3(-34.0, 34.0, z + dz), 0.9, color)
	var apex := Vector3(-44.0, 47.0, z)
	kit.beam(SOLID, Vector3(-60.0, 36.0, z), Vector3(-18.0, 36.0, z), 1.6, color)
	kit.beam(SOLID, Vector3(-52.0, 34.0, z), apex, 0.6, color)
	kit.beam(SOLID, Vector3(-34.0, 34.0, z), apex, 0.6, color)
	kit.beam(SOLID, apex, Vector3(-18.0, 36.0, z), 0.3, color)
	kit.beam(SOLID, apex, Vector3(-60.0, 36.0, z), 0.3, color)
	kit.block(SOLID, Vector3(-30.0, 33.0, z), Vector3(3.0, 2.4, 2.6), DARK)
	kit.halo(apex + Vector3.UP * 0.6, WARNING_RED, 2.2)

## Four legs leaning in from `spread` at the foot to `top` at `height`, braced twice.
static func _lattice(kit: SiteKit, base: Vector3, spread: float, top: float, height: float, color: Color) -> void:
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var c: Vector2 = corners[i]
		kit.beam(SOLID, base + Vector3(c.x * spread, 0.0, c.y * spread), base + Vector3(c.x * top, height, c.y * top), 0.22, color)
	for level in [0.33, 0.66]:
		var half := lerpf(spread, top, level)
		for i in 4:
			var a: Vector2 = corners[i] * half
			var b: Vector2 = corners[(i + 1) % 4] * half
			kit.beam(SOLID, base + Vector3(a.x, height * level, a.y), base + Vector3(b.x, height * level, b.y), 0.12, color)

## One radio dish: pedestal, yoke, and a dish turned to the same patch of sky as all the others.
static func _dish(kit: SiteKit, base: Vector3, color: Color) -> void:
	kit.cylinder(SOLID, base, 0.9, 7.0, color, 0.8, 8)
	kit.block(SOLID, base + Vector3.UP * 7.0, Vector3(2.4, 1.6, 1.2), color)
	var tilt := Basis(Vector3.RIGHT, 0.75)
	var center := base + Vector3.UP * 10.5
	kit.shape(SOLID, &"sphere", Transform3D(tilt * Basis.from_scale(Vector3(12.0, 2.2, 12.0)), center), color)
	kit.beam(SOLID, center, center + tilt * Vector3.UP * 4.5, 0.2, STEEL)

## Posts every 3.5 m and two rails.
static func _fence(kit: SiteKit, from: Vector3, to: Vector3) -> void:
	var wood := Color(0.05, 0.04, 0.03)
	var count := int(from.distance_to(to) / 3.5)
	for i in count + 1:
		kit.cylinder(SOLID, from.lerp(to, float(i) / float(count)), 0.07, 1.2, wood, 1.0, 5)
	for y in [0.6, 1.05]:
		kit.beam(SOLID, from + Vector3.UP * y, to + Vector3.UP * y, 0.05, wood)

## A wind turbine with its blades at rest, a warning light on the nacelle.
static func _turbine(kit: SiteKit, base: Vector3, blade_turn: float) -> void:
	var white := Color(0.1, 0.105, 0.12)
	kit.cylinder(SOLID, base, 1.3, 46.0, white, 0.55, 8)
	var hub := base + Vector3.UP * 47.0
	var facing := -base.normalized()
	kit.box(SOLID, hub - facing * 1.5, Vector3(2.2, 2.2, 6.0), white, atan2(base.x, base.z))
	var across := facing.cross(Vector3.UP).normalized()
	for i in 3:
		var angle := blade_turn + TAU * float(i) / 3.0
		kit.beam(SOLID, hub + facing * 1.6, hub + facing * 1.6 + (across * cos(angle) + Vector3.UP * sin(angle)) * 21.0, 0.7, white)
	kit.halo(hub + Vector3.UP * 1.4, WARNING_RED, 3.0)
