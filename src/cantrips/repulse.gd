class_name Repulse
extends Cantrip
## Ward's cantrip: a defensive shove. Radial knockback + stagger — its value is
## the contact damage it relieves, so it scores by pressure, not just damage.

const KNOCKBACK := 150.0
const SLOW := 0.45


func _init() -> void:
	id = "ward"
	display_name = "Repulse"
	cooldown = 1.40
	damage = 3.0
	reach = 150.0
	dtype = "reflect"


func score(p: Player) -> Dictionary:
	var dmg_base := dmg_for(p)
	var s := 0.0
	var pressure := 0.0
	var count := 0
	for e in p.get_tree().get_nodes_in_group("enemies"):
		if p.global_position.distance_to(e.global_position) <= reach:
			s += p.est_capped(e, dmg_base, dtype)
			pressure += e.eff_damage()
			count += 1
	if count == 0:
		return {"score": 0.0}
	var urgency: float = clampf(1.3 - p.hp / p.max_hp, 0.3, 1.3)
	return {"score": s + pressure * urgency}


func cast(p: Player, _target) -> void:
	var dmg_base := dmg_for(p)
	for e in p.get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector2 = e.global_position - p.global_position
		if to_e.length() <= reach:
			p.deal(e, dmg_base, dtype, id)
			e.global_position += to_e.normalized() * KNOCKBACK
			e.apply_slow(SLOW, 1.2)  # staggered by the shove
	var ring := RingFx.new()
	ring.max_radius = reach
	ring.color = Families.color("ward")
	ring.global_position = p.global_position
	p.projectile_parent.add_child(ring)
