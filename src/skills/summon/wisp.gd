class_name Wisp
extends Skill
## Summon T1: a familiar that fires physical darts at the nearest foe.
## The wisp volley has ONE owner (see p.wisp_ticker) so Wisp + Legion never
## double-fire; Legion inherits this tick and raises the count.

const REACH := 420.0
const DAMAGE := 4.0

var _timer := 0.0


func _init() -> void:
	id = "wisp"
	display_name = "Wisp"
	desc = "A familiar fights with you"
	fam = "summon"
	tier = 1


func apply(p: Player) -> void:
	p.wisp_count = maxi(p.wisp_count, 1)
	p.wisp_ticker = self


func tick(p: Player, delta: float) -> void:
	if p.wisp_ticker != self or p.wisp_count <= 0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0 * p.wisp_speed_mult * p.attack_speed_mult
	for i in p.wisp_count:
		var target := p.nearest_enemy_in(REACH)
		if target == null:
			return
		var off := Vector2(cos(TAU * i / maxi(p.wisp_count, 1)), sin(TAU * i / maxi(p.wisp_count, 1))) * 26.0
		var b := Projectile.new()
		b.damage = DAMAGE * p.fam_power.summon * p.damage_mult * p.boost_dmg
		b.speed = 480.0
		b.life = 1.2
		b.radius = 3.5
		b.dtype = "physical"
		b.fam = "summon"
		b.tint = Families.color("summon")
		b.direction = (target.global_position - (p.global_position + off)).normalized()
		b.source = p
		b.global_position = p.global_position + off
		p.projectile_parent.add_child(b)
