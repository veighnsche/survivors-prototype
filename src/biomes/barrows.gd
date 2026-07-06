class_name BarrowsBiome
extends Biome
## Attrition land: tanks, tides, and things that don't stay dead. Resists burst,
## rots fast under necrotic.


func _init() -> void:
	id = "barrows"
	display_name = "The Barrows"
	color = Color("#6FB03A")
	family = "drain"
	roster = [
		{"arch": "barrow_knight", "w": 0.45},
		{"arch": "grave_swarm", "w": 0.35},
		{"arch": "bonepile", "w": 0.2},
	]
	resists = {"arcane": 0.65, "necrotic": 1.6}


## Headstones: a rounded-top slab with an epitaph line.
func draw_obstacle(ob: ObstacleBody) -> void:
	var edge := ob.color.lightened(0.25)
	ob.draw_rect(Rect2(-ob.size.x * 0.5, -ob.size.y * 0.35, ob.size.x, ob.size.y * 0.85), ob.color)
	ob.draw_circle(Vector2(0, -ob.size.y * 0.35), ob.size.x * 0.5, ob.color)
	ob.draw_arc(Vector2(0, -ob.size.y * 0.35), ob.size.x * 0.5, PI, TAU, 16, edge, 2.0)
	ob.draw_line(Vector2(-ob.size.x * 0.2, 0), Vector2(ob.size.x * 0.2, 0), edge, 2.0)
