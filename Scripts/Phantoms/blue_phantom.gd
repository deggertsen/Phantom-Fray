extends ResonancePhantom

func _ready() -> void:
	variant_id = &"blue"
	required_hand = &"right"
	phantom_color = Color(0.05, 0.55, 1.0, 0.9)
	super()
