class_name Shatter
extends Skill
## Control T2: slowed foes take bonus damage from everything. The bonus lives
## here; the player's damage funnel reads it when has_shatter is set.

const BONUS := 1.45


func _init() -> void:
	id = "shatter"
	display_name = "Shatter"
	desc = "Slowed foes take +45%"
	fam = "control"
	tier = 2


func apply(p: Player) -> void:
	p.has_shatter = true
