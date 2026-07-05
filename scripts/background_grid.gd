class_name BackgroundGrid
extends Node2D
## The ground. Paints biome-colored patches by sampling the biome map per block,
## so region borders are visible terrain you can see and walk toward — plus the
## scrolling grid that makes motion read.

const BLOCK := 128.0  # ground-patch sampling size

var target: Node2D
var biome_map: BiomeMap
var cell := 64.0
var line_color := Color(1, 1, 1, 0.05)


func _process(_delta: float) -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position
		queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var half := vp * 0.65
	var left := -half.x
	var right := half.x
	var top := -half.y
	var bottom := half.y

	# Ground: biome-colored patches sampled from the world map (borders visible).
	if biome_map != null:
		var wx0 := floorf((global_position.x + left) / BLOCK) * BLOCK
		var wy0 := floorf((global_position.y + top) / BLOCK) * BLOCK
		var wy := wy0
		while wy < global_position.y + bottom + BLOCK:
			var wx := wx0
			while wx < global_position.x + right + BLOCK:
				var biome := biome_map.biome_at(Vector2(wx + BLOCK * 0.5, wy + BLOCK * 0.5))
				var c: Color = Config.BIOMES[biome].color
				draw_rect(Rect2(wx - global_position.x, wy - global_position.y, BLOCK, BLOCK), Color(c.r, c.g, c.b, 0.14))
				wx += BLOCK
			wy += BLOCK

	# Scrolling grid lines.
	var ox := fposmod(global_position.x, cell)
	var oy := fposmod(global_position.y, cell)
	var x := left - ox
	while x <= right:
		draw_line(Vector2(x, top), Vector2(x, bottom), line_color, 1.0)
		x += cell
	var y := top - oy
	while y <= bottom:
		draw_line(Vector2(left, y), Vector2(right, y), line_color, 1.0)
		y += cell
