class_name SightFamily
extends Family
## Divination: crits, marks, foresight. Taught by Cragspire.


func _init() -> void:
	id = "sight"
	display_name = "Sight"
	color = Color("#4C8DF0")
	skills = [
		preload("res://src/skills/sight/keen_eye.gd"),
		preload("res://src/skills/sight/mark.gd"),
		preload("res://src/skills/sight/foresight.gd"),
	]
	minors = [
		{"id": "sight_keener", "rebuild": true, "name": "Keener Eye", "desc": "+6% crit chance", "max": 5},
		{"id": "sight_deadly", "name": "Deadly Precision", "desc": "+40% crit damage", "max": 4},
	]


func apply_minor(p: Player, id: String) -> bool:
	match id:
		"sight_keener":
			p.crit_chance += 0.06
		"sight_deadly":
			p.crit_mult += 0.4
		_:
			return false
	return true
