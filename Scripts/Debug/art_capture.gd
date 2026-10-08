extends Node

## Desktop stills of the arena, the phantoms, and the gauntlets for art review.
## Run: Godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/art_capture.tscn
## Writes PNGs to res://reports/art/<label>/ (label from --art-label=<name>, default "current").

const PHANTOMS := {
	"yellow": "res://Scenes/Phantoms/yellow_phantom.tscn",
	"blue": "res://Scenes/Phantoms/blue_phantom.tscn",
	"green": "res://Scenes/Phantoms/green_phantom.tscn",
	"pink": "res://Scenes/Phantoms/pink_phantom.tscn",
}

var _out_dir: String
var _camera: Camera3D
var _main: Node3D
var _phantoms: Dictionary = {}

func _ready() -> void:
	var label := "current"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-label="):
			label = arg.trim_prefix("--art-label=")
	_out_dir = ProjectSettings.globalize_path("res://reports/art/%s" % label)
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	add_child(_main)
	await get_tree().process_frame
	_quiet_main()

	_camera = Camera3D.new()
	_camera.fov = 75.0
	_main.add_child(_camera)
	_camera.make_current()

	var rift := (load("res://Scenes/Rifts/rift_manager.tscn") as PackedScene).instantiate() as Node3D
	_main.add_child(rift)
	rift.global_position = Vector3(0.0, 1.6, -12.0)
	rift.look_at(Vector3(0.0, 1.6, 0.0), Vector3.UP)

	_spawn("yellow", Vector3(-0.9, 1.45, -3.2))
	_spawn("blue", Vector3(1.0, 1.75, -5.0))
	_spawn("green", Vector3(-0.2, 1.3, -7.0))
	_spawn("pink", Vector3(1.9, 1.5, -8.5))
	_place_hands()
	await _settle(30)

	await _shot("operator", Vector3(0.0, 1.6, 0.0), Vector3(0.0, 1.4, -6.0))
	await _shot("wide", Vector3(7.5, 5.0, 5.5), Vector3(0.0, 1.2, -5.0))
	await _shot("arena", Vector3(0.0, 1.6, 0.0), Vector3(-6.0, 1.9, 4.0))
	for id in _phantoms:
		var phantom := _phantoms[id] as Node3D
		var front := phantom.global_position + phantom.global_transform.basis.z * 2.1 + Vector3(0.7, 0.35, 0.0)
		await _shot("phantom-%s" % id, front, phantom.global_position)
	await _shot("gauntlets", Vector3(0.0, 1.62, 0.12), Vector3(0.0, 1.2, -0.6))
	await _wrist(rift)
	await _hits()
	await _low_life()
	await _lineups()
	print("ART CAPTURE COMPLETE: %s" % _out_dir)
	get_tree().quit()

func _quiet_main() -> void:
	for path in ["VRMenuPresenter", "GameFlowController", "RoundController", "MusicManager", "MusicIntensityController", "PerformanceMonitor"]:
		var node := _main.get_node_or_null(path)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if node is Node3D:
				(node as Node3D).visible = false

## Every body form of each species side by side, turned three-quarters to show silhouettes.
func _lineups() -> void:
	for id in _phantoms:
		if is_instance_valid(_phantoms[id]):
			(_phantoms[id] as Node3D).queue_free()
	_phantoms.clear()
	_camera.make_current()
	# Clear the low-life overlay and the in-combat bearing markers out of the way.
	_main.get_node("Player/LifeForceManager").reset()
	var markers := _main.get_node_or_null("RiftSpawnManager/PhantomBearings") as Node3D
	if markers:
		markers.process_mode = Node.PROCESS_MODE_DISABLED
		markers.visible = false
	await get_tree().create_timer(1.0).timeout
	for id in ["yellow", "green", "pink"]:
		var row: Array[Node3D] = []
		for form in CreatureMesh.FORMS:
			_spawn("%s-%d" % [id, form], Vector3(-1.5 + form * 1.5, 1.45, -2.2), id, form)
			var phantom := _phantoms["%s-%d" % [id, form]] as Node3D
			phantom.rotate_y(1.1 if id == "pink" else 0.6)
			row.append(phantom)
		var eye := Vector3(0.0, 1.65, -0.5) if id == "pink" else Vector3(0.0, 1.75, 0.4)
		await _shot("forms-%s" % id, eye, Vector3(0.0, 1.4, -2.2))
		for phantom in row:
			phantom.queue_free()
		_phantoms.clear()

