extends "res://Scripts/Player/hand_collision.gd"

var is_grabbing = false

func _ready():
	# Call parent _ready function first
	super()
	
	# Connect the button_pressed signal
	button_pressed.connect(_on_button_pressed)

func _on_button_pressed(button_name: String):
	if button_name == "grip_click":
		is_grabbing = true
		print("Grabbing with ", name)
	elif button_name == "trigger_click":
		print("Interacting with ", name)

func _process(delta):
	if is_grabbing:
		# Check if the grip button is released
		if !is_button_pressed("grip_click"):
			is_grabbing = false
			print("Released grab with ", name)
