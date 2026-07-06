class_name WallBody
extends StaticBody2D
## A biome border rampart — its own look (stone coursework with a lit top edge),
## tinted by the biome it belongs to. Distinct from ObstacleBody buildings.

var size := Vector2(100, 100)
var tint := Color(0.4, 0.2, 0.2)


func _ready() -> void:
	z_index = 2
	collision_layer = 16
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	var base := tint.darkened(0.35)
	var mortar := tint.darkened(0.6)
	var top := tint.lightened(0.22)

	draw_rect(r, base)
	# stone coursework: horizontal mortar lines + staggered verticals
	var rows := 4
	var row_h := size.y / rows
	for i in range(1, rows):
		var y := -size.y * 0.5 + i * row_h
		draw_line(Vector2(-size.x * 0.5, y), Vector2(size.x * 0.5, y), mortar, 2.0)
	for i in rows:
		var y0 := -size.y * 0.5 + i * row_h
		var stagger := (size.x * 0.25) if i % 2 == 0 else 0.0
		var x := -size.x * 0.5 + size.x * 0.25 + stagger
		while x < size.x * 0.5:
			draw_line(Vector2(x, y0), Vector2(x, y0 + row_h), mortar, 2.0)
			x += size.x * 0.5
	# lit crown so the rampart reads as raised
	draw_rect(Rect2(-size.x * 0.5, -size.y * 0.5, size.x, 7.0), top)
	draw_rect(r, mortar, false, 1.5)
