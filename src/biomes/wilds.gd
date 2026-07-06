class_name WildsBiome
extends Biome
## Fast packs with a leader. The beasts evade bolts but freeze solid.


func _init() -> void:
	id = "wilds"
	display_name = "The Wilds"
	color = Color("#3FCDE0")
	family = "control"
	roster = [
		{"arch": "prowler", "w": 0.5},
		{"arch": "stalker", "w": 0.3},
		{"arch": "howler", "w": 0.2},
	]
	resists = {"arcane": 0.85, "frost": 1.6}


## Trees: trunk + broad canopy blob.
func draw_obstacle(ob: ObstacleBody) -> void:
	var edge := ob.color.lightened(0.25)
	ob.draw_rect(Rect2(-ob.size.x * 0.12, 0, ob.size.x * 0.24, ob.size.y * 0.5), ob.color.darkened(0.3))
	ob.draw_circle(Vector2(0, -ob.size.y * 0.15), ob.size.x * 0.48, ob.color)
	ob.draw_arc(Vector2(0, -ob.size.y * 0.15), ob.size.x * 0.48, 0.0, TAU, 20, edge, 2.0)
