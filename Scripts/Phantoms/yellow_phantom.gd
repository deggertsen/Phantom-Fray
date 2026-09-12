extends ResonancePhantom

func _ready() -> void:
	variant_id = &"yellow"
	required_hand = &"left"
	phantom_color = Color(1.0, 0.78, 0.08, 0.9)
	super()
