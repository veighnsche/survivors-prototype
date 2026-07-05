class_name Gem
extends Node2D
## An XP drop. Sits on the floor accruing idle_time (used for merging), flies to
## the player once inside pickup radius, grants XP on contact.

var value := 1
var player: Node2D
var game  # the run director, for add_xp()

var idle_time := 0.0
var attracting := false
var collected := false


func _ready() -> void:
	add_to_group("gems")
	z_index = 2
	queue_redraw()


func _process(delta: float) -> void:
	if collected:
		return
	if player != null and is_instance_valid(player):
		var d := global_position.distance_to(player.global_position)
		if d <= Config.GEM_COLLECT_DIST:
			_collect()
			return
		if attracting or d <= player.pickup_radius:
			attracting = true
			global_position = global_position.move_toward(player.global_position, Config.GEM_ATTRACT_SPEED * delta)
			return
	idle_time += delta


## Merge another gem into this one (called by the run director's merge pass).
func absorb(other: Gem) -> void:
	value += other.value
	other.collected = true
	other.queue_free()
	idle_time = 0.0
	queue_redraw()


func _collect() -> void:
	if collected:
		return
	collected = true
	if game != null:
		game.add_xp(value)
	queue_free()


func _tier() -> int:
	if value >= 25:
		return 2
	elif value >= 5:
		return 1
	return 0


func _draw() -> void:
	var t := _tier()
	# small=cyan, medium=green, large=purple (kept off gold so it doesn't read as coins)
	var colors := [Color(0.3, 0.85, 0.95), Color(0.45, 0.9, 0.4), Color(0.72, 0.42, 1.0)]
	var radii := [5.0, 7.0, 10.0]
	var r: float = radii[t] + min(6.0, value * 0.05)
	draw_circle(Vector2.ZERO, r, colors[t])
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 1.5)
