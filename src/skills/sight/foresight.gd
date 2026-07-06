class_name Foresight
extends Skill
## Sight T3: you see the hit coming — a quarter of them simply miss.


func _init() -> void:
	id = "foresight"
	display_name = "Foresight"
	desc = "25% dodge"
	fam = "sight"
	tier = 3


func apply(p: Player) -> void:
	p.dodge_chance = 0.25
