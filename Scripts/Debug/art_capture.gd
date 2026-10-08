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
	await _hits()
	print("ART CAPTURE COMPLETE: %s" % _out_dir)
	get_tree().quit()

func _quiet_main() -> void:
	for path in ["VRMenuPresenter", "GameFlowController", "RoundController", "MusicManager", "MusicIntensityController", "PerformanceMonitor"]:
		var node := _main.get_node_or_null(path)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if node is Node3D:
				(node as Node3D).visible = false

func _spawn(id: String, at: Vector3) -> void:
	var phantom := (load(PHANTOMS[id]) as PackedScene).instantiate() as Node3D
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
	_phantoms[id] = phantom

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
