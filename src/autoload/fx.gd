extends Node
## Global juice helper (autoload "Fx"). The run director registers its world FX
## layer and camera each run; entities call these without threading references.

var layer: Node2D  # world-space container for transient FX
var camera        # GameCamera, for screen shake


func damage_number(pos: Vector2, amount: float) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	var d := DamageNumber.new()
	d.amount = amount
	d.global_position = pos
	layer.add_child(d)


func floating_text(pos: Vector2, text: String, color: Color) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	var d := DamageNumber.new()
	d.text_override = text
	d.color = color
	d.global_position = pos
	layer.add_child(d)


func death_pop(pos: Vector2, color: Color) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	var p := DeathPop.new()
	p.color = color
	p.global_position = pos
	layer.add_child(p)


func shake(amount: float) -> void:
	if camera != null and is_instance_valid(camera):
		camera.add_trauma(amount)
