class_name EdgeIndicators
extends Control
## Screen-edge beacons pointing at off-screen chests/pickups (group "guided").
## Each is clamped to the screen border in the item's direction; alpha rises as
## you get close and fades out when far. Multiple show at once.

var player: Node2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var vp := get_viewport_rect().size
	var center := vp * 0.5
	var margin := 34.0

	for item in get_tree().get_nodes_in_group("guided"):
		if not is_instance_valid(item):
			continue
		var to_item: Vector2 = item.global_position - player.global_position
		var dist := to_item.length()
		if dist < 1.0:
			continue

		# Alpha: full when just off-screen, fading to 0 at the far threshold.
		var span: float = Config.INDICATOR_FADE_MAX - Config.INDICATOR_FADE_MIN
		var a := clampf((Config.INDICATOR_FADE_MAX - dist) / span, 0.0, 1.0)
		if a <= 0.02:
			continue

		# Camera is centered on the player, so screen pos = center + world offset.
		var screen := center + to_item
		if screen.x > margin and screen.x < vp.x - margin and screen.y > margin and screen.y < vp.y - margin:
			continue  # already visible on-screen

		var dir := to_item.normalized()
		var color := Color.WHITE
		if item.has_method("indicator_color"):
			color = item.indicator_color()
		_draw_beacon(_edge_point(center, dir, vp, margin), dir, color, a)


func _edge_point(center: Vector2, dir: Vector2, vp: Vector2, margin: float) -> Vector2:
	var half := vp * 0.5 - Vector2(margin, margin)
	var sx := INF if dir.x == 0.0 else half.x / absf(dir.x)
	var sy := INF if dir.y == 0.0 else half.y / absf(dir.y)
	return center + dir * minf(sx, sy)


func _draw_beacon(pos: Vector2, dir: Vector2, color: Color, a: float) -> void:
	var ang := dir.angle()
	var tip := pos + Vector2(15.0, 0.0).rotated(ang)
	var b1 := pos + Vector2(-9.0, 9.0).rotated(ang)
	var b2 := pos + Vector2(-9.0, -9.0).rotated(ang)
	draw_circle(pos, 6.0, Color(color.r, color.g, color.b, a * 0.55))
	draw_colored_polygon(PackedVector2Array([tip, b1, b2]), Color(color.r, color.g, color.b, a))
