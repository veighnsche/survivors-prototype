class_name TrueBolt
extends BoltCantrip
## Sight's cantrip: the sniper. Long reach, and 1.5x against targets still at
## or above the execute threshold — punish the big ones.

const EXECUTE_MULT := 1.5


func _init() -> void:
	id = "sight"
	display_name = "True Bolt"
	cooldown = 0.85
	damage = 7.0
	reach = 500.0
	speed = 660.0
	dtype = "precise"
	execute = 20.0


## The execute: bolts hit 1.5x against targets still at/above the threshold.
func _rig(b: Projectile, _p: Player) -> void:
	b.pre_hit = func(_bolt: Projectile, e, dmg: float) -> float:
		return dmg * EXECUTE_MULT if e.hp >= execute else dmg
