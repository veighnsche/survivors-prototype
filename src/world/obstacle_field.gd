class_name ObstacleField
extends Node2D
## Infinite obstacle field. Deterministically places buildings per world cell
## (stable via hashing) and streams them in/out around the player so the plane
## has structure to collide with everywhere.

var player: Node2D
var world_seed := 0  # per-run seed so each run's layout differs
var biome_map: BiomeMap  # styles obstacles by the biome they sit in
var _active: Dictionary = {}  # Vector2i -> ObstacleBody or null (empty cell)
var _timer := 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.3
	_refresh()


func _refresh() -> void:
	if player == null or not is_instance_valid(player):
		return
	var cell: float = Config.OBSTACLE_CELL
	var vc: int = Config.OBSTACLE_VIEW_CELLS
	var pc := Vector2i(int(floor(player.global_position.x / cell)), int(floor(player.global_position.y / cell)))

	var needed := {}
	for dx in range(-vc, vc + 1):
		for dy in range(-vc, vc + 1):
			var c := pc + Vector2i(dx, dy)
			needed[c] = true
			if not _active.has(c):
				var ob = _make(c, cell)
				_active[c] = ob
				if ob != null:
					add_child(ob)

	for c in _active.keys():
		if not needed.has(c):
			var ob = _active[c]
			if ob != null and is_instance_valid(ob):
				ob.queue_free()
			_active.erase(c)


func _make(c: Vector2i, cell: float):
	if c == Vector2i(0, 0):
		return null  # keep the spawn point clear
	# Vector3i hash avalanches each component — adjacent cells get uncorrelated
	# values (a string hash made consecutive cells line up).
	var h := hash(Vector3i(world_seed, c.x, c.y))
	if posmod(h, 100) >= int(Config.OBSTACLE_DENSITY):
		return null
	var ox := float(posmod(h >> 7, 220)) - 110.0
	var oy := float(posmod(h >> 15, 220)) - 110.0
	var w := 60.0 + float(posmod(h >> 23, 90))
	var hgt := 60.0 + float(posmod(h >> 3, 90))
	var ob := ObstacleBody.new()
	ob.size = Vector2(w, hgt)
	ob.global_position = Vector2(c) * cell + Vector2(cell * 0.5 + ox, cell * 0.5 + oy)
	if biome_map != null:
		var bdef := Biomes.of(biome_map.biome_at(ob.global_position))
		ob.biome = bdef  # the biome paints its own terrain
		ob.color = bdef.color.darkened(0.55)
	return ob
