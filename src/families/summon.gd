class_name SummonFamily
extends Family
## Conjuration: wisps, hexfields, the grinding legion. Taught by the Hollow.


func _init() -> void:
	id = "summon"
	display_name = "Summon"
	color = Color("#9A54E4")
	skills = [
		preload("res://src/skills/summon/wisp.gd"),
		preload("res://src/skills/summon/hexfield.gd"),
		preload("res://src/skills/summon/legion.gd"),
	]
	minors = [
		{"id": "summon_fiercer", "name": "Fiercer Wisps", "desc": "+30% wisp & hex damage", "max": 5},
		{"id": "summon_eager", "name": "Eager Wisps", "desc": "Wisps fire faster", "max": 4},
	]


func apply_minor(p: Player, id: String) -> bool:
	match id:
		"summon_fiercer":
			p.fam_power.summon *= 1.30
		"summon_eager":
			p.wisp_speed_mult *= 0.85
		_:
			return false
	return true
