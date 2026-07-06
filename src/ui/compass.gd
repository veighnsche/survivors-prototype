class_name Compass
extends Control
## Macro navigation for huge biomes: a screen-edge pointer to the living Warden
## while it hunts you, or to the nearest known gates when you're free to travel.
## Distinct from loot beacons: full alpha, labeled, with distance.

var player
var game


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or game == null or not is_instance_valid(player):
		return
	var targets: Array = []
	if game.warden_ref != null and is_instance_valid(game.warden_ref):
		targets.append({"pos": game.warden_ref.global_position, "label": "WARDEN", "color": Color(1.0, 0.3, 0.25)})
	elif game.boss_lock_biome == "":
		# free to travel: the two nearest known gates
		var gates: Array = game.known_gates.duplicate()
		gates.sort_custom(func(a, b): return player.global_position.distance_squared_to(a) < player.global_position.distance_squared_to(b))
		for i in mini(2, gates.size()):
			targets.append({"pos": gates[i], "label": "GATE", "color": Color(0.95, 0.85, 0.5)})

	var vp := get_viewport_rect().size
	var center := vp * 0.5
	var margin := 52.0
	for t in targets:
		var to_t: Vector2 = t.pos - player.global_position
		var dist := to_t.length()
		if dist < 60.0:
			continue
		var screen := center + to_t
		var onscreen: bool = screen.x > margin and screen.x < vp.x - margin and screen.y > margin and screen.y < vp.y - margin
		var dir := to_t.normalized()
		var p := screen if onscreen else _edge_point(center, dir, vp, margin)
		var col: Color = t.color
		# chevron
		var ang := dir.angle()
		var tip := p + Vector2(18.0, 0.0).rotated(ang)
		var b1 := p + Vector2(-8.0, 11.0).rotated(ang)
		var b2 := p + Vector2(-8.0, -11.0).rotated(ang)
		draw_colored_polygon(PackedVector2Array([tip, b1, b2]), col)
		draw_string(ThemeDB.fallback_font, p + Vector2(-34, 28), "%s %dm" % [t.label, int(dist / 32.0)], HORIZONTAL_ALIGNMENT_CENTER, 80, 13, col)


func _edge_point(center: Vector2, dir: Vector2, vp: Vector2, margin: float) -> Vector2:
	var half := vp * 0.5 - Vector2(margin, margin)
	var sx := INF if dir.x == 0.0 else half.x / absf(dir.x)
	var sy := INF if dir.y == 0.0 else half.y / absf(dir.y)
	return center + dir * minf(sx, sy)
