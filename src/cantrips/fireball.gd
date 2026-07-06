class_name Fireball
extends BoltCantrip
## Blast's cantrip: the only splash bolt. The brain picks it only when a real
## clump beats the single-target math.


const SPLASH_FACTOR := 0.6  # splash hits deal this fraction of the bolt


func _init() -> void:
	id = "blast"
	display_name = "Fireball"
	cooldown = 0.85
	damage = 7.0
	reach = 380.0
	speed = 460.0
	dtype = "arcane"
	explode = 56.0


## The blast: on impact, splash everything around the victim through the same
## damage funnel, and ring the explosion.
func _rig(b: Projectile, p: Player) -> void:
	b.post_hit = func(bolt: Projectile, e, _applied: float) -> void:
		var pos: Vector2 = e.global_position
		var er := explode * p.blast_radius_mult
		for e2 in bolt.get_tree().get_nodes_in_group("enemies"):
			if e2 != e and pos.distance_to(e2.global_position) <= er:
				bolt.deal_through(e2, bolt.damage * SPLASH_FACTOR)
		var ring := RingFx.new()
		ring.max_radius = er
		ring.color = Families.color("blast")
		ring.global_position = pos
		bolt.get_parent().add_child(ring)
