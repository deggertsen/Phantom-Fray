extends Node

## Plays the real game on desktop with the same keys a tester would press, and saves frames.
## Run: Godot --path . --xr-mode off --resolution 1600x900 res://Scenes/Debug/play_capture.tscn
## Writes PNGs to res://reports/play/<label>/ (label from --art-label=<name>, default "current").

var _out_dir: String
var _main: Node3D

func _ready() -> void:
	var label := "current"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-label="):
			label = arg.trim_prefix("--art-label=")
	_out_dir = ProjectSettings.globalize_path("res://reports/play/%s" % label)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Node3D
	add_child(_main)
	await _wait(1.0)
	# Stand the desktop camera at head height, as a player would be.
	var camera := _main.get_node("Player/XRCamera3D") as Node3D
	camera.position = Vector3(0.0, 1.6, 0.0)
	await _capture("01-menu")
	_press(KEY_T)
	await _wait(0.8)
	await _capture("01b-tutorial")
	_press(KEY_ESCAPE)
	await _wait(0.5)
	_press(KEY_S)
	await _wait(0.8)
	await _capture("01c-settings")
	_press(KEY_ESCAPE)
	await _wait(0.5)
	_press(KEY_ENTER)
	await _wait(0.8)
	await _capture("02-operations")
	_press(KEY_ENTER)
	await _wait(2.0)
	await _capture("03-countdown")
	await _wait(7.0)
	await _capture("04-combat")
	await _wait(5.0)
	await _capture("05-combat")
	_press(KEY_ESCAPE)
	await _wait(0.8)
	await _capture("06-pause")
	print("PLAY CAPTURE COMPLETE: %s" % _out_dir)
	get_tree().quit()

func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _capture(file_name: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out_dir, file_name])
