class_name Gem
extends Node2D
## THE drop: a biome-colored gem carrying both XP and family Insight — kill a
## creature, absorb a shard of what it was. Sits on the floor accruing idle_time
## (merging), flies to the player in pickup radius.

const ATTRACT_SPEED := 580.0

var value := 1            # XP
var insight_value := 0.0  # family Insight
var family := ""          # which family this feeds (from the creature's biome)
var player: Node2D
var game

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


## Merge another gem into this one (both XP and insight combine).
func absorb(other: Gem) -> void:
	value += other.value
	insight_value += other.insight_value
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
		if family != "" and insight_value > 0.0:
			game.add_insight(family, insight_value)
	queue_free()


func _tier() -> int:
	if value >= 25:
		return 2
	elif value >= 5:
		return 1
	return 0


func _draw() -> void:
	var c: Color = Config.FAMILY_COLORS.get(family, Color(0.3, 0.85, 0.95))
	var radii := [5.0, 7.0, 10.0]
	var r: float = radii[_tier()] + min(6.0, value * 0.05)
	draw_circle(Vector2.ZERO, r, c)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, Color(1, 1, 1, 0.7), 1.5)
