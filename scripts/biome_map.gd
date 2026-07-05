class_name BiomeMap
extends RefCounted
## The world's biome layout: organic Voronoi-style blobs, deterministic per run
## seed. The Commons always surrounds spawn so tabula rasa starts survivable.

var world_seed := 0


func _init(seed_value: int) -> void:
	world_seed = seed_value


## Which biome is at this world position?
func biome_at(pos: Vector2) -> String:
	if pos.length() < Config.COMMONS_RADIUS:
		return "commons"
	var cell: float = Config.BIOME_CELL
	var pc := Vector2i(int(floor(pos.x / cell)), int(floor(pos.y / cell)))
	var best_d := INF
	var best := "commons"
	# Nearest jittered cell-center over the 3x3 neighborhood → organic borders.
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
				best = _pick_biome(h >> 20)
	return best


func _pick_biome(h: int) -> String:
	var total := 0.0
	for k in Config.BIOME_WEIGHTS:
		total += Config.BIOME_WEIGHTS[k]
	var roll := (float(posmod(h, 10000)) / 10000.0) * total
	for k in Config.BIOME_WEIGHTS:
		roll -= Config.BIOME_WEIGHTS[k]
		if roll <= 0.0:
			return k
	return "commons"
