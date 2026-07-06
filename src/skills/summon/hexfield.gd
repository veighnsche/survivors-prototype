class_name Hexfield
extends Skill
## Summon T2: conjured grinding zones that hold ground where the horde is.

const PERIOD := 4.5
const REACH := 420.0

var _timer := 0.0


func _init() -> void:
	id = "hex"
	display_name = "Hexfield"
	desc = "Conjured grinding zones"
	fam = "summon"
	tier = 2


func tick(p: Player, delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = PERIOD
	var target := p.nearest_enemy_in(REACH)
	if target == null:
		return
	var zone := HexZone.new()
	zone.player = p
	zone.power = p.fam_power.summon
	zone.global_position = target.global_position
	p.projectile_parent.add_child(zone)
