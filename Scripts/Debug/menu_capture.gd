extends Node

var _menu: VRMenuPanel

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/menu-states"))
	# The panel is drawn at the headset viewport size; the default 1152x648 window cut off its bottom rows.
	get_window().size = Vector2i(1280, 780)
	_menu = preload("res://Scenes/UI/vr_menu_panel.tscn").instantiate() as VRMenuPanel
	add_child(_menu)
	await _capture_main()
	await _capture_operations()
	await _capture_tutorial()
	await _capture_settings()
	await _capture_pause()
	await _capture_results()
	print("MENU CAPTURE COMPLETE")
	get_tree().quit()

func _capture_main() -> void:
	_menu.show_main_menu()
	await _capture("main-menu.png")
	var profile := _two_cleared_profile()
	_menu.show_main_menu(MissionCatalog.deploy_detail(profile))
	await _capture("main-menu-next.png")
	profile.free()

func _capture_operations() -> void:
	var profile := _two_cleared_profile()
	_menu.show_operations(MissionCatalog.operation_entries(profile))
	await _capture("operations.png")
	profile.free()

## A settings object with the first two operations sealed and timed, never saved to disk.
func _two_cleared_profile() -> Node:
	var profile: Node = load("res://Scripts/Core/game_settings.gd").new()
	profile.cleared_missions = PackedStringArray(["first_light", "widen_the_ring"])
	profile.best_times = {"first_light": 94.0, "widen_the_ring": 342.0}
	return profile

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
	_menu.show_settings("75%", "50%", "100%", false, false)
	await _capture("settings.png")
	_menu.show_settings("75%", "50%", "100%", false, false, true)
	await _capture("settings-own-music.png")

func _capture_pause() -> void:
	_menu.show_pause()
	await _capture("pause.png")

func _capture_results() -> void:
	_menu.show_results(&"victory", 12840, "Chen: It knows your resonance now. This was the opening move. Not the end of the war.", "DOUBLE BREACH  •  %s" % MissionCatalog.expected_minutes_text(MissionCatalog.get_mission("double_breach")), 252.0, 280.0)
	await _capture("results.png")

func _capture(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://reports/menu-states/%s" % file_name))
