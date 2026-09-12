extends Node

var _menu: VRMenuPanel

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/menu-states"))
	_menu = preload("res://Scenes/UI/vr_menu_panel.tscn").instantiate() as VRMenuPanel
	add_child(_menu)
	await _capture_main()
	await _capture_tutorial()
	await _capture_settings()
	await _capture_pause()
	await _capture_results()
	print("MENU CAPTURE COMPLETE")
	get_tree().quit()

func _capture_main() -> void:
	_menu.show_main_menu()
	await _capture("main-menu.png")

func _capture_tutorial() -> void:
	_menu.show_tutorial(0, [{
		"eyebrow": "MODULE 01 // SAFE PLAY SPACE",
		"title": "CENTER YOUR OPERATING AREA",
		"body": "Phantom Fray is stationary. Stand or sit inside the cyan floor ring. Clear enough room to punch, duck, and take a small step left or right.",
		"callout": "Hold the Meta button to recenter the world in front of you. This lesson waits until you select Continue.",
		"color": Color("56dff5"),
	}])
	await _capture("tutorial.png")

func _capture_settings() -> void:
	_menu.show_settings("-8 dB", "100%", false, false)
	await _capture("settings.png")

func _capture_pause() -> void:
	_menu.show_pause()
	await _capture("pause.png")

func _capture_results() -> void:
	_menu.show_results(&"victory", 12840)
	await _capture("results.png")

func _capture(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://reports/menu-states/%s" % file_name))
