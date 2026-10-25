extends Node2D

## The single panel's views on the desktop. The city map and results are wrap panels: see
## menu_capture.gd, or play_capture.gd for them in the arena.

var _menu: VRMenuPanel

func _ready() -> void:
	_menu = preload("res://Scenes/UI/vr_menu_panel.tscn").instantiate() as VRMenuPanel
	add_child(_menu)
	_menu.action_requested.connect(_on_action)
	_menu.show_training_complete("NEXT • OP-01 FIRST LIGHT • 2 TO 4 MIN")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2:
				_menu.show_training_complete("NEXT • OP-01 FIRST LIGHT • 2 TO 4 MIN")
			KEY_3:
				_menu.show_settings("75%", "50%", "100%", false, false)
			KEY_4:
				_menu.show_pause(true)
			KEY_5:
				_menu.show_pause()
			KEY_6:
				_menu.show_abort_confirmation()

func _on_action(action: StringName) -> void:
	match action:
		&"training_replay", &"training_menu", &"settings_back":
			_menu.show_training_complete("NEXT • OP-01 FIRST LIGHT • 2 TO 4 MIN")
		&"pause_settings":
			_menu.show_settings("75%", "50%", "100%", false, true)
		&"settings_flashes_off":
			_menu.show_settings("75%", "50%", "100%", false, false)
		&"settings_flashes_on":
			_menu.show_settings("75%", "50%", "100%", true, false)
		&"reset_progress":
			_menu.show_reset_confirmation()
		&"reset_cancel", &"reset_confirm":
			_menu.show_settings("75%", "50%", "100%", false, false)
