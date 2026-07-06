class_name AffinityWheel
extends Control
## The character portrait: a six-cornered wheel that fills toward the families
## your journey has taught you. Bottom-right HUD.

var player

const ORDER := ["blast", "ward", "drain", "summon", "control", "sight"]
const SHORT := {"blast": "Bl", "ward": "Wa", "drain": "Dr", "control": "Co", "sight": "Si", "summon": "Su"}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var vp := get_viewport_rect().size
	var c := Vector2(vp.x - 98.0, vp.y - 108.0)
	var r := 60.0
	var n := ORDER.size()
	var full: float = Config.INSIGHT_TIERS[Config.INSIGHT_TIERS.size() - 1]

	for ring in [0.34, 0.67, 1.0]:
		var ring_pts := PackedVector2Array()
		for i in n:
			var ang := -PI / 2.0 + i * TAU / n
			ring_pts.append(c + Vector2(cos(ang), sin(ang)) * r * ring)
		ring_pts.append(ring_pts[0])
		draw_polyline(ring_pts, Color(1, 1, 1, 0.12), 1.0)

	var poly := PackedVector2Array()
	for i in n:
		var fam: String = ORDER[i]
		var ang := -PI / 2.0 + i * TAU / n
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(c, c + dir * r, Color(1, 1, 1, 0.1), 1.0)
		var frac: float = clampf(float(player.insight.get(fam, 0.0)) / full, 0.0, 1.0)
		poly.append(c + dir * r * maxf(frac, 0.03))

	for i in n:
		draw_colored_polygon(PackedVector2Array([c, poly[i], poly[(i + 1) % n]]), Color(0.85, 0.85, 0.95, 0.16))
	var outline := poly
	outline.append(poly[0])
	draw_polyline(outline, Color(0.9, 0.9, 1.0, 0.7), 2.0)

	for i in n:
		var fam: String = ORDER[i]
		var ang := -PI / 2.0 + i * TAU / n
		var dir := Vector2(cos(ang), sin(ang))
		var col: Color = Families.color(fam)
		var tier: int = player.family_tier(fam)
		var label: String = SHORT[fam]
		if tier > 0:
			label += " " + ["I", "II", "III"][mini(tier, 3) - 1]
		draw_string(ThemeDB.fallback_font, c + dir * (r + 17.0) + Vector2(-12, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		if tier > 0:
			draw_circle(poly[i], 4.0, col)

	draw_string(ThemeDB.fallback_font, c + Vector2(-42, -r - 26.0), "Affinity", HORIZONTAL_ALIGNMENT_CENTER, 84, 13, Color(1, 1, 1, 0.7))
