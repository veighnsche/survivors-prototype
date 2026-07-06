class_name HealPack
extends Booster
## Restores a chunk of health on touch.

const HEAL := 40.0


func _init() -> void:
	label = "Heal"
	letter = "+"
	color = Color(0.4, 0.9, 0.45)


func _apply() -> void:
	player.heal(HEAL)
