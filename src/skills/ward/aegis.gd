class_name Aegis
extends Skill
## Ward T1: a regenerating shield that soaks damage before HP.


func _init() -> void:
	id = "aegis"
	display_name = "Aegis"
	desc = "Regenerating shield"
	fam = "ward"
	tier = 1


func apply(p: Player) -> void:
	p.shield_max = 34.0
	p.shield_regen = 4.0
	p.shield_hp = p.shield_max
