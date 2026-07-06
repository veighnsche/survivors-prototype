class_name SimBot
extends RefCounted
## The headless balance-sim pilot. Plays like a player: flee real pressure,
## hoover gems, chase beacons (chests/pickups), otherwise explore outward.
## Decisions are cached a few ticks — full-field scans every physics frame
## were the sim's CPU ceiling.

var _dir := Vector2.RIGHT
var _cache := Vector2.RIGHT
var _cache_ticks := 0


func steer(p: Player) -> Vector2:
	if OS.has_environment("DBG_STAND"):
		return Vector2.ZERO
	if _cache_ticks > 0:
		_cache_ticks -= 1
		return _cache
	_cache_ticks = 8
	_cache = _think(p)
	return _cache


func _think(p: Player) -> Vector2:
	# 1. Threat pressure from close enemies.
	var flee := Vector2.ZERO
	var threats := 0
	for e in p.get_tree().get_nodes_in_group("enemies"):
		var d: float = p.global_position.distance_to(e.global_position)
		if d < 160.0:
			flee += (p.global_position - e.global_position) / maxf(d, 8.0)
			threats += 1
	if threats >= 3:
		return _slide(p, flee.normalized())  # genuinely swarmed: just get out

	# 2. Collect: nearest gem, else nearest beacon target (chest/pickup).
	var tgt: Node2D = null
	var best_d := 520.0 * 520.0
	for g in p.get_tree().get_nodes_in_group("gems"):
		var d2: float = p.global_position.distance_squared_to(g.global_position)
		if d2 < best_d:
			best_d = d2
			tgt = g
	if tgt == null:
		best_d = 1200.0 * 1200.0
		for b in p.get_tree().get_nodes_in_group("guided"):
			var d2: float = p.global_position.distance_squared_to(b.global_position)
			if d2 < best_d:
				best_d = d2
				tgt = b
	if tgt != null:
		var dir: Vector2 = (tgt.global_position - p.global_position).normalized()
		if threats > 0:
			dir = (dir + flee.normalized() * 0.8).normalized()
		return _slide(p, dir)

	# 3. Explore: keep a heading, drift it occasionally, bias away from spawn.
	if randf() < 0.008:
		_dir = (_dir.rotated(randf_range(-1.2, 1.2)) + p.global_position.normalized() * 0.3).normalized()
	if threats > 0:
		return _slide(p, (_dir + flee.normalized()).normalized())
	return _slide(p, _dir)


## Slide the heading along walls instead of pinning into them.
func _slide(p: Player, dir: Vector2) -> Vector2:
	var space := p.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(p.global_position, p.global_position + dir * 90.0, 16)
	var hit := space.intersect_ray(q)
	if hit:
		var n: Vector2 = hit.normal
		var slid: Vector2 = dir - n * dir.dot(n)
		if slid.length() > 0.05:
			return slid.normalized()
		_dir = Vector2(-n.y, n.x)  # dead-on into a wall: turn along it
		return _dir
	return dir
