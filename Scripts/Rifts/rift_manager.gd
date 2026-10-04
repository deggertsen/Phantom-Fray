extends Node3D
class_name RiftManager

const SfxVariations := preload("res://Scripts/Audio/sfx_variations.gd")

signal health_changed(current: int, maximum: int)
signal phantom_resolved(result: Dictionary)
signal player_damaged(amount: float)
signal strike_rejected(reason: StringName)
signal closed

@export var phantom_scenes: Array[PackedScene] = []
@export var spawn_interval: float = 3.5
@export var max_live_phantoms: int = 4
@export var maximum_health: int = 100
@export var spawn_radius: float = 2.5

var rift_id: int = 0
var rift_health: int
var spawning_enabled: bool = false
var _closing: bool = false
var _dissolve_amount: float = 0.0
var _damage_flash: float = 0.0
var _spawn_timer: Timer
var _phantom_container: Node3D
var _live_phantoms: Dictionary = {}
var _portal_material: ShaderMaterial
var _wave_scenes: Array[PackedScene] = []
var _speed_scale: float = 1.0
var _telegraph_scale: float = 1.0
var _beacon: Node3D
var _beacon_time: float = 0.0

func _ready() -> void:
	add_to_group("active_rift")
	rift_health = maximum_health
	_initialize_rift_visuals()
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	_phantom_container = get_tree().get_first_node_in_group("PhantomContainer") as Node3D
	if _phantom_container == null:
		_phantom_container = self

func configure_wave(wave: Dictionary) -> void:
	maximum_health = int(wave.get("health", maximum_health))
	rift_health = maximum_health
	spawn_interval = float(wave.get("interval", spawn_interval))
	if _spawn_timer:
		_spawn_timer.wait_time = spawn_interval
	max_live_phantoms = int(wave.get("max_live", max_live_phantoms))
	_speed_scale = float(wave.get("speed_scale", 1.0))
	_telegraph_scale = float(wave.get("telegraph_scale", 1.0))
	var pool: Array = wave.get("pool", [])
	if not pool.is_empty():
		_wave_scenes.clear()
		for variant_id in pool:
			var path := MissionCatalog.scene_path(String(variant_id))
			var scene := load(path) as PackedScene
			if scene:
				_wave_scenes.append(scene)
	_update_health_shader()

func start_spawning(spawn_immediately: bool = false) -> void:
	if _closing:
		return
	spawning_enabled = true
	_spawn_timer.start()
	if spawn_immediately:
		_on_spawn_timer_timeout()

func stop_spawning() -> void:
	spawning_enabled = false
	if _spawn_timer:
		_spawn_timer.stop()

func delay_first_spawn(delay: float) -> void:
	if _spawn_timer == null or _closing:
		return
	# https://docs.godotengine.org/en/stable/classes/class_timer.html#class-timer-method-start
	_spawn_timer.start(maxf(delay, 0.4))

func force_cleanup() -> void:
	stop_spawning()
	for phantom in _live_phantoms.values():
		if is_instance_valid(phantom) and phantom.has_method("force_cleanup"):
			phantom.force_cleanup()
	_live_phantoms.clear()
	queue_free()

func is_marked() -> bool:
	return not _closing

func _process(delta: float) -> void:
	_pulse_beacon(delta)
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
	if _portal_material:
		_portal_material.set_shader_parameter("damage_flash", _damage_flash)
	if not _closing:
		return
	_dissolve_amount = minf(_dissolve_amount + delta * 0.75, 1.0)
	if _portal_material:
		_portal_material.set_shader_parameter("dissolve_amount", _dissolve_amount)
	if _dissolve_amount >= 1.0:
		queue_free()

func _on_spawn_timer_timeout() -> void:
	_prune_phantoms()
	if not spawning_enabled or _closing or _live_phantoms.size() >= max_live_phantoms:
		return
	_spawn_phantom()

func _spawn_phantom() -> void:
	if phantom_scenes.is_empty():
		push_warning("RiftManager: no phantom scenes configured")
		return
	var scenes: Array[PackedScene] = _wave_scenes if not _wave_scenes.is_empty() else phantom_scenes
	var scene := scenes[randi() % scenes.size()]
	if scene == null:
		return
	var phantom := scene.instantiate() as Node3D
	if phantom == null:
		return
	var angle := randf_range(-0.65, 0.65)
	var offset := Vector3(sin(angle), randf_range(-0.35, 0.35), cos(angle)) * randf_range(0.8, spawn_radius)
	phantom.position = _phantom_container.to_local(global_position + offset)
	_phantom_container.add_child(phantom)
	if phantom.has_method("apply_pressure"):
		phantom.apply_pressure(_speed_scale, _telegraph_scale)
	_live_phantoms[phantom.get_instance_id()] = phantom
	phantom.resolved.connect(_on_phantom_resolved.bind(phantom))
	phantom.player_contact.connect(_on_phantom_player_contact.bind(phantom))
	if phantom.has_signal("strike_rejected"):
		phantom.strike_rejected.connect(_on_phantom_strike_rejected)
	phantom.tree_exiting.connect(_on_phantom_tree_exiting.bind(phantom.get_instance_id()))

