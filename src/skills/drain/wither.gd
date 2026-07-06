class_name Wither
extends Skill
## Drain T3: auto-curses the toughest foe in reach — vulnerable, then bitten.

const PERIOD := 4.0
const REACH := 300.0
const MIN_HP := 14.0
const DAMAGE := 14.0

var _timer := 0.0


func _init() -> void:
	id = "wither"
	display_name = "Wither"
	desc = "Auto-curse the toughest foe"
	fam = "drain"
	tier = 3


func tick(p: Player, delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = PERIOD
	var best: Node2D = null
	var best_hp := MIN_HP
	for e in p.get_tree().get_nodes_in_group("enemies"):
		if p.global_position.distance_to(e.global_position) <= REACH and e.hp > best_hp:
			best_hp = e.hp
			best = e
	if best == null:
		return
	best.apply_vuln(1.5, 4.0)
	p.deal(best, DAMAGE * p.fam_power.drain, "necrotic", "drain")
	Fx.floating_text(best.global_position + Vector2(0, -18), "withered", Families.color("drain"))
