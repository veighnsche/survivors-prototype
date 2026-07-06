class_name Dread
extends Skill
## Control T3: a periodic wave of terror — nearby creatures turn and flee.

const PERIOD := 5.0
const RADIUS := 210.0
const FEAR := 1.6

var _timer := 0.0


func _init() -> void:
	id = "dread"
	display_name = "Dread"
	desc = "Periodic fear"
	fam = "control"
	tier = 3


func tick(p: Player, delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = PERIOD
	for e in p.get_tree().get_nodes_in_group("enemies"):
		if not e.is_boss and p.global_position.distance_to(e.global_position) <= RADIUS:
			e.apply_fear(FEAR)
