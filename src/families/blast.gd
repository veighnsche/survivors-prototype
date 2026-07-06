class_name BlastFamily
extends Family
## Evocation: raw area damage. Taught by the Commons.


func _init() -> void:
	id = "blast"
	display_name = "Blast"
	color = Color("#E2493B")
	skills = [
		preload("res://src/skills/blast/nova.gd"),
		preload("res://src/skills/blast/volley.gd"),
	]
	minors = [
		{"id": "blast_hotter", "name": "Hotter Burst", "desc": "+25% blast damage", "max": 5},
		{"id": "blast_wider", "name": "Wider Burst", "desc": "+20% burst & nova radius", "max": 4},
	]


func apply_minor(p: Player, id: String) -> bool:
	match id:
		"blast_hotter":
			p.fam_power.blast *= 1.25
		"blast_wider":
			p.blast_radius_mult *= 1.20
		_:
			return false
	return true
