class_name CommonsBiome
extends Biome
## The starting field around spawn — the melee rush school: pressure at every
## speed. Melts to Blast.


func _init() -> void:
	id = "commons"
	display_name = "The Commons"
	color = Color("#E2493B")
	family = "blast"
	roster = [
		{"arch": "husk", "w": 0.55},
		{"arch": "stray", "w": 0.25},
		{"arch": "pouncer", "w": 0.2},
	]
	resists = {"arcane": 1.2}
	weight = 0.20
