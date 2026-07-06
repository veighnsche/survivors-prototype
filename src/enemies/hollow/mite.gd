class_name Mite
extends Enemy
## Hollow chaff: harmless alone, lethal as a tide. Frenzy-sprints when close.

const FRENZY_RANGE := 160.0
const FRENZY_SPEED := 1.6

var _sprint := false


func _init() -> void:
	arch = "mite"
	display_name = "Mite"
	base_hp = 1.5
	speed = 85.0
	damage = 3.0
	radius = 6.0
	xp_tier = "small"


func _brain(_delta: float) -> Vector2:
	var to_p := to_player()
	var s := to_p.length() < FRENZY_RANGE
	if s and not _sprint:
		_logmech("mite:frenzy")
	_sprint = s
	return to_p.normalized()


func _state_speed() -> float:
	return FRENZY_SPEED if _sprint else 1.0
