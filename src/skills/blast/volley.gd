class_name Volley
extends Skill
## Blast T2: every basic attack looses one more bolt.


func _init() -> void:
	id = "volley"
	display_name = "Volley"
	desc = "+1 bolt on basic attacks"
	fam = "blast"
	tier = 2


func apply(p: Player) -> void:
	p.bolt_count += 1
