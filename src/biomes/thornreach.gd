class_name ThornreachBiome
extends Biome
## Layered ranged pressure. Its creatures shrug generic bolts but break on wards.


func _init() -> void:
	id = "thornreach"
	display_name = "Thornreach"
	color = Color("#E0A02E")
	family = "ward"
	roster = [
		{"arch": "slinger", "w": 0.5},
		{"arch": "bramble", "w": 0.25},
		{"arch": "volleyer", "w": 0.25},
	]
	resists = {"arcane": 0.8, "reflect": 1.6}


## Thorn hedges: jagged clumped fill with bramble spikes along the top.
func draw_obstacle(ob: ObstacleBody) -> void:
	var r := Rect2(-ob.size * 0.5, ob.size)
	var edge := ob.color.lightened(0.25)
	ob.draw_rect(r, ob.color)
	for i in 5:
		var px := -ob.size.x * 0.4 + i * ob.size.x * 0.2
		ob.draw_line(Vector2(px, -ob.size.y * 0.5), Vector2(px + 6, -ob.size.y * 0.62), edge, 2.0)
	ob.draw_rect(r, edge, false, 2.0)
