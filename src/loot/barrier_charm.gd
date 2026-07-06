class_name BarrierCharm
extends Booster
## Grants a barrier that absorbs damage — no timer, it lasts until spent.

const BARRIER := 40.0  # how much one charm absorbs


func _init() -> void:
	label = "Barrier"
	letter = "S"
	color = Color(0.92, 0.9, 0.5)


func _apply() -> void:
	player.bonus_shield += BARRIER
	player.boost_flash()
