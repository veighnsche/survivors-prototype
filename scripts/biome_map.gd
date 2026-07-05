class_name BiomeMap
extends RefCounted
## The world's biome layout. Near spawn: a guaranteed-fair pinwheel — all three
## biomes touch the spawn area as sectors in seed-random directions, so which
## biome you meet first is YOUR choice of direction, never luck. Beyond that:
## huge organic Voronoi blobs.

var world_seed := 0
var _sector_order: Array = []
var _sector_offset := 0.0


func _init(seed_value: int) -> void:
	world_seed = seed_value
	_sector_order = ["commons", "thornreach", "barrows", "wilds", "cragspire", "hollow"]
	# deterministic seed-based Fisher-Yates shuffle + rotation of the spawn sectors
	var h := hash(Vector3i(seed_value, 17, -9))
	for i in range(_sector_order.size() - 1, 0, -1):
		var j := posmod(h >> (i * 3), i + 1)
		var tmp = _sector_order[i]
		_sector_order[i] = _sector_order[j]
		_sector_order[j] = tmp
	_sector_offset = float(posmod(h >> 8, 1000)) / 1000.0 * TAU


## Which biome is at this world position?
func biome_at(pos: Vector2) -> String:
	var dist := pos.length()
	if dist < Config.COMMONS_RADIUS:
		return "commons"
	if dist < Config.SPAWN_FAIR_RADIUS:
		# fair pinwheel: one 60° sector per biome — all six touch spawn
		var ang := fposmod(pos.angle() + _sector_offset, TAU)
		return _sector_order[int(ang / (TAU / 6.0)) % 6]

	var cell: float = Config.BIOME_CELL
	var pc := Vector2i(int(floor(pos.x / cell)), int(floor(pos.y / cell)))
	var best_d := INF
	var best := "commons"
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := pc + Vector2i(dx, dy)
			var h := hash(Vector3i(world_seed, c.x, c.y))
			var jx := float(posmod(h, 1000)) / 1000.0
			var jy := float(posmod(h >> 10, 1000)) / 1000.0
			var center := (Vector2(c) + Vector2(jx, jy)) * cell
			var d := pos.distance_squared_to(center)
			if d < best_d:
				best_d = d
				best = _pick_biome(c)
	return best


func _pick_biome(c: Vector2i) -> String:
	# Independent full-range hash (reusing jitter bits once capped the roll and
	# made Barrows literally impossible — see git history).
	var h := hash(Vector3i(world_seed ^ 0x51ED270, c.x, c.y))
	var total := 0.0
	for k in Config.BIOME_WEIGHTS:
		total += Config.BIOME_WEIGHTS[k]
	var roll := (float(posmod(h, 100000)) / 100000.0) * total
	for k in Config.BIOME_WEIGHTS:
		roll -= Config.BIOME_WEIGHTS[k]
		if roll <= 0.0:
			return k
	return "commons"
