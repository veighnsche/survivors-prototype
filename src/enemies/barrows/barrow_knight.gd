class_name BarrowKnight
extends Enemy
## Barrows tank. Its raised shield blocks half of all RANGED damage — get close.

const SHIELD_RANGE := 140.0


func _init() -> void:
	arch = "barrow_knight"
	display_name = "Barrow-Knight"
	base_hp = 30.0
	speed = 42.0
	damage = 13.0
	radius = 20.0
	xp_tier = "large"


func _incoming(amount: float, _dtype: String) -> float:
	if target != null and is_instance_valid(target):
		if global_position.distance_to(target.global_position) > SHIELD_RANGE:
			_logmech("barrow_knight:shield_block")
			return amount * 0.5
	return amount


func _draw_marks() -> void:
	draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 14, Color(0, 0, 0, 0.3), 3.0)
	# the raised shield (blocks ranged damage)
	var fd := to_player().normalized() if target != null and is_instance_valid(target) else Vector2.RIGHT
	draw_arc(Vector2.ZERO, radius + 4.0, fd.angle() - 0.8, fd.angle() + 0.8, 10, Color(0.9, 0.9, 0.95, 0.8), 3.5)
