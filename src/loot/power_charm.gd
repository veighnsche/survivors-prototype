class_name PowerCharm
extends Booster
## Temporary boost: spells hit substantially harder.


func _init() -> void:
	label = "Power"
	letter = "P"
	color = Color(0.8, 0.42, 0.95)


func _apply() -> void:
	player.boost_dmg = 1.6
	player.boost_dmg_t = Config.BOOST_DURATION
	player.boost_flash()
