class_name AttackPanel
extends Control
## Live view of the cantrip selector (every option, its score, what got PICKED
## and why) plus the list of spells the player has committed to. Left HUD.

var player
var game


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


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

	# --- committed spells -------------------------------------------------------
	if game == null:
		return
	y += 34.0
	var spells: Array = game.picked_skills
	draw_string(font, Vector2(x, y), "Spells  %d/%d" % [spells.size(), Config.SKILL_LIMIT], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.75))
	for s in spells:
		y += 20.0
		draw_string(font, Vector2(x + 14, y), str(s.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, s.color)
