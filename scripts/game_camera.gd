class_name GameCamera
extends Camera2D
## Trauma-based screen shake. Call add_trauma(0..1); it decays each frame and the
## offset scales with trauma squared so small hits barely nudge, big hits kick.

var trauma := 0.0
var max_offset := 15.0
var decay := 1.6


func add_trauma(amount: float) -> void:
	trauma = min(1.0, trauma + amount)


func _process(delta: float) -> void:
	if trauma <= 0.0:
		offset = Vector2.ZERO
		return
	trauma = max(0.0, trauma - decay * delta)
	var amt := trauma * trauma
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * max_offset * amt
