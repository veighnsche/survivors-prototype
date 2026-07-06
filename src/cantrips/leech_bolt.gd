class_name LeechBolt
extends BoltCantrip
## Drain's cantrip: necrotic bolt that heals the caster a fraction of the
## damage — its score rises the more hurt you are.


func _init() -> void:
	id = "drain"
	display_name = "Leech Bolt"
	cooldown = 0.90
	damage = 6.0
	reach = 330.0
	speed = 460.0
	dtype = "necrotic"
	leech = 0.22


## The leech: a fraction of the damage that actually lands comes back as HP.
func _rig(b: Projectile, p: Player) -> void:
	b.post_hit = func(_bolt: Projectile, _e, applied: float) -> void:
		if applied > 0.0:
			p.leech_heal(applied * leech)
