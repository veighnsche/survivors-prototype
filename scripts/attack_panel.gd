class_name AttackPanel
extends Control
## Live view of the cantrip selector (every option, its score, what got PICKED
## and why) plus the list of spells the player has committed to. Left HUD.

var player
var game

var _spell_rows: Array = []      # [{rect: Rect2, idx: int}] rebuilt each draw
var _pending_forget := -1        # click once to arm, again to forget
var _pending_t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _pending_t > 0.0:
		_pending_t -= delta
		if _pending_t <= 0.0:
			_pending_forget = -1
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for row in _spell_rows:
		var r: Rect2 = row.rect
		if r.has_point(mb.position):
			if _pending_forget == int(row.idx):
				game.forget_skill(int(row.idx))
				_pending_forget = -1
			else:
				_pending_forget = int(row.idx)
				_pending_t = 2.0
			return


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var x := 20.0
	var y := 120.0
	var font := ThemeDB.fallback_font

	var report: Array = player.brain_report
	var header := "Cantrips"
	if player.cast_cd > 0.0:
		header += "   silenced %.1fs" % player.cast_cd
	draw_string(font, Vector2(x, y), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.75))
	y += 8.0
	for entry in report:
		y += 22.0
		var picked: bool = entry.picked
		var col := Color(1, 1, 1, 0.55)
		if picked:
			col = Color(0.5, 1.0, 0.6, 1.0)
		if picked:
			draw_string(font, Vector2(x, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		draw_string(font, Vector2(x + 14, y), str(entry.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		var score_txt := "—"
		if not entry.no_target:
			score_txt = "%.1f" % float(entry.score)
		draw_string(font, Vector2(x + 122, y), score_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		var state := ""
		if picked:
			state = "PICKED (locks %.1fs)" % (player.cast_cd if player.cast_cd > 0.0 else 0.0)
		elif entry.no_target:
			state = "no target"
		else:
			state = "candidate"
		draw_string(font, Vector2(x + 172, y), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		if entry.home:
			draw_string(font, Vector2(x + 300, y), "^ biome", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.8, 0.4, 0.8))

	# --- committed spells (click to forget: once to arm, again to confirm) -------
	if game == null:
		return
	y += 34.0
	var spells: Array = game.picked_skills
	var full: bool = spells.size() >= Config.SKILL_LIMIT
	var spells_header := "Spells  %d/%d" % [spells.size(), Config.SKILL_LIMIT]
	if full:
		spells_header += "  (full — click one to forget)"
	draw_string(font, Vector2(x, y), spells_header, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.75))
	_spell_rows = []
	for i in spells.size():
		y += 20.0
		var s = spells[i]
		_spell_rows.append({"rect": Rect2(x, y - 15.0, 240.0, 20.0), "idx": i})
		if _pending_forget == i:
			draw_string(font, Vector2(x + 14, y), "%s — click again to forget" % s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.45, 0.4))
		else:
			draw_string(font, Vector2(x + 14, y), str(s.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, s.color)
