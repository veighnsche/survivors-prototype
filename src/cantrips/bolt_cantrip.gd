class_name BoltCantrip
extends Cantrip
## Shared behavior of every flying-bolt cantrip: score the nearest target in
## reach (plus rider value), then loose bolt_count projectiles with this
## cantrip's riders attached.

const LIFE := 0.75   # seconds a bolt flies before fizzling

var speed := 500.0
var explode := 0.0   # splash radius (Fireball) — scaled by blast_radius_mult
var leech := 0.0     # fraction of damage healed (Leech Bolt)
var pierce := 0      # extra bodies a bolt passes through (Frost Lance)
var execute := 0.0   # 1.5x to targets at/above this hp (True Bolt)


func score(p: Player) -> Dictionary:
	var t := p.nearest_enemy_in(reach)
	if t == null:
		return {"score": 0.0}
	var dmg_base := dmg_for(p)
	var eff_base := dmg_base
	if execute > 0.0 and t.hp >= execute:
		eff_base *= 1.5
	var s: float = p.est_capped(t, eff_base, dtype) * p.bolt_count
	if explode > 0.0:
		var er := explode * p.blast_radius_mult
		for e2 in p.get_tree().get_nodes_in_group("enemies"):
			if e2 != t and t.global_position.distance_to(e2.global_position) <= er:
				s += p.est_capped(e2, dmg_base * 0.6, dtype)
	if leech > 0.0:
		# healing value scales with how hurt we are
		var urgency: float = clampf(1.0 - p.hp / p.max_hp, 0.0, 1.0)
		s += p.est_capped(t, dmg_base, dtype) * leech * urgency * 3.0
	return {"score": s, "target": t}


func cast(p: Player, target) -> void:
	var fam := "" if id == "force" else id
	var dmg_base := dmg_for(p)
	var base_dir: Vector2 = (target.global_position - p.global_position).normalized()
	var spread := deg_to_rad(12.0)
	for i in p.bolt_count:
		var offset := 0.0
		if p.bolt_count > 1:
			offset = spread * (i - (p.bolt_count - 1) / 2.0)
		var b := Projectile.new()
		b.damage = dmg_base * p.damage_mult * p.boost_dmg
		b.speed = speed
		b.life = LIFE
		b.direction = base_dir.rotated(offset)
		b.dtype = dtype
		b.fam = fam
		b.pierce = pierce
		if id != "force":
			b.tint = Families.color(id)
		b.source = p
		_rig(b, p)  # the subclass attaches its unique riders
		# spawn ahead of the body so bolts don't die inside a wall we're touching
		b.global_position = p.global_position + b.direction * (p.radius + 9.0)
		p.projectile_parent.add_child(b)


## Attach this cantrip's unique riders (pre_hit/post_hit) to a bolt about to
## fly. Base bolts fly clean.
func _rig(_b: Projectile, _p: Player) -> void:
	pass