func _spawn(key: String, at: Vector3, id: String = "", form: int = 0) -> void:
	if id == "":
		id = key
	var phantom := (load(PHANTOMS[id]) as PackedScene).instantiate() as Node3D
	phantom.set("creature_form", form)
	_main.get_node("PhantomContainer").add_child(phantom)
	phantom.global_position = at
	# Hold still and face the player so the stills are repeatable.
	phantom.set_physics_process(false)
	var to_player := Vector3(0.0, at.y, 0.0) - at
	phantom.global_transform.basis = Basis(Vector3.UP, atan2(to_player.x, to_player.z))
	if phantom.has_method("place_sweet_spot"):
		phantom.place_sweet_spot(0)
	if phantom.has_method("_update_lane"):
		phantom._update_lane(1.0)
	_phantoms[key] = phantom

## The wrist display mid-mission: standby first, then fed a mission's worth of signals.
func _wrist(rift: Node3D) -> void:
	var hud := _main.get_node_or_null("Player/LeftHandController/RoundHUD") as Node3D
	if hud == null:
		return
	var panel := hud.global_position
	var facing := hud.global_transform.basis.z
	await _shot("wrist-standby", panel + facing * 0.22, panel)
	var round := _main.get_node("RoundController")
	var director := get_tree().get_first_node_in_group("RiftSpawnManager")
	round.score_changed.emit(0, 0, &"reset")
	round.rift_progress_changed.emit(0, 3)
	director.rift_spawned.emit(101, null)
	director.rift_closed.emit(101, 1, 3)
	round.rift_progress_changed.emit(1, 3)
	director.rift_spawned.emit(102, rift)
	rift.health_changed.emit(45, 100)
	round.mission_status_changed.emit("OP-03  2/3  •  CHEN'S GAMBIT")
	round.time_changed.emit(142.0)
	round.combo_changed.emit(4, 2.5)
	round.score_changed.emit(12840, 220, &"sweet_spot")
	var comms := get_tree().get_first_node_in_group("ChenComms")
	if comms:
		comms.say("rift_oclock_4")
	await _settle(6)
	await _shot("wrist", panel + facing * 0.22, panel)
	await _shot("wrist-in-view", Vector3(0.0, 1.62, 0.12), Vector3(0.0, 1.2, -0.6))

## The moment of impact: a sweet-spot hit on yellow, a plain hit burning through blue,
## and a half-block spark on green.
func _hits() -> void:
	var vfx := get_tree().get_first_node_in_group("CombatVFX")
	if vfx == null:
		return
	var yellow := _phantoms["yellow"] as Node3D
	var blue := _phantoms["blue"] as Node3D
	var green := _phantoms["green"] as Node3D
	var lure := (yellow.get_node("SweetSpotVisual") as Node3D).global_position
	vfx.play(&"sweet", lure, 1.0, yellow.get("phantom_color"))
	var struck := blue.global_position + Vector3(-0.25, 0.0, 0.3)
	blue._begin_dissolve(struck, Vector3.FORWARD, false)
	vfx.play(&"hit", struck, 0.7, blue.get("phantom_color"))
	vfx.play(&"guard", green.global_position + Vector3(0.3, 0.0, 0.5), 0.35, green.get("phantom_color"))
	_camera.global_position = Vector3(0.0, 1.6, 0.0)
	_camera.look_at(Vector3(0.0, 1.5, -4.0), Vector3.UP)
	await _settle(5)
	RenderingServer.force_draw()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/hits.png" % _out_dir)

## Critical life force, seen through the player's own camera (the overlay rides on it).
func _low_life() -> void:
	var life := _main.get_node_or_null("Player/LifeForceManager")
	var eyes := _main.get_node_or_null("Player/XRCamera3D") as Camera3D
	if life == null or eyes == null:
		return
	eyes.position = Vector3(0.0, 1.6, 0.0)
	eyes.look_at(Vector3(0.0, 1.4, -6.0), Vector3.UP)
	eyes.make_current()
	life.apply_damage(82.0)
	await get_tree().create_timer(1.5).timeout
	RenderingServer.force_draw()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/low-life.png" % _out_dir)

func _place_hands() -> void:
	var player := _main.get_node("Player") as Node3D
	var left := player.get_node("LeftHandController") as Node3D
	var right := player.get_node("RightHandController") as Node3D
	left.set_physics_process(false)
	right.set_physics_process(false)
	for hand in [left, right]:
		var pointer := hand.get_node_or_null("MenuPointer") as Node3D
		if pointer:
			pointer.process_mode = Node.PROCESS_MODE_DISABLED
			pointer.visible = false
	# A guard: fists forward at chest height, knuckles toward the camera's view.
	left.transform = Transform3D(Basis.from_euler(Vector3(0.35, -0.25, 0.0)), Vector3(-0.2, 1.28, -0.38))
	right.transform = Transform3D(Basis.from_euler(Vector3(0.35, 0.25, 0.0)), Vector3(0.2, 1.28, -0.38))

func _shot(file_name: String, from: Vector3, look: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(look, Vector3.UP)
	await _settle(4)
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out_dir, file_name])

func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame
