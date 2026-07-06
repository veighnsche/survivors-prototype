class_name Rot
extends Skill
## Drain T2: a necrotic aura that grinds everything near the caster.

const TICK := 0.5
const RADIUS := 100.0
const DAMAGE := 2.2

var _timer := 0.0


func _init() -> void:
	id = "rot"
	display_name = "Rot"
	desc = "Necrotic aura"
	fam = "drain"
	tier = 2


func apply(p: Player) -> void:
	p.rot_radius = RADIUS  # the player draws the aura ring
	p.queue_redraw()


func tick(p: Player, delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	for e in p.get_tree().get_nodes_in_group("enemies"):
		if p.global_position.distance_to(e.global_position) <= p.rot_radius:
			p.deal(e, DAMAGE * p.fam_power.drain, "necrotic", "drain")
