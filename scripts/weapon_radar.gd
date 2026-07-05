class_name WeaponRadar
extends Control
## A hexagonal "mastery web": one spoke per weapon, filled by how far the player
## has leveled that weapon's upgrade tree (upgrades taken / total available).
## The current weapon's spoke is dotted. Bottom-right of the screen.

var game

const ORDER := ["fists", "ranged", "melee", "chain", "boomerang", "railgun"]
const LETTERS := {"fists": "F", "ranged": "R", "melee": "C", "chain": "T", "boomerang": "B", "railgun": "L"}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var vp := get_viewport_rect().size
	var c := Vector2(vp.x - 98.0, vp.y - 108.0)
	var r := 60.0
	var n := ORDER.size()

	# Sum taken/total upgrade levels per weapon.
	var taken := {}
	var total := {}
	for w in ORDER:
		taken[w] = 0.0
		total[w] = 0.0
	for def in Upgrades.pool():
		var wt: String = def.get("weapon", "any")
		if total.has(wt):
			total[wt] += float(int(def.max))
			taken[wt] += float(int(game.upgrade_levels.get(def.id, 0)))

	# Grid rings.
	for ring in [0.34, 0.67, 1.0]:
		var ring_pts := PackedVector2Array()
		for i in n:
			var ang := -PI / 2.0 + i * TAU / n
			ring_pts.append(c + Vector2(cos(ang), sin(ang)) * r * ring)
		ring_pts.append(ring_pts[0])
		draw_polyline(ring_pts, Color(1, 1, 1, 0.12), 1.0)

	# Spokes + data points.
	var poly := PackedVector2Array()
	for i in n:
		var w: String = ORDER[i]
		var ang := -PI / 2.0 + i * TAU / n
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(c, c + dir * r, Color(1, 1, 1, 0.1), 1.0)
		var prog := 0.0
		if total[w] > 0.0:
			prog = clampf(taken[w] / total[w], 0.0, 1.0)
		poly.append(c + dir * r * maxf(prog, 0.03))

	# Filled area, triangulated from center (correct for concave shapes).
	for i in n:
		draw_colored_polygon(PackedVector2Array([c, poly[i], poly[(i + 1) % n]]), Color(0.45, 0.8, 1.0, 0.22))
	var outline := poly
	outline.append(poly[0])
	draw_polyline(outline, Color(0.55, 0.85, 1.0, 0.85), 2.0)

	# Labels + current-weapon marker.
	var cur := ""
	if game.player != null and is_instance_valid(game.player):
		cur = game.player.weapon_kind
	for i in n:
		var w: String = ORDER[i]
		var ang := -PI / 2.0 + i * TAU / n
		var dir := Vector2(cos(ang), sin(ang))
		var col: Color = Config.WEAPONS[w].color
		draw_string(ThemeDB.fallback_font, c + dir * (r + 15.0) + Vector2(-5, 5), LETTERS[w], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
		if w == cur:
			draw_circle(poly[i], 4.0, col)

	draw_string(ThemeDB.fallback_font, c + Vector2(-55, -r - 16.0), "Weapon Mastery", HORIZONTAL_ALIGNMENT_LEFT, 120, 13, Color(1, 1, 1, 0.7))
