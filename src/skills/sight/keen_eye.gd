class_name KeenEye
extends Skill
## Sight T1: crits. Critical hits land as "precise" damage — what flyers fear.


func _init() -> void:
	id = "keen"
	display_name = "Keen Eye"
	desc = "+15% crit chance"
	fam = "sight"
	tier = 1


func apply(p: Player) -> void:
	p.crit_chance += 0.15
