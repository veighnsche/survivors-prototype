class_name Essence
extends Node2D
## A mote of school-colored essence dropped by a biome's enemies. Collecting it
## feeds that family's Insight — the world teaching you the counter it just
## used against you.

var family := "blast"
var value := 2.0
var player: Node2D
var game

var attracting := false
var collected := false
var _spin := 0.0


func _ready() -> void:
	z_index = 2
	_spin = randf() * TAU
	queue_redraw()


func _process(delta: float) -> void:
	if collected:
		return
	_spin += delta * 3.0
	queue_redraw()
	if player != null and is_instance_valid(player):
		var d := global_position.distance_to(player.global_position)
		if d <= Config.ESSENCE_COLLECT_DIST:
			collected = true
			if game != null:
				game.add_insight(family, value)
			queue_free()
			return
		if attracting or d <= player.pickup_radius:
			attracting = true
			global_position = global_position.move_toward(player.global_position, Config.ESSENCE_ATTRACT_SPEED * delta)


func _draw() -> void:
	var c: Color = Config.FAMILY_COLORS[family]
	# a slowly spinning diamond, clearly distinct from round gems/coins
	var pts := PackedVector2Array()
	for i in 4:
		var a := _spin + i * TAU / 4.0
		pts.append(Vector2(cos(a), sin(a)) * 7.0)
	draw_colored_polygon(pts, c)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.7), 1.5)
