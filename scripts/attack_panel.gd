class_name AttackPanel
extends Control
## Live view of the smart basic-attack selector: every attack the caster can
## pick from, its current utility score, cooldown state, home-turf lean, and
## which one was just PICKED. Left side of the screen.

var player


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var report: Array = player.brain_report
	if report.is_empty():
		return
	var x := 20.0
	var y := 120.0
	var font := ThemeDB.fallback_font

	draw_string(font, Vector2(x, y), "Basic attacks", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.75))
	y += 8.0

	for entry in report:
		y += 22.0
		var picked: bool = entry.picked
		var col := Color(1, 1, 1, 0.55)
		if picked:
			col = Color(0.5, 1.0, 0.6, 1.0)
		elif entry.cd > 0.0:
			col = Color(1, 1, 1, 0.32)
		# marker
		if picked:
			draw_string(font, Vector2(x, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		# name
		draw_string(font, Vector2(x + 14, y), str(entry.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		# score (the number that decided it)
		var score_txt := "—"
		if not entry.no_target:
			score_txt = "%.1f" % float(entry.score)
		draw_string(font, Vector2(x + 118, y), score_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		# state
		var state := ""
		if picked:
			state = "PICKED"
		elif entry.no_target:
			state = "no target"
		elif entry.cd > 0.0:
			state = "cd %.1f" % float(entry.cd)
		else:
			state = "ready"
		draw_string(font, Vector2(x + 168, y), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		# home-turf lean marker
		if entry.home:
			draw_string(font, Vector2(x + 238, y), "^ biome", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.8, 0.4, 0.8))
