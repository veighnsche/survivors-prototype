class_name ControlFamily
extends Family
## Enchantment/transmutation: slows, fear, shatter. Taught by the Wilds.


func _init() -> void:
	id = "control"
	display_name = "Control"
	color = Color("#3FCDE0")
	skills = [
		preload("res://src/skills/control/frost_pulse.gd"),
		preload("res://src/skills/control/shatter.gd"),
		preload("res://src/skills/control/dread.gd"),
	]
	minors = [
		{"id": "control_chill", "name": "Deeper Chill", "desc": "Stronger slow, +pulse damage", "max": 4},
		{"id": "control_wider", "name": "Wider Pulse", "desc": "+20% pulse radius", "max": 4},
	]


func apply_minor(p: Player, id: String) -> bool:
	match id:
		"control_chill":
			p.chill_level += 1
			p.fam_power.control *= 1.15
		"control_wider":
			p.control_radius_mult *= 1.20
		_:
			return false
	return true