func _on_phantom_resolved(result: Dictionary, phantom: Node3D) -> void:
	_unregister_phantom(phantom)
	if _closing:
		return
	var damage: int = result.get("rift_damage", 0)
	rift_health = maxi(rift_health - damage, 0)
	_damage_flash = 1.0
	_update_health_shader()
	health_changed.emit(rift_health, maximum_health)
	phantom_resolved.emit(result)
	if rift_health <= 0:
		_close_rift()

func _on_phantom_strike_rejected(reason: StringName) -> void:
	strike_rejected.emit(reason)

func _on_phantom_player_contact(amount: float, phantom: Node3D) -> void:
	_unregister_phantom(phantom)
	player_damaged.emit(amount)

func _on_phantom_tree_exiting(instance_id: int) -> void:
	_live_phantoms.erase(instance_id)

func _unregister_phantom(phantom: Node3D) -> void:
	if is_instance_valid(phantom):
		_live_phantoms.erase(phantom.get_instance_id())

func _prune_phantoms() -> void:
	for instance_id in _live_phantoms.keys():
		if not is_instance_valid(_live_phantoms[instance_id]):
			_live_phantoms.erase(instance_id)

func _close_rift() -> void:
	if _closing:
		return
	_closing = true
	stop_spawning()
	if _beacon:
		_beacon.visible = false
	closed.emit()
	for phantom in _live_phantoms.values():
		if is_instance_valid(phantom) and phantom.has_method("force_cleanup"):
			phantom.force_cleanup()
	_live_phantoms.clear()
	var stream := SfxVariations.pick("rift_close_sound")
	if stream == null:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.bus = &"SFX"
	audio.volume_db = -5.0
	add_child(audio)
	audio.play()

func _initialize_rift_visuals() -> void:
	var portal := MeshInstance3D.new()
	portal.name = "Portal"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.0, 4.0)
	portal.mesh = mesh
	_portal_material = preload("res://Resources/Materials/rift_video.tres").duplicate() as ShaderMaterial
	portal.material_override = _portal_material
	add_child(portal)
	_build_beacon()
	_update_health_shader()

func _build_beacon() -> void:
	_beacon = Node3D.new()
	_beacon.name = "RiftBeacon"
	_beacon.top_level = true
	add_child(_beacon)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var column := CylinderMesh.new()
	column.top_radius = 0.05
	column.bottom_radius = 0.16
	column.height = 7.2
	beam.mesh = column
	beam.material_override = _beacon_material(Color(0.35, 0.9, 1.0), 2.4)
	_beacon.add_child(beam)
	var ring := MeshInstance3D.new()
	ring.name = "FloorRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.05
	torus.rings = 12
	torus.ring_segments = 24
	ring.mesh = torus
	ring.position = Vector3(0.0, -3.55, 0.0)
	ring.material_override = _beacon_material(Color(1.0, 0.25, 0.75), 1.8)
	_beacon.add_child(ring)
	var sign := Label3D.new()
	sign.name = "BeaconLabel"
	sign.text = "RIFT"
	sign.font_size = 72
	sign.pixel_size = 0.012
	sign.position = Vector3(0.0, 3.85, 0.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(0.75, 0.95, 1.0)
	sign.outline_size = 16
	sign.outline_modulate = Color(0.05, 0.0, 0.12)
	sign.no_depth_test = true
	_beacon.add_child(sign)

func _beacon_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.55)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _pulse_beacon(delta: float) -> void:
	if _beacon == null or not is_instance_valid(_beacon):
		return
	_beacon.global_position = Vector3(global_position.x, 3.6, global_position.z)
	if _closing:
		_beacon.visible = false
		return
	_beacon_time += delta
	var pulse := 0.65 + sin(_beacon_time * 3.4) * 0.35
	for child in _beacon.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var material := mesh.material_override as StandardMaterial3D
		if material:
			material.emission_energy_multiplier = lerpf(1.2, 3.4, pulse)

func _update_health_shader() -> void:
	if _portal_material == null:
		return
	var ratio := float(rift_health) / maxf(float(maximum_health), 1.0)
	_portal_material.set_shader_parameter("health_ratio", ratio)
	_portal_material.set_shader_parameter("intensity", lerpf(0.75, 1.2, ratio))
