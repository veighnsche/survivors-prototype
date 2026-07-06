class_name Nova
extends Skill
## Blast T1: an automatic shockwave pulse around the caster.

const PERIOD := 3.2
const RADIUS := 130.0
const DAMAGE := 11.0

var _timer := 0.0


func _init() -> void:
	id = "nova"
	display_name = "Nova"
	desc = "Auto shockwave pulse"
	fam = "blast"
	tier = 1


func tick(p: Player, delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = PERIOD * p.attack_speed_mult
	var nova_radius := RADIUS * p.blast_radius_mult
	var any := false
	for e in p.get_tree().get_nodes_in_group("enemies"):
		if p.global_position.distance_to(e.global_position) <= nova_radius:
			p.deal(e, DAMAGE * p.fam_power.blast, "arcane", "blast")
			any = true
	if any:
		var ring := RingFx.new()
		ring.max_radius = nova_radius
		ring.color = Families.color("blast")
		ring.global_position = p.global_position
		p.projectile_parent.add_child(ring)
