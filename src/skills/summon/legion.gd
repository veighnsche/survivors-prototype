class_name Legion
extends Wisp
## Summon T3: a second wisp joins the volley (and takes over as its owner).


func _init() -> void:
	id = "legion"
	display_name = "Legion"
	desc = "A second wisp"
	fam = "summon"
	tier = 3


func apply(p: Player) -> void:
	p.wisp_count = 2
	p.wisp_ticker = self
