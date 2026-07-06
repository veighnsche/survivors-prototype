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
var _timer := 0.0


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
	# Keep the spawn area open — no cage ring around the starting Commons disc.
	if pos.length() < Config.COMMONS_RADIUS + 220.0:
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
