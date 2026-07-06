class_name ObstacleBody
extends StaticBody2D
## A solid piece of terrain the player collides with. Its LOOK is owned by the
## biome it stands in (Biome.draw_obstacle) — a tomb in the Barrows, a hedge in
## Thornreach — so the terrain itself reads which region you're in.

var size := Vector2(80, 80)
var color := Color(0.28, 0.28, 0.34)
var biome: Biome  # paints this body; null falls back to the base block


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
	if biome != null:
		biome.draw_obstacle(self)
	else:
		var r := Rect2(-size * 0.5, size)
		draw_rect(r, color)
		draw_rect(r, color.lightened(0.25), false, 2.0)
