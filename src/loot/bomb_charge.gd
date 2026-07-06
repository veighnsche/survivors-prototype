class_name BombCharge
extends Booster
## Detonates: heavy arcane damage to everything around the player.

const DAMAGE := 80.0
const RADIUS := 720.0


func _init() -> void:
	label = "Bomb"
	letter = "B"
	color = Color(0.96, 0.6, 0.22)


func _apply() -> void:
	Fx.shake(Config.SHAKE_ON_BOMB)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(player.global_position) < RADIUS:
			e.take_damage(DAMAGE, "arcane")
