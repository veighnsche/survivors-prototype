class_name WardFamily
extends Family
## Abjuration: shields, thorns, deflection. Taught by Thornreach.


func _init() -> void:
	id = "ward"
	display_name = "Ward"
	color = Color("#E0A02E")
	skills = [
		preload("res://src/skills/ward/aegis.gd"),
		preload("res://src/skills/ward/thorns.gd"),
		preload("res://src/skills/ward/deflect.gd"),
	]
	minors = [
		{"id": "ward_denser", "rebuild": true, "name": "Denser Aegis", "desc": "+12 shield, +regen", "max": 5},
		{"id": "ward_sharper", "rebuild": true, "name": "Sharper Thorns", "desc": "Thorns bite harder", "max": 4},
	]


func apply_minor(p: Player, id: String) -> bool:
	match id:
		"ward_denser":
			p.shield_max += 12.0
			p.shield_regen += 1.5
		"ward_sharper":
			p.thorns_damage = maxf(p.thorns_damage * 1.4, 4.0)
			p.fam_power.ward *= 1.15
		_:
			return false
	return true
