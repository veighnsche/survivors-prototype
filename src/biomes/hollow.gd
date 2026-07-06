class_name HollowBiome
extends Biome
## The endless tide, above and below. The swarm shrugs magic; minions and zones
## grind it down.


func _init() -> void:
	id = "hollow"
	display_name = "The Hollow"
	color = Color("#9A54E4")
	family = "summon"
	roster = [
		{"arch": "mite", "w": 0.6},
		{"arch": "broodmother", "w": 0.2},
		{"arch": "tunneler", "w": 0.2},
	]
	resists = {"arcane": 0.8, "physical": 1.5}
