extends Node2D

var _menu: VRMenuPanel

func _ready() -> void:
	_menu = preload("res://Scenes/UI/vr_menu_panel.tscn").instantiate() as VRMenuPanel
	add_child(_menu)
	_menu.action_requested.connect(_on_action)
	_menu.show_main_menu("NEXT • OP-01 FIRST LIGHT • 2 TO 4 MIN", true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_menu.show_main_menu("NEXT • OP-01 FIRST LIGHT • 2 TO 4 MIN", true)
			KEY_2:
				_menu.show_training_complete("NEXT • OP-01 FIRST LIGHT • 2 TO 4 MIN")
			KEY_3:
				_menu.show_settings("75%", "50%", "100%", false, false)
			KEY_4:
				_menu.show_pause(true)
			KEY_5:
				_menu.show_results(&"victory", 12840, "Chen: It knows your resonance now. This was the opening move. Not the end of the war.", "DOUBLE BREACH", 252.0, 280.0)
			KEY_6:
				_menu.show_results(&"defeat", 4120, "Chen: The matrix drank you before the seal. Learn the pattern. Then go back in.", "", 0.0, 0.0, "STANDARD", true)

func _on_action(action: StringName) -> void:
	match action:
		&"training", &"training_replay":
			_menu.show_training_complete("NEXT • OP-01 FIRST LIGHT • 2 TO 4 MIN")
		&"training_menu", &"settings_back", &"results_menu":
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

