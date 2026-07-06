class_name FrenzyCharm
extends Booster
## Temporary boost: casts come twice as fast.


func _init() -> void:
	label = "Frenzy"
	letter = "F"
	color = Color(0.95, 0.4, 0.32)


func _apply() -> void:
	player.boost_rate = 0.5
	player.boost_rate_t = Config.BOOST_DURATION
	player.boost_flash()
