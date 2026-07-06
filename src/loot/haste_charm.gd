class_name HasteCharm
extends Booster
## Temporary boost: the caster moves much faster.


func _init() -> void:
	label = "Haste"
	letter = "H"
	color = Color(0.3, 0.9, 0.95)


func _apply() -> void:
	player.boost_speed = 1.4
	player.boost_speed_t = Config.BOOST_DURATION
	player.boost_flash()
