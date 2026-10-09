extends Node3D

## Dresses the breach site: the floor, the RSF pylons, the dead city and its rubble.
## The floor's corruption veins follow whichever rifts are open and fade as they seal.

const CYAN := Color(0.08, 0.7, 1.0, 1.0)
const DARK := Color(0.012, 0.018, 0.04, 1.0)
const FLOOR_SHADER := preload("res://Resources/Materials/arena_floor.gdshader")
const NOISE := preload("res://Resources/Materials/breach_noise.tres")
const MAX_RIFTS := 4

const BOSS_LIGHT := Color(0.85, 0.12, 0.3)

var _floor_material: ShaderMaterial
## Rift instance id -> [floor position, corruption strength].
var _corruption: Dictionary = {}
var _pylons: Node3D
var _pylon_colors: Dictionary = {}
var _environment: Environment
var _sun: DirectionalLight3D
var _ambient_color: Color
var _sun_color: Color
var _boss_mood: float = 0.0

func _ready() -> void:
	add_to_group("ArenaPresentation")
	CreatureMesh.prewarm()
	_build_floor()
	_pylons = BreachCity.pylons()
	add_child(_pylons)
	_cache_boss_mood_targets()
	add_child(BreachCity.city())
	add_child(BreachCity.rubble())
	var vfx := CombatVFX.new()
	vfx.name = "CombatVFX"
	add_child(vfx)
	_build_briefing_panel()
	_warm_shaders.call_deferred()

## Compile combat shaders while the menu is up, not when the first phantom appears.
func _warm_shaders() -> void:
	ShaderWarmup.attach(get_tree())

func _process(delta: float) -> void:
	_update_corruption(delta)

func _build_floor() -> void:
	var floor_mesh := get_node_or_null("../Floor/MeshInstance3D") as MeshInstance3D
	if floor_mesh == null:
		return
	# The Floor node is scaled 2x, so this reaches 260 m across, out past the city.
	var plane := PlaneMesh.new()
	plane.size = Vector2(130.0, 130.0)
	floor_mesh.mesh = plane
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = FLOOR_SHADER
	_floor_material.set_shader_parameter("noise_tex", NOISE)
	floor_mesh.material_override = _floor_material

func _update_corruption(delta: float) -> void:
	if _floor_material == null:
		return
	var seen := {}
	for node in get_tree().get_nodes_in_group("active_rift"):
		var rift := node as Node3D
		if rift == null:
			continue
		var id := rift.get_instance_id()
		seen[id] = true
		var target := 0.0
		if rift.has_method("is_marked") and rift.is_marked():
			var health := float(rift.get("rift_health")) / maxf(float(rift.get("maximum_health")), 1.0)
			target = lerpf(0.35, 1.0, clampf(health, 0.0, 1.0))
		var entry: Array = _corruption.get(id, [rift.global_position, 0.0])
		entry[0] = rift.global_position
		entry[1] = move_toward(entry[1], target, delta * 0.6)
		_corruption[id] = entry
	for id in _corruption.keys():
		if not seen.has(id):
			_corruption[id][1] = move_toward(_corruption[id][1], 0.0, delta * 0.6)
			if _corruption[id][1] <= 0.0:
				_corruption.erase(id)
	var packed := PackedVector4Array()
	for entry in _corruption.values():
		if packed.size() >= MAX_RIFTS:
			break
		packed.append(Vector4(entry[0].x, entry[0].z, 0.0, entry[1]))
	while packed.size() < MAX_RIFTS:
		packed.append(Vector4.ZERO)
	_floor_material.set_shader_parameter("rifts", packed)

## The Maw's turn, 0 (none) to 1 (torn): veins race from the rift under the player's feet, the
## sky crack spreads, the pylons flicker and dim, and the light shifts toward the boss's colour.
## Reduced Flashes caps the light shift and holds the pylons steady. The world changes; the
## player's view never moves.
func set_boss_mood(amount: float, rift_position: Vector3, head: Vector3) -> void:
	var calm := _reduced_flashes()
	var changed := not is_equal_approx(amount, _boss_mood)
	_boss_mood = clampf(amount, 0.0, 1.0)
	if _floor_material:
		var reach := Vector2(head.x - rift_position.x, head.z - rift_position.z).length() + 3.0
		_floor_material.set_shader_parameter("surge", Vector3(rift_position.x, rift_position.z, reach * _boss_mood) if _boss_mood > 0.0 else Vector3.ZERO)
	# The sky is rendered into the radiance map, so it only changes in steps.
	var sky := _sky_material()
	if sky and changed:
		var stepped := snappedf(_boss_mood, 0.1)
		if not is_equal_approx(float(sky.get_shader_parameter("crack_spread")), stepped):
			sky.set_shader_parameter("crack_spread", stepped)
	var flicker := 1.0
	if not calm and _boss_mood > 0.0 and _boss_mood < 1.0:
		flicker = 0.45 + 0.55 * randf()
	var lit := lerpf(1.0, 0.35, _boss_mood) * flicker
	for material in _pylon_colors:
		var base: Color = _pylon_colors[material]
		(material as StandardMaterial3D).albedo_color = Color(base.r * lit, base.g * lit, base.b * lit, base.a * (lit if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else 1.0))
	var shift := _boss_mood * (0.35 if calm else 0.7)
	if _environment:
		_environment.ambient_light_color = _ambient_color.lerp(BOSS_LIGHT, shift)
	if _sun:
		_sun.light_color = _sun_color.lerp(BOSS_LIGHT, shift)

func _cache_boss_mood_targets() -> void:
	var emitters := _pylons.get_node_or_null("Emitters") as MeshInstance3D
	if emitters and emitters.mesh:
		for surface in range(1, emitters.mesh.get_surface_count()):
			var material := emitters.mesh.surface_get_material(surface) as StandardMaterial3D
			if material:
				_pylon_colors[material] = material.albedo_color
	var halos := _pylons.get_node_or_null("BeaconGlow") as GeometryInstance3D
	if halos and halos.material_override is StandardMaterial3D:
		_pylon_colors[halos.material_override] = (halos.material_override as StandardMaterial3D).albedo_color
	var world := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world and world.environment:
		_environment = world.environment
		_ambient_color = _environment.ambient_light_color
	_sun = get_node_or_null("../DirectionalLight3D") as DirectionalLight3D
	if _sun:
		_sun_color = _sun.light_color

func _sky_material() -> ShaderMaterial:
	if _environment == null or _environment.sky == null:
		return null
	return _environment.sky.sky_material as ShaderMaterial

func _reduced_flashes() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	return settings != null and bool(settings.get("reduced_flashes"))

func _build_briefing_panel() -> void:
	var label := Label3D.new()
	label.name = "RSFBriefing"
	label.text = "RSF // ERM TRAINING CHAMBER 07\nTHE BREACH IS ACTIVE"
	label.font_size = 42
	label.pixel_size = 0.003
	label.modulate = Color(0.45, 0.9, 1.0)
	label.outline_size = 10
	label.outline_modulate = DARK
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, 2.8, -6.0)
	add_child(label)
