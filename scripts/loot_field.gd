class_name LootField
extends Node2D
## Places floor loot ON the map: boosters (pickups) and chests. Gold is dropped
## by monsters, not placed here. Deterministically seeds each world cell, streams
## it in around the player, and remembers collected cells so loot never respawns.

var player: Node2D
var game
var world_seed := 0  # per-run seed so loot placement differs each run

var _active: Dictionary = {}    # cell -> node or null (empty cell)
var _consumed: Dictionary = {}  # cell -> true (already collected)
var _timer := 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.35
	_refresh()


func _refresh() -> void:
	if player == null or not is_instance_valid(player):
		return
	var cell: float = Config.LOOT_CELL
	var vc: int = Config.LOOT_VIEW_CELLS
	var pc := Vector2i(int(floor(player.global_position.x / cell)), int(floor(player.global_position.y / cell)))

	var needed := {}
	for dx in range(-vc, vc + 1):
		for dy in range(-vc, vc + 1):
			var c := pc + Vector2i(dx, dy)
			needed[c] = true
			if _consumed.has(c):
				continue
			if not _active.has(c):
				var node = _make(c, cell)
				_active[c] = node
				if node != null:
					add_child(node)

	for c in _active.keys():
		if not needed.has(c):
			var node = _active[c]
			if node != null and is_instance_valid(node):
				node.queue_free()
			_active.erase(c)


func on_collected(c: Vector2i) -> void:
	_consumed[c] = true
	_active.erase(c)


func _make(c: Vector2i, cell: float):
	if c == Vector2i(0, 0):
		return null  # keep the spawn point clear
	# Independent hashes (different salts) for presence, X, Y and type, so they're
	# uncorrelated — otherwise items in a cell fall into a visible grid pattern.
	var h_present := hash(Vector3i(world_seed ^ 0x1B873593, c.x, c.y))
	if posmod(h_present, 100) >= int(Config.LOOT_DENSITY):
		return null

	var hx := hash(Vector3i(world_seed ^ 0x2C1B3A9D, c.x, c.y))
	var hy := hash(Vector3i(world_seed ^ 0x5F356495, c.x, c.y))
	var ht := hash(Vector3i(world_seed ^ 0x7A9E1C3B, c.x, c.y))

	# Jittered position within the cell; smaller jitter keeps neighbours apart.
	var jit: float = Config.LOOT_JITTER
	var ox := (float(posmod(hx, 10000)) / 10000.0 - 0.5) * cell * jit
	var oy := (float(posmod(hy, 10000)) / 10000.0 - 0.5) * cell * jit
	var pos := Vector2(c) * cell + Vector2(cell * 0.5, cell * 0.5) + Vector2(ox, oy)

	# Never bury loot inside a wall/building — nudge it out, or skip the cell.
	pos = _free_spot(pos)
	if pos == Vector2.INF:
		return null

	var roll := posmod(ht, 100)
	var node
	if roll < 86:
		var p := Pickup.new()
		p.kind = _pickup_kind(ht)
		node = p
	else:  # ~14% of floor loot — chests are the rarer find
		node = Chest.new()

	node.player = player
	node.game = game
	node.field = self
	node.origin_cell = c
	node.global_position = pos
	return node


## Returns a nearby position clear of collision bodies, or Vector2.INF if the
## whole neighbourhood is blocked.
func _free_spot(pos: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 16
	q.collide_with_bodies = true
	q.collide_with_areas = false
	for off in [Vector2.ZERO, Vector2(90, 0), Vector2(-90, 0), Vector2(0, 90), Vector2(0, -90), Vector2(120, 120), Vector2(-120, -120)]:
		q.position = pos + off
		if space.intersect_point(q, 1).is_empty():
			return pos + off
	return Vector2.INF


func _pickup_kind(h: int) -> String:
	var kinds := ["heal", "magnet", "bomb", "frenzy", "power", "haste", "shield"]
	return kinds[posmod(h >> 17, kinds.size())]
