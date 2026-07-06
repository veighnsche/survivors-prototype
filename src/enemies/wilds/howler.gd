class_name Howler
extends Enemy
## Wilds pack leader: runs with the pack and war-cries it into a frenzy.

const CRY_EVERY := 2.5
const BUFF_RADIUS := 220.0

var _cry_timer := 0.0


func _init() -> void:
	arch = "howler"
	display_name = "Howler"
	base_hp = 16.0
	speed = 95.0
	damage = 6.0
	radius = 12.0
	xp_tier = "medium"


func _brain(delta: float) -> Vector2:
	_cry_timer -= delta
	if _cry_timer <= 0.0:
		_cry_timer = CRY_EVERY
		_logmech("howler:warcry")
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and global_position.distance_to(e.global_position) <= BUFF_RADIUS:
				e.apply_haste(1.35, CRY_EVERY)
		var ring := RingFx.new()
		ring.max_radius = BUFF_RADIUS
		ring.color = Color(color.r, color.g, color.b, 0.5)
		ring.global_position = global_position
		get_parent().add_child(ring)
	return to_player().normalized()


func _draw_marks() -> void:
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 18, color.lightened(0.3), 2.0)
