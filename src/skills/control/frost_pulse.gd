class_name FrostPulse
extends Skill
## Control T1: a periodic pulse that chills (and nicks) everything around you.

const PERIOD := 2.6
const RADIUS := 135.0
const DAMAGE := 3.0

var _timer := 0.0


func _init() -> void:
	id = "pulse"
	display_name = "Frost Pulse"
	desc = "Periodic slowing pulse"
	fam = "control"
	tier = 1


func tick(p: Player, delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = PERIOD * p.attack_speed_mult
	var pulse_radius := RADIUS * p.control_radius_mult
	var slow_factor := maxf(0.25, 0.55 - 0.05 * p.chill_level)
	var any := false
	for e in p.get_tree().get_nodes_in_group("enemies"):
		if p.global_position.distance_to(e.global_position) <= pulse_radius:
			e.apply_slow(slow_factor, 2.0)
			p.deal(e, DAMAGE * p.fam_power.control, "frost", "control")
			any = true
	if any:
		var ring := RingFx.new()
		ring.max_radius = pulse_radius
		ring.color = Families.color("control")
		ring.global_position = p.global_position
		p.projectile_parent.add_child(ring)
