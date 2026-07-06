extends Control
## Main menu + PowerUp shop. The between-run hub: shows banked gold, starts a
## run, and lets you spend gold on permanent upgrades.

var _gold_label: Label
var _shop: ColorRect
var _shop_list: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := Label.new()
	title.text = "SURVIVORS"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 24)
	vb.add_child(_gold_label)

	var start := Button.new()
	start.text = "Start Run"
	start.custom_minimum_size = Vector2(240, 48)
	start.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	vb.add_child(start)

	var shop_btn := Button.new()
	shop_btn.text = "PowerUps"
	shop_btn.custom_minimum_size = Vector2(240, 48)
	shop_btn.pressed.connect(_open_shop)
	vb.add_child(shop_btn)

	_build_shop()
	_update_gold()


func _process(_delta: float) -> void:
	_update_gold()


func _update_gold() -> void:
	_gold_label.text = "Gold: %d" % Save.total_gold


func _open_shop() -> void:
	_shop.visible = true
	_rebuild_shop()


func _build_shop() -> void:
	_shop = ColorRect.new()
	_shop.color = Color(0, 0, 0, 0.88)
	_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.visible = false
	add_child(_shop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var t := Label.new()
	t.text = "POWERUPS"
	t.add_theme_font_size_override("font_size", 36)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)

	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 6)
	vb.add_child(_shop_list)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 40)
	back.pressed.connect(func(): _shop.visible = false)
	vb.add_child(back)


func _rebuild_shop() -> void:
	for c in _shop_list.get_children():
		c.queue_free()
	for p in Powerups.POOL:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var lvl := Save.powerup_level(p.id)
		var info := Label.new()
		info.custom_minimum_size = Vector2(440, 0)
		info.text = "%s  (Lv %d/%d)  —  %s" % [p.name, lvl, int(p.max), p.desc]
		row.add_child(info)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, 0)
		if lvl >= int(p.max):
			btn.text = "MAX"
			btn.disabled = true
		else:
			var cost := Save.powerup_cost(p.id)
			btn.text = "Buy (%d)" % cost
			btn.disabled = Save.total_gold < cost
			var pid: String = p.id
			btn.pressed.connect(func(): _buy(pid))
		row.add_child(btn)
		_shop_list.add_child(row)


func _buy(id: String) -> void:
	Save.buy(id)
	_rebuild_shop()
	_update_gold()
