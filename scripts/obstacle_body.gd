class_name ObstacleBody
extends StaticBody2D
## A solid piece of terrain the player collides with. Its look comes from the
## biome it sits in — ruined block (Commons), thorn hedge (Thornreach), tomb
## (Barrows) — so the terrain itself reads which region you're in.

var size := Vector2(80, 80)
var style := "block"
var color := Color(0.28, 0.28, 0.34)


func _ready() -> void:
	z_index = 1
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
	var edge := color.lightened(0.25)
	match style:
		"tomb":
			# a headstone: rounded-top slab
			draw_rect(Rect2(-size.x * 0.5, -size.y * 0.35, size.x, size.y * 0.85), color)
			draw_circle(Vector2(0, -size.y * 0.35), size.x * 0.5, color)
			draw_arc(Vector2(0, -size.y * 0.35), size.x * 0.5, PI, TAU, 16, edge, 2.0)
			draw_line(Vector2(-size.x * 0.2, 0), Vector2(size.x * 0.2, 0), edge, 2.0)
		"hedge":
			# thorny bramble: jagged clumped fill
			draw_rect(r, color)
			for i in 5:
				var px := -size.x * 0.4 + i * size.x * 0.2
				draw_line(Vector2(px, -size.y * 0.5), Vector2(px + 6, -size.y * 0.62), edge, 2.0)
			draw_rect(r, edge, false, 2.0)
		_:
			# ruined block
			draw_rect(r, color)
			draw_rect(r, edge, false, 2.0)
			draw_line(Vector2(-size.x * 0.5, size.y * 0.1), Vector2(size.x * 0.5, size.y * 0.1), Color(0, 0, 0, 0.25), 1.5)
