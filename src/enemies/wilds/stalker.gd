class_name Stalker
extends Enemy
## Wilds ghost: phases out at range (bolts pass through it), solid up close —
## you can't kill it from afar, you must let it come.

const PHASE_RANGE := 220.0

var _phased := false


func _init() -> void:
	arch = "stalker"
	display_name = "Stalker"
	base_hp = 14.0
	speed = 118.0
	damage = 8.0
	radius = 12.0
	xp_tier = "medium"


func _brain(_delta: float) -> Vector2:
	var to_p := to_player()
	var was := _phased
	_phased = to_p.length() > PHASE_RANGE
	modulate.a = 0.28 if _phased else 1.0
	if _phased and not was:
		_logmech("stalker:phase")
	return to_p.normalized()


func _incoming(amount: float, _dtype: String) -> float:
	if _phased:
		_logmech("stalker:phase_immune")
		return 0.0  # bolts pass right through it
	return amount
