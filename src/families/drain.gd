class_name DrainFamily
extends Family
## Necromancy: rot and lifesteal. Taught by the Barrows.


func _init() -> void:
	id = "drain"
	display_name = "Drain"
	color = Color("#6FB03A")
	skills = [
		preload("res://src/skills/drain/siphon.gd"),
		preload("res://src/skills/drain/rot.gd"),
		preload("res://src/skills/drain/wither.gd"),
	]
	minors = [
		{"id": "drain_deeper", "name": "Deeper Rot", "desc": "+25% drain damage", "max": 5},
		{"id": "drain_thicker", "rebuild": true, "name": "Thicker Blood", "desc": "+3% lifesteal", "max": 4},
	]


func apply_minor(p: Player, id: String) -> bool:
	match id:
		"drain_deeper":
			p.fam_power.drain *= 1.25
		"drain_thicker":
			p.siphon_pct += 0.02
		_:
			return false
	return true
