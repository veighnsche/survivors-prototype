class_name HexZone
extends Node2D
## Summon T2: a conjured field that holds ground, ticking physical damage to
## everything inside. The swarm-grinder.

var player
var power := 1.0
var radius := 95.0
var life := 3.2
var _tick := 0.0


func _ready() -> void:
	z_index = 3
	queue_redraw()


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		if player != null and is_instance_valid(player):
			for e in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(e.global_position) <= radius:
					player.deal(e, 4.0 * power, "physical", "summon")
	modulate.a = clampf(life / 0.6, 0.0, 1.0)


func _draw() -> void:
	var c: Color = Config.FAMILY_COLORS.summon
	draw_circle(Vector2.ZERO, radius, Color(c.r, c.g, c.b, 0.10))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.55), 2.5)
