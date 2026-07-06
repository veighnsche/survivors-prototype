class_name CragspireBiome
extends Biome
## The sky is the threat. Flyers elude generic fire; precise crits swat them.


func _init() -> void:
	id = "cragspire"
	display_name = "Cragspire"
	color = Color("#4C8DF0")
	family = "sight"
	roster = [
		{"arch": "gale", "w": 0.55},
		{"arch": "roc", "w": 0.25},
		{"arch": "diver", "w": 0.2},
	]
	resists = {"arcane": 0.7, "precise": 1.6}


## Jagged rock spikes.
func draw_obstacle(ob: ObstacleBody) -> void:
	var edge := ob.color.lightened(0.25)
	var pts := PackedVector2Array([
		Vector2(-ob.size.x * 0.5, ob.size.y * 0.5), Vector2(-ob.size.x * 0.15, -ob.size.y * 0.5),
		Vector2(ob.size.x * 0.2, -ob.size.y * 0.15), Vector2(ob.size.x * 0.5, ob.size.y * 0.5)])
	ob.draw_colored_polygon(pts, ob.color)
	ob.draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 2.0)
