class_name Siphon
extends Skill
## Drain T1: a share of all damage dealt comes back as health.


func _init() -> void:
	id = "siphon"
	display_name = "Siphon"
	desc = "+10% lifesteal"
	fam = "drain"
	tier = 1


func apply(p: Player) -> void:
	p.siphon_pct += 0.06
