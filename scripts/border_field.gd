class_name BorderField
extends Node2D
## Permanent walls along biome borders, streamed around the player. Borders are
## closed except for entrance gaps (deterministic per seed), so crossing into a
## biome means finding a way in. Wall tiles are styled by the biome they stand
## in, so each side of a border looks like its own region.

const TILE := 96.0
const VIEW := 1400.0
const GATE := 420.0  # coarse gate cells; a "gap" opens the whole gate cell

var player: Node2D
var biome_map: BiomeMap
var world_seed := 0
var game  # for posting entrance guards

var _active: Dictionary = {}   # Vector2i tile -> WallBody or null
var _guarded: Dictionary = {}  # gate cell -> true once its guards were posted
var _spawn_doors: Array = []   # exactly one doorway per wedge on the Commons ring
var _timer := 0.0


func _ready() -> void:
	# One door per sector, seed-random angle within it: leaving the Commons is
	# always a six-way CHOICE, each door opening into a different biome.
	if biome_map == null:
		return
	for i in 6:
		var h := hash(Vector3i(world_seed ^ 0x0D008, i, 7))
		var frac := 0.2 + 0.6 * (float(posmod(h, 1000)) / 1000.0)
		var ang := (float(i) + frac) * TAU / 6.0 - biome_map._sector_offset
		var door := Vector2(cos(ang), sin(ang)) * Config.COMMONS_RADIUS
		_spawn_doors.append(door)
		if game != null:
			game.known_gates.append(door)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.4
	_refresh()


func _refresh() -> void:
	if player == null or not is_instance_valid(player) or biome_map == null:
		return
	var center := Vector2i(int(floor(player.global_position.x / TILE)), int(floor(player.global_position.y / TILE)))
	var span := int(ceil(VIEW / TILE))

	var needed := {}
	for dx in range(-span, span + 1):
		for dy in range(-span, span + 1):
			var c := center + Vector2i(dx, dy)
			needed[c] = true
			if not _active.has(c):
				var node = _make(c)
				_active[c] = node
				if node != null:
					add_child(node)

	for c in _active.keys():
		if not needed.has(c):
			var node = _active[c]
			if node != null and is_instance_valid(node):
				node.queue_free()
			_active.erase(c)


func _make(c: Vector2i):
	var pos := (Vector2(c) + Vector2(0.5, 0.5)) * TILE
	# Keep only the immediate spawn point clear; the Commons EDGE gets its wall
	# ring like every border (with its rare doorways).
	if pos.length() < 500.0:
		return null
	var b := biome_map.biome_at(pos)
	# A wall tile stands where a neighboring sample lies in a different biome.
	var border := false
	for off in [Vector2(TILE, 0), Vector2(-TILE, 0), Vector2(0, TILE), Vector2(0, -TILE)]:
		if biome_map.biome_at(pos + off) != b:
			border = true
			break
	if not border:
		return null
	# The Commons ring uses its six per-sector doors, not random gates.
	if absf(pos.length() - Config.COMMONS_RADIUS) < TILE * 1.8:
		for di in _spawn_doors.size():
			var d: Vector2 = _spawn_doors[di]
			if pos.distance_to(d) <= Config.GATE_WIDTH:
				var door_key := Vector2i(9999, di)  # synthetic guard key per door
				if not _guarded.has(door_key) and game != null:
					_guarded[door_key] = true
					var outside := biome_map.biome_at(d * ((Config.COMMONS_RADIUS + 180.0) / Config.COMMONS_RADIUS))
					_post_guards(d, outside)
				return null
		# ring tile, not a door → solid wall (skip random gate rolls entirely)
		var w0 := WallBody.new()
		w0.size = Vector2(TILE + 4.0, TILE + 4.0)
		w0.tint = Color(Config.BIOMES[b].color)
		w0.global_position = pos
		return w0

	# Gates: a few gate-cells contain a doorway — and the doorway is TINY, a
	# fixed point in the cell only GATE_WIDTH wide. Guards stand right in it.
	var gate := Vector2i(int(floor(pos.x / GATE)), int(floor(pos.y / GATE)))
	var gh := hash(Vector3i(world_seed ^ 0x77AA11, gate.x, gate.y))
	if posmod(gh, 100) < Config.WALL_GAP_PCT:
		var jx := (float(posmod(gh >> 8, 1000)) / 1000.0 - 0.5) * GATE * 0.5
		var jy := (float(posmod(gh >> 18, 1000)) / 1000.0 - 0.5) * GATE * 0.5
		var doorway := (Vector2(gate) + Vector2(0.5, 0.5)) * GATE + Vector2(jx, jy)
		if pos.distance_to(doorway) <= Config.GATE_WIDTH:
			if not _guarded.has(gate) and game != null:
				_guarded[gate] = true
				_post_guards(doorway, b)
				game.known_gates.append(doorway)  # discovered: the compass can use it
			return null
	var w := WallBody.new()
	w.size = Vector2(TILE + 4.0, TILE + 4.0)
	w.tint = Color(Config.BIOMES[b].color)
	w.global_position = pos
	return w


func _post_guards(pos: Vector2, biome: String) -> void:
	var roster: Array = Config.BIOMES[biome].roster
	var arch: String = roster[roster.size() - 1].arch  # the biome's heavier archetype
	for i in Config.GUARDS_PER_GATE:
		var off := Vector2(randf_range(-50, 50), randf_range(-50, 50))
		var e := Enemy.new()
		e.setup(arch, biome, player, game._hp_scale())
		e.guard = true
		e.global_position = pos + off
		e.home_pos = pos + off
		e.biome_map = biome_map
		e.died.connect(game._on_enemy_died.bind(e))
		game.enemies_root.add_child(e)
