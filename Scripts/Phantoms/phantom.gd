extends CharacterBody3D

# Signal emitted when the phantom is hit
signal phantom_hit(points)

# Health and score
var health = 3
var score = 0

func _ready():
    # Start with idle animation
    $AnimationPlayer.play("idle")
    
    # Connect collision signal
    $Area3D.body_entered.connect(_on_Area3D_body_entered)

func _on_Area3D_body_entered(body):
    if body.is_in_group("PlayerPunch"):
        health -= 1
        if health <= 0:
            emit_signal("phantom_hit", calculate_points())
            $AnimationPlayer.play("death")
            # Remove phantom after death animation
            await get_tree().create_timer(1.0).timeout
            queue_free()
        else:
            $AnimationPlayer.play("hit_reaction")

func calculate_points():
    # Implement your scoring logic here
    return 100  # Placeholder value
