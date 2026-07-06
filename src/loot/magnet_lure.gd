class_name MagnetLure
extends Booster
## Pulls EVERYTHING collectible on the field toward the player.


func _init() -> void:
	label = "Magnet"
	letter = "M"
	color = Color(0.4, 0.72, 1.0)


func _apply() -> void:
	# pulls EVERYTHING collectible, not just gems
	for g in get_tree().get_nodes_in_group("gems"):
		g.attracting = true
	for c in get_tree().get_nodes_in_group("gold"):
		c.attracting = true
