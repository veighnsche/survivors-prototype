class_name Husk
extends Enemy
## Commons rusher. Emboldens in a pack — thin the pack or they run you down.

var _embold := false
var _pack_timer := 0.0


func _init() -> void:
	arch = "husk"
	display_name = "Husk"
	base_hp = 3.5
	speed = 118.0
	damage = 5.0
	radius = 9.0
	xp_tier = "small"


func _brain(delta: float) -> Vector2:
	_pack_timer -= delta
	if _pack_timer <= 0.0:
		_pack_timer = 0.5
		var packmates := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and e is Husk and global_position.distance_to(e.global_position) < 150.0:
				packmates += 1
				if packmates >= 2:
					break
		if packmates >= 2 and not _embold:
			_logmech("husk:embolden")
		_embold = packmates >= 2
		queue_redraw()
	return to_player().normalized()


func _state_speed() -> float:
	return 1.22 if _embold else 1.0


func _draw_marks() -> void:
	if _embold:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 16, Color(1.0, 0.5, 0.4, 0.8), 2.0)
