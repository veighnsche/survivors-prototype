class_name SpiritDart
extends BoltCantrip
## Summon's cantrip: cheap, rapid physical darts — the swarm-grinder's rhythm.


func _init() -> void:
	id = "summon"
	display_name = "Spirit Dart"
	cooldown = 0.32
	damage = 3.2
	reach = 340.0
	speed = 480.0
	dtype = "physical"
