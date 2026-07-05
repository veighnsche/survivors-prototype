class_name CardScreen
extends CanvasLayer
## The level-up choice UI. Runs while the tree is paused (PROCESS_MODE_ALWAYS).
## Shows 3 cards plus Reroll/Banish. Emits signals the run director acts on.

signal picked(id)
signal banished(id)
signal rerolled

var game  # run director, read for current levels + charges
var active := false
var banish_mode := false
var _cards: Array = []

var _title: Label
var _cards_box: HBoxContainer
var _reroll_btn: Button
var _banish_btn: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 20)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_cards_box)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 20)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(actions)

	_reroll_btn = Button.new()
	_reroll_btn.pressed.connect(func(): rerolled.emit())
	actions.add_child(_reroll_btn)

	_banish_btn = Button.new()
	_banish_btn.pressed.connect(_toggle_banish)
	actions.add_child(_banish_btn)


func show_cards(cards: Array) -> void:
	_cards = cards
	banish_mode = false
	active = true
	visible = true
	_rebuild()


func hide_cards() -> void:
	active = false
	visible = false


func _toggle_banish() -> void:
	banish_mode = not banish_mode
	_rebuild()


func _rebuild() -> void:
	for c in _cards_box.get_children():
		c.queue_free()

	_title.text = "BANISH — pick a card to remove" if banish_mode else "LEVEL UP — choose an upgrade"

	var idx := 1
	for def in _cards:
		var b := Button.new()
		b.custom_minimum_size = Vector2(250, 175)
		var lvl := 0
		if game != null:
			lvl = int(game.upgrade_levels.get(def.id, 0))
		var lvltxt := ""
		if def.has("max"):
			lvltxt = "\n\nLv %d → %d" % [lvl, lvl + 1]
		var wtag: String = def.get("weapon", "any")
		var source := "Shared"
		if wtag != "any" and Config.WEAPONS.has(wtag):
			source = Config.WEAPONS[wtag].name
		b.text = "%d. %s\n(%s)\n\n%s%s" % [idx, def.name, source, def.desc, lvltxt]
		var this_id: String = def.id
		b.pressed.connect(func(): _on_card(this_id))
		_cards_box.add_child(b)
		idx += 1

	var rc := 0
	var bc := 0
	if game != null:
		rc = game.reroll_charges
		bc = game.banish_charges
	_reroll_btn.text = "Reroll (Q)  x%d" % rc
	_reroll_btn.disabled = rc <= 0
	_banish_btn.text = "Banish: ON (E)" if banish_mode else "Banish (E)  x%d" % bc
	_banish_btn.disabled = bc <= 0 and not banish_mode


func _on_card(id: String) -> void:
	if banish_mode:
		banished.emit(id)
	else:
		picked.emit(id)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_pick_index(0)
			KEY_2:
				_pick_index(1)
			KEY_3:
				_pick_index(2)
			KEY_Q:
				if game != null and game.reroll_charges > 0:
					rerolled.emit()
			KEY_E:
				if game != null and (game.banish_charges > 0 or banish_mode):
					_toggle_banish()


func _pick_index(i: int) -> void:
	if i < _cards.size():
		_on_card(_cards[i].id)
