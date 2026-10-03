extends ResonancePhantom

func _ready() -> void:
	variant_id = &"yellow"
	required_hand = &"left"
	phantom_color = Color(1.0, 0.78, 0.08, 0.9)
	lateral_bias = -1.0
	height_bias = 0.1
	lateral_reach_min = 0.12
	lateral_reach_max = 0.52
	height_jitter = 0.34
	arc_scale = 3.6
	acceleration = 2.3
	engage_distance = 2.5
	pattern_telegraph_seconds = 0.85
	pattern_commit_speed = 6.1
	pattern_commit_seconds = 0.5
	super()
