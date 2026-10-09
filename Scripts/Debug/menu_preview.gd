extends Node2D

var _menu: VRMenuPanel
var _page: int = 0

func _ready() -> void:
	_menu = preload("res://Scenes/UI/vr_menu_panel.tscn").instantiate() as VRMenuPanel
	add_child(_menu)
	_menu.action_requested.connect(_on_action)
	_menu.show_main_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_menu.show_main_menu()
			KEY_2:
				_menu.show_tutorial(_page, _pages())
			KEY_3:
				_menu.show_settings("75%", "50%", "100%", false, false)
			KEY_4:
				_menu.show_pause()
			KEY_5:
				_menu.show_results(&"victory", 12840, "Chen: It knows your resonance now. This was the opening move. Not the end of the war.", "DOUBLE BREACH", 252.0, 280.0)

func _on_action(action: StringName) -> void:
	match action:
		&"training":
			_page = 0
			_menu.show_tutorial(_page, _pages())
		&"tutorial_continue":
			_page = mini(_page + 1, _pages().size() - 1)
			_menu.show_tutorial(_page, _pages())
		&"tutorial_back":
			_page = maxi(_page - 1, 0)
			_menu.show_tutorial(_page, _pages())
		&"tutorial_exit", &"settings_back", &"results_menu":
			_menu.show_main_menu()
		&"settings":
			_menu.show_settings("75%", "50%", "100%", false, false)
		&"settings_flashes_off":
			_menu.show_settings("75%", "50%", "100%", false, false)
		&"settings_flashes_on":
			_menu.show_settings("75%", "50%", "100%", true, false)
		&"reset_progress":
			_menu.show_reset_confirmation()
		&"reset_cancel", &"reset_confirm":
			_menu.show_settings("75%", "50%", "100%", false, false)

func _pages() -> Array[Dictionary]:
	return [
		{
			"eyebrow": "MODULE 01 // SAFE PLAY SPACE",
			"title": "CENTER YOUR OPERATING AREA",
			"body": "Phantom Fray is stationary. Stand or sit inside the cyan floor ring. Clear enough room to punch, duck, and take a small step left or right.",
			"callout": "Hold the Meta button to recenter the world in front of you. This lesson waits until you select Continue.",
			"color": Color("56dff5"),
		},
		{
			"eyebrow": "MODULE 02 // ERM GAUNTLETS",
			"title": "GRIP, THEN STRIKE",
			"body": "Hold the controller grip while punching. The Ethereal Resonance Matrix activates only when your fist is moving at combat speed.",
			"callout": "Short jabs, hooks, and uppercuts all work. Never punch outside your boundary.",
			"color": Color("5cf2ae"),
		},
	]
