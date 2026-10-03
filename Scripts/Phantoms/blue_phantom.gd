extends ResonancePhantom

func _ready() -> void:
	variant_id = &"blue"
	required_hand = &"right"
	phantom_color = Color(0.05, 0.55, 1.0, 0.9)
	lateral_bias = 1.0
	height_bias = -0.14
	lateral_reach_min = 0.14
	lateral_reach_max = 0.48
	height_jitter = 0.3
	engage_distance = 2.45
	pattern_telegraph_seconds = 0.8
	pattern_commit_speed = 6.4
	pattern_commit_seconds = 0.48
	super()
