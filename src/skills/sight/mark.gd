class_name Mark
extends Skill
## Sight T2: auto-marks the toughest foe in reach — it takes +50% while marked.

const PERIOD := 4.0
const REACH := 320.0
const MIN_HP := 10.0

var _timer := 0.0


func _init() -> void:
	id = "mark"
	display_name = "Mark"
	desc = "Auto-mark tough foes"
	fam = "sight"
	tier = 2


func tick(p: Player, delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = PERIOD
	var tough = null
	var tough_hp := MIN_HP
	for e in p.get_tree().get_nodes_in_group("enemies"):
		if p.global_position.distance_to(e.global_position) <= REACH and e.hp > tough_hp:
			tough_hp = e.hp
			tough = e
	if tough != null:
		tough.apply_vuln(1.5, 3.0)
		Fx.floating_text(tough.global_position + Vector2(0, -18), "marked", Families.color("sight"))
