class_name Deflect
extends Skill
## Ward T3: most enemy shots are warded off outright, and the shield thickens.


func _init() -> void:
	id = "deflect"
	display_name = "Deflect"
	desc = "Block ranged shots"
	fam = "ward"
	tier = 3


func apply(p: Player) -> void:
	p.deflect_chance = 0.6
	p.shield_max += 24.0
