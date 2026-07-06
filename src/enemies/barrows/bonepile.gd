class_name Bonepile
extends Enemy
## Barrows heavy: a slow ossuary that bursts into Grave-swarms on death.


const SPLIT_COUNT := 3


func _init() -> void:
	arch = "bonepile"
	display_name = "Bonepile"
	base_hp = 40.0
	speed = 30.0
	damage = 10.0
	radius = 17.0
	xp_tier = "large"


## Bursts into its Grave-swarms when it falls.
func on_death(game) -> void:
	_logmech("bonepile:split")
	for i in SPLIT_COUNT:
		game.spawn_minion("grave_swarm", biome, global_position + Vector2(randf_range(-26, 26), randf_range(-26, 26)))


func _draw_marks() -> void:
	for i in 3:
		var a := i * TAU / 3.0
		draw_circle(Vector2(cos(a), sin(a)) * radius * 0.45, 2.5, Color(0, 0, 0, 0.35))
