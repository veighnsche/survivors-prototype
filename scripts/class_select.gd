class_name ClassSelect
extends CanvasLayer
## Pre-run class picker (Ranged / Melee). Shown at start with the tree paused;
## emits `chosen(id)` and the run director begins the run. Issue #51.

signal chosen(id)

var _ids := ["ranged", "melee"]


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 28)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := Label.new()
	title.text = "CHOOSE YOUR CLASS"
	title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)

	var idx := 1
	for id in _ids:
		var c: Dictionary = Config.CLASS[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 220)
		b.text = "%d. %s\n\n%s" % [idx, c.name, c.blurb]
		var this_id: String = id
		b.pressed.connect(func(): _choose(this_id))
		row.add_child(b)
		idx += 1

	var hint := Label.new()
	hint.text = "Click a class, or press 1 / 2"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)


func _choose(id: String) -> void:
	chosen.emit(id)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_choose(_ids[0])
			KEY_2:
				_choose(_ids[1])
