class_name Broodmother
extends Enemy
## Hollow matriarch: lays a Mite every few seconds while alive, and bursts into
## her brood on death.

const LAY_EVERY := 6.0
const BROOD_COUNT := 4

var _lay_timer := 0.0


func _init() -> void:
	arch = "broodmother"
	display_name = "Broodmother"
	base_hp = 26.0
	speed = 38.0
	damage = 10.0
	radius = 18.0
	xp_tier = "large"


func _brain(delta: float) -> Vector2:
	_lay_timer -= delta
	if _lay_timer <= 0.0:
		_lay_timer = LAY_EVERY
		var g = get_parent().get_parent()
		if g != null and g.has_method("spawn_minion"):
			_logmech("broodmother:lay")
			g.spawn_minion("mite", biome, global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	return to_player().normalized()


## Her brood bursts free when she falls.
func on_death(game) -> void:
	_logmech("broodmother:split")
	for i in BROOD_COUNT:
		game.spawn_minion("mite", biome, global_position + Vector2(randf_range(-26, 26), randf_range(-26, 26)))


func _draw_marks() -> void:
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		draw_circle(Vector2(cos(a), sin(a)) * radius * 0.5, 2.0, Color(1, 1, 1, 0.4))
