class_name Thorns
extends Skill
## Ward T2: contact damage bites back.


func _init() -> void:
	id = "thorns"
	display_name = "Thorns"
	desc = "Reflect contact damage"
	fam = "ward"
	tier = 2


func apply(p: Player) -> void:
	p.thorns_damage = 9.0
