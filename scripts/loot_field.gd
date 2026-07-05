class_name LootField
extends Node2D
## Places loot ON the map (not dropped by enemies). Deterministically seeds each
## world cell with gold / a pickup / a chest, streams them in around the player,
## and remembers collected cells so loot never respawns.

var player: Node2D
var game

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
	# Distinct seed from the obstacle field so loot and buildings don't correlate.
	var h := hash(Vector2i(c.x + 4096, c.y - 8192))
	if posmod(h, 100) >= int(Config.LOOT_DENSITY):
		return null

	var ox := float(posmod(h >> 7, 260)) - 130.0
	var oy := float(posmod(h >> 15, 260)) - 130.0
	var pos := Vector2(c) * cell + Vector2(cell * 0.5 + ox, cell * 0.5 + oy)

	var roll := posmod(h >> 21, 100)
	var node
	if roll < 60:
		var g := Gold.new()
		g.value = 3 + posmod(h >> 3, 6)
		node = g
	elif roll < 90:
		var p := Pickup.new()
		p.kind = _pickup_kind(h)
		node = p
	else:
		node = Chest.new()

	node.player = player
	node.game = game
	node.field = self
	node.origin_cell = c
	node.global_position = pos
	return node


func _pickup_kind(h: int) -> String:
	var kinds := ["heal", "magnet", "bomb", "frenzy", "power", "haste"]
	return kinds[posmod(h >> 17, kinds.size())]
