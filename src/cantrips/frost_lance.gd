class_name FrostLance
extends BoltCantrip
## Control's cantrip: a fast lance that punches through one extra body.


func _init() -> void:
	id = "control"
	display_name = "Frost Lance"
	cooldown = 0.70
	damage = 6.0
	reach = 380.0
	speed = 560.0
	dtype = "frost"
	pierce = 1
