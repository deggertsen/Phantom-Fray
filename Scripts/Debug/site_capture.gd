extends Node

## Desktop stills of every breach site, with a rift and one phantom of each colour in front of
## it so readability can be judged against each backdrop.
## Run: Godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/site_capture.tscn
## Writes PNGs to res://reports/sites/<label>/ (label from --art-label=<name>, default "current").
## --site=<id> captures one site (or district) only.

const PHANTOMS := {
	"yellow": ["res://Scenes/Phantoms/yellow_phantom.tscn", Vector3(-1.6, 1.5, -6.0)],
	"blue": ["res://Scenes/Phantoms/blue_phantom.tscn", Vector3(1.4, 1.75, -7.5)],
	"green": ["res://Scenes/Phantoms/green_phantom.tscn", Vector3(-3.4, 1.4, -10.0)],
	"pink": ["res://Scenes/Phantoms/pink_phantom.tscn", Vector3(3.2, 1.55, -10.5)],
}

var _out_dir: String
var _camera: Camera3D
var _main: Node3D

func _ready() -> void:
	var label := "current"
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-label="):
			label = arg.trim_prefix("--art-label=")
		elif arg.begins_with("--site="):
			only = arg.trim_prefix("--site=")
	_out_dir = ProjectSettings.globalize_path("res://reports/sites/%s" % label)
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	add_child(_main)
	await get_tree().process_frame
	for path in ["VRMenuPresenter", "GameFlowController", "RoundController", "MusicManager", "MusicIntensityController", "PerformanceMonitor", "XRLifecycleController"]:
		var node := _main.get_node_or_null(path)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if node is Node3D:
				(node as Node3D).visible = false

	_camera = Camera3D.new()
	_camera.fov = 90.0
	_main.add_child(_camera)
	_camera.make_current()

	var rift := (load("res://Scenes/Rifts/rift_manager.tscn") as PackedScene).instantiate() as Node3D
	_main.add_child(rift)
	rift.global_position = Vector3(1.0, 1.6, -13.0)
	rift.look_at(Vector3(0.0, 1.6, 0.0), Vector3.UP)
	for id in PHANTOMS:
		var phantom := (load(PHANTOMS[id][0]) as PackedScene).instantiate() as Node3D
		_main.get_node("PhantomContainer").add_child(phantom)
		var at: Vector3 = PHANTOMS[id][1]
		phantom.global_position = at
		phantom.set_physics_process(false)
		phantom.global_transform.basis = Basis(Vector3.UP, atan2(-at.x, -at.z))
		if phantom.has_method("place_sweet_spot"):
			phantom.place_sweet_spot(0)
		if phantom.has_method("_update_lane"):
			phantom._update_lane(1.0)

	var arena := _main.get_node("ArenaPresentation")
	var sites: Array = [only] if only != "" else Array(BreachSites.site_ids())
	for site in sites:
		arena.call("apply_site", site)
		await _settle(20)
		await _shot("%s-front" % site, Vector3(0.0, 1.6, 0.0), Vector3(0.0, 2.2, -10.0))
		await _shot("%s-left" % site, Vector3(0.0, 1.6, 0.0), Vector3(-10.0, 2.2, 0.0))
		await _shot("%s-back" % site, Vector3(0.0, 1.6, 0.0), Vector3(0.0, 2.2, 10.0))
		await _shot("%s-right" % site, Vector3(0.0, 1.6, 0.0), Vector3(10.0, 2.2, 0.0))
		await _shot("%s-wide" % site, Vector3(26.0, 22.0, 30.0), Vector3(0.0, 2.0, -10.0))
	print("SITE CAPTURE COMPLETE: %s" % _out_dir)
	get_tree().quit()

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
