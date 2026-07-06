class_name Projectile
extends Area2D
## A flying bolt: generic flight, pierce, collision, and damage routing —
## nothing cantrip-specific lives here. Anything unique to one cantrip
## (Fireball's blast, Leech Bolt's healing, True Bolt's execute) is attached
## by that cantrip as a rider hook when it casts.

var damage := 3.0
var speed := 520.0
var direction := Vector2.RIGHT
var life := 1.4
var pierce := 0           # extra bodies the bolt passes through
var radius := 5.0
var dtype := "arcane"
var fam := ""             # family credited when routed through the player
var tint := Color(1.0, 1.0, 0.65)
var source: Node

# Cantrip riders (set by the casting cantrip, see src/cantrips/):
#   pre_hit(bolt, enemy, dmg) -> float   adjust damage before it lands
#   post_hit(bolt, enemy, applied)       react after it lands
var pre_hit := Callable()
var post_hit := Callable()

var _hit: Dictionary = {}


func _ready() -> void:
	z_index = 8
	collision_layer = 8
	collision_mask = 2 | 16
	monitoring = true
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	add_child(cs)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	# Fixed-step motion: identical trajectories at any sim speed (no tunneling).
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var e := area.get_parent()
	if not (e is Enemy):
		return
	var eid := e.get_instance_id()
	if _hit.has(eid):
		return
	_hit[eid] = true
	var dmg := damage
	if pre_hit.is_valid():
		dmg = pre_hit.call(self, e, dmg)
	var applied := deal_through(e, dmg)
	if post_hit.is_valid():
		post_hit.call(self, e, applied)
	if pierce > 0:
		pierce -= 1
	else:
		queue_free()


## Route damage through the caster so crits/siphon/shatter/insight apply;
## global mults are baked into `damage`, so divide them back out first.
## Riders splash through this same funnel (see Fireball).
func deal_through(e, amount: float) -> float:
	if source != null and is_instance_valid(source) and source.has_method("deal"):
		var base: float = amount / max(source.damage_mult * source.boost_dmg, 0.001)
		return source.deal(e, base, dtype, fam)
	return e.take_damage(amount, dtype)


func _on_body_entered(_body: Node) -> void:
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, tint)
	draw_circle(Vector2.ZERO, radius * 0.5, Color.WHITE)
